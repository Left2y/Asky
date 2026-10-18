#!/usr/bin/env python3
"""Check bundled language parity, format arguments and static UI localization calls."""
from collections import Counter
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
entry = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', re.M)
placeholder = re.compile(r'%(?:\d+\$)?(?:[-+ #0]*\d*(?:\.\d+)?)(?:ll|l|z)?[@diuoxXfFeEgGcs]')
def arguments(value):
    slots = []
    for index, match in enumerate(placeholder.finditer(value.replace("%%", "")), 1):
        token = match.group()
        position = re.match(r"%(\d+)\$", token)
        slots.append((int(position[1]) if position else index, re.sub(r"%\d+\$", "%", token)))
    return Counter(slots)

catalogs = {}
errors = []
for language in ("en", "zh-Hans"):
    catalogs[language] = {}
    for path in sorted((root / "App/Resources" / (language + ".lproj")).glob("*.strings")):
        pairs = entry.findall(path.read_text())
        duplicate = [key for key, count in Counter(key for key, _ in pairs).items() if count > 1]
        if duplicate:
            errors.append(f"{path.relative_to(root)}: duplicate keys {duplicate}")
        catalogs[language][path.stem] = dict(pairs)

if catalogs["en"].keys() != catalogs["zh-Hans"].keys():
    errors.append("Language localization tables differ")

for table in sorted(catalogs["en"].keys() & catalogs["zh-Hans"].keys()):
    english, chinese = catalogs["en"][table], catalogs["zh-Hans"][table]
    if english.keys() != chinese.keys():
        errors.append(f"{table}: language keys differ: {sorted(english.keys() ^ chinese.keys())}")
    for key in english.keys() & chinese.keys():
        expected = arguments(key)
        for language, values in (("en", english), ("zh-Hans", chinese)):
            actual = arguments(values[key])
            if expected != actual:
                errors.append(f"{language}/{table}: format arguments differ for {key!r}")
        if re.search(r'[\u4e00-\u9fff]', english[key]):
            errors.append(f"en/{table}: untranslated Chinese in {key!r}")

# Direct literals and ternary literal keys. Dynamic names are checked by native regressions.
call = re.compile(r'NSLocalizedString\((.*?)\bcomment:\s*"(?:[^"\\]|\\.)*"\s*\)', re.S)
literal = re.compile(r'"((?:[^"\\]|\\.)*)"')
sources = list((root / "App/Sources").glob("*.swift"))
sources += list((root / "Packages/KulaCore/Sources").rglob("*.swift"))
for path in sources:
    source = re.sub(r'(?m)^\s*//.*$', '', path.read_text())
    for match in re.finditer(r'\b(?:Text|Button|Label|Picker|Section|TextField|accessibilityLabel|accessibilityHint|help)\("((?:[^"\\]|\\.)*)"', source):
        key = match.group(1)
        if re.search(r'[\u4e00-\u9fff]', key) and "\\(" not in key and key not in catalogs["en"]["Localizable"]:
            errors.append(f"{path.relative_to(root)}: missing SwiftUI key {key!r}")
    for match in call.finditer(source):
        arguments = match.group(1)
        table_match = re.search(r'tableName:\s*"([^"]+)"', arguments)
        table = table_match.group(1) if table_match else "Localizable"
        first = arguments.split(", tableName:")[0]
        for key in literal.findall(first):
            if "\\(" not in key and key not in catalogs["en"].get(table, {}):
                errors.append(f"{path.relative_to(root)}: missing {table} key {key!r}")

if errors:
    raise SystemExit("\n".join(errors))
print(f"PASS: {len(sources)} Swift sources; language parity, format arguments and static localization keys")
