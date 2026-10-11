import AppKit

/// Accessory apps get no default main menu, so ⌘V/⌘C/⌘X/⌘A/⌘Z never reach
/// text fields. A hidden main menu still routes these key equivalents to the
/// first responder of the key window, including non-activating panels.
@MainActor
enum EditMenu {
    static func install() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: NSLocalizedString("退出 Asky", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: NSLocalizedString("编辑", comment: ""))
        edit.addItem(withTitle: NSLocalizedString("撤销", comment: ""), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: NSLocalizedString("重做", comment: ""), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: NSLocalizedString("剪切", comment: ""), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: NSLocalizedString("拷贝", comment: ""), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: NSLocalizedString("粘贴", comment: ""), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: NSLocalizedString("全选", comment: ""), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
