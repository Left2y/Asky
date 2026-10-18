import Foundation
import Testing
import Contracts

@Suite struct CoreLocalizationTests {
    @Test func sharedBundleContainsBothLanguagesWithoutAnAppBundle() {
        #expect(CoreLocalization.text("未获得日历完全访问权限", language: "en") == "Full calendar access has not been granted")
        #expect(CoreLocalization.text("未获得日历完全访问权限", language: "zh-Hans") == "未获得日历完全访问权限")
        #expect(CoreLocalization.text("尚未在设置中选择允许访问的 Notes 文件夹", language: "en") == "No authorized Notes folders have been selected in Settings")
        #expect(CoreLocalization.text("插件未安装", language: "en") == "The plugin is not installed")
    }

    @Test func messageFormattingPreservesNamesPathsAndErrorCodes() {
        let name = "项目：A → B"
        let template = CoreLocalization.text("文件夹「%@」未授权", language: "en")
        #expect(String(format: template, name) == "Folder “项目：A → B” is not authorized")
        let path = "/Users/demo/文档/计划.md"
        let file = CoreLocalization.text("插件文件不存在或路径无效：%@", language: "en")
        #expect(String(format: file, path).hasSuffix(path))
        #expect(ToolError(.permissionDenied, String(format: template, name)).code.rawValue == "permissionDenied")
    }
}
