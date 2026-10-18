import Testing
import Foundation
import Contracts
import LocalStore
@testable import Memory

func tempMemoryFolder() -> MemoryFolder {
    MemoryFolder(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Memory"))
}

@Suite struct MemoryFolderTests {
    @Test func templateHasNoContextUntilSomethingIsWritten() throws {
        let m = tempMemoryFolder()
        #expect(m.read().isEmpty && m.context() == nil)
        try m.ensureExists()
        #expect(m.read().contains("## 偏好") && m.read().contains("## 主题文件") && m.context() == nil)
        try m.add("用户希望默认用中文回复", section: "偏好")
        #expect(m.context()?.contains("- 用户希望默认用中文回复") == true)
    }

    @Test func addAppendsUnderSectionAndSkipsDuplicates() throws {
        let m = tempMemoryFolder()
        #expect(try m.add("用户住在杭州", section: "关于我"))
        #expect(try m.add("用户是产品经理", section: "关于我"))
        #expect(try m.add("用户喜欢靠窗座位", section: "偏好"))
        #expect(try !m.add("用户住在杭州", section: "偏好"))
        let text = m.read()
        let me = try #require(text.range(of: "## 关于我")), pref = try #require(text.range(of: "## 偏好"))
        let hz = try #require(text.range(of: "- 用户住在杭州")), pm = try #require(text.range(of: "- 用户是产品经理"))
        #expect(me.upperBound < hz.lowerBound && hz.upperBound < pm.lowerBound && pm.upperBound < pref.lowerBound)
        #expect(text.components(separatedBy: "用户住在杭州").count == 2)
        // Unknown sections fall back to the first one; headings the user deleted are recreated.
        try String("# 我的记忆\n- 手写的一行\n").write(to: m.indexURL, atomically: true, encoding: .utf8)
        try m.add("用户养了一只猫", section: "宠物")
        #expect(m.read() == "# 我的记忆\n- 手写的一行\n\n## 关于我\n- 用户养了一只猫\n")
    }

    @Test func topicFilesAreRegisteredInIndexButNotInContext() throws {
        let m = tempMemoryFolder()
        try m.add("用户在做 Orion 项目，目标年底上线", file: "projects", description: "长期项目与目标")
        try m.add("Orion 用 Swift 写", file: "projects.md", description: "别的说明")
        #expect(m.read("projects.md") == "# projects\n\n- 用户在做 Orion 项目，目标年底上线\n- Orion 用 Swift 写\n")
        let index = m.read()
        #expect(index.contains("## 主题文件\n- [projects.md](projects.md) — 长期项目与目标\n") && !index.contains("别的说明"))
        let ctx = try #require(m.context())
        #expect(ctx.contains("projects.md") && !ctx.contains("年底上线"))
        #expect(m.topicFiles() == ["projects.md"])
        #expect(throws: MemoryFolder.EditError.invalidFileName) { try m.add("x", file: "../secret") }
    }

    @Test func replaceAndRemoveNeedExactUniqueText() throws {
        let m = tempMemoryFolder()
        try m.add("用户住在上海", section: "关于我")
        try m.add("用户在做 Orion 项目", file: "projects.md")
        try m.add("用户在上海工作", section: "关于我")
        #expect(throws: MemoryFolder.EditError.notFound) { try m.replace("用户住在北京", with: "x") }
        #expect(throws: MemoryFolder.EditError.ambiguous) { try m.replace("上海", with: "x") }
        #expect(throws: MemoryFolder.EditError.notFound) { try m.remove("Orion") }
        try m.replace("用户住在上海", with: "用户住在杭州")
        try m.remove("Orion", file: "projects.md")
        #expect(m.read().contains("- 用户住在杭州\n") && !m.read("projects.md").contains("Orion"))
    }

    @Test func longIndexIsTruncatedInContext() throws {
        let m = tempMemoryFolder()
        try m.ensureExists()
        try (m.read() + String(repeating: "- 很长的一行\n", count: 1000)).write(to: m.indexURL, atomically: true, encoding: .utf8)
        let ctx = try #require(m.context())
        let suffix = CoreLocalization.text("\n（记忆索引过长，后面的内容已省略）")
        #expect(ctx.count == MemoryFolder.maxIndexCharacters + suffix.count && ctx.hasSuffix(suffix))
    }

    @Test func legacyConfirmedMemoriesAreExportedOnce() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let s = try LocalStore(inMemoryWithRoot: root)
        func row(_ content: String, _ kind: String, confirmed: Bool, pinned: Bool = false, permissions: Int = 3) throws {
            try s.db.run("""
                INSERT INTO memories(id, content, kind, status, source_ids, subjects, confirmed, pinned, permissions, created_at, updated_at)
                VALUES(?,?,?,'active','[]','[]',?,?,?,0,0)
                """, [UUID().uuidString, content, kind, confirmed, pinned, permissions])
        }
        try row("用户偏好中文回复", "preference", confirmed: true)
        try row("用户在做 Orion 项目", "episode", confirmed: false, pinned: true)
        try row("用户使用 Codex 工具进行开发", "fact", confirmed: false)
        try row("用户的病史", "fact", confirmed: true, permissions: 1)
        let m = MemoryFolder(s)
        m.migrateLegacy(s)
        let text = m.read()
        #expect(text.contains("## 偏好\n- 用户偏好中文回复") && text.contains("[projects.md](projects.md)"))
        #expect(m.read("projects.md").contains("- 用户在做 Orion 项目"))
        #expect(!text.contains("Codex") && !text.contains("病史"))
        try m.remove("Orion", file: "projects.md")
        m.migrateLegacy(s)
        #expect(!m.read("projects.md").contains("Orion"))
    }
}
