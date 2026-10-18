"""Small Swift literal reader for auditing display strings, including interpolation."""
import re


def string_end(source, start):
    hashes = 0
    while start - hashes > 0 and source[start - hashes - 1] == "#":
        hashes += 1
    quote = '"""' if source.startswith('"""', start) else '"'
    if hashes or len(quote) == 3:
        end = source.find(quote + "#" * hashes, start + len(quote))
        if end < 0:
            raise ValueError("Unclosed Swift string")
        return end + len(quote) + hashes
    index = start + 1
    while index < len(source):
        if source.startswith("\\(", index):
            index = paren_end(source, index + 2) + 1
        elif source[index] == "\\":
            index += 2
        elif source[index] == '"':
            return index + 1
        else:
            index += 1
    raise ValueError("Unclosed Swift string")


def paren_end(source, start):
    depth, index = 1, start
    while index < len(source):
        if source.startswith("//", index):
            end = source.find("\n", index)
            index = len(source) if end < 0 else end
            continue
        if source[index] == '"':
            index = string_end(source, index)
            continue
        if source[index] == "(":
            depth += 1
        elif source[index] == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise ValueError("Unclosed Swift call")


def unlocalized_error_literals(source):
    localized = []
    for match in re.finditer(r'(?:CoreLocalization\.(?:text|format)|NSLocalizedString)\(', source):
        localized.append((match.end(), paren_end(source, match.end())))
    for match in re.finditer(r'\bToolError\(|\.failure\(|\.denied\(', source):
        index, end = match.end(), paren_end(source, match.end())
        while index < end:
            if source[index] != '"':
                index += 1
                continue
            finish = string_end(source, index)
            value = source[index:finish]
            if re.search(r'[\u4e00-\u9fff]', value) and not any(start <= index < stop for start, stop in localized):
                yield source.count("\n", 0, index) + 1, value
            index = finish
