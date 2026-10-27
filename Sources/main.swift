import AppKit
import Carbon
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusLabel: NSTextField!
    private var textView: NSTextView!
    private var picker: NSPopUpButton!
    private var scanButton: NSButton!
    private var fileButton: NSButton!
    private var clipboardButton: NSButton!
    private var copyButton: NSButton!
    private var openButton: NSButton!
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var busy = false
    private var results: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu()
        makeWindow()
        makeStatusItem()
        registerShortcut()
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func makeMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于轻扫码", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出轻扫码", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func label(_ text: String, size: CGFloat = 13, color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: text)
        view.font = .systemFont(ofSize: size)
        view.textColor = color
        return view
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        return button
    }

    private func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 500),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "轻扫码"
        window.minSize = NSSize(width: 540, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        let root = window.contentView!
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])

        let heading = label("轻扫码", size: 26)
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(label("框住二维码，内容即刻复制。", size: 14, color: .secondaryLabelColor))

        scanButton = button("框选屏幕扫码     ⌥⇧Q", action: #selector(scanScreen))
        scanButton.bezelColor = .controlAccentColor
        scanButton.contentTintColor = .white
        scanButton.font = .systemFont(ofSize: 16, weight: .medium)
        scanButton.keyEquivalent = "\r"
        stack.addArrangedSubview(scanButton)
        scanButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scanButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        fileButton = button("选择图片…", action: #selector(scanFile))
        clipboardButton = button("识别剪贴板图片", action: #selector(scanClipboard))
        let inputs = NSStackView(views: [fileButton, clipboardButton])
        inputs.distribution = .fillEqually
        inputs.spacing = 10
        stack.addArrangedSubview(inputs)
        inputs.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let separator = NSBox()
        separator.boxType = .separator
        stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        statusLabel = label("准备好了，选择一种方式开始扫码。", color: .secondaryLabelColor)
        stack.addArrangedSubview(statusLabel)
        picker = NSPopUpButton()
        picker.target = self
        picker.action = #selector(selectResult)
        picker.isHidden = true
        stack.addArrangedSubview(picker)
        picker.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 510, height: 140))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        copyButton = button("复制内容", action: #selector(copyResult))
        openButton = button("打开链接 ↗", action: #selector(openLink))
        copyButton.isEnabled = false
        openButton.isEnabled = false
        let actions = NSStackView(views: [copyButton, openButton])
        actions.spacing = 10
        stack.addArrangedSubview(actions)
        stack.addArrangedSubview(label("离线识别 · 不上传图片 · 不保存历史", size: 11, color: .tertiaryLabelColor))
    }

    private func makeStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "轻扫码")
        let menu = NSMenu()
        let scan = NSMenuItem(title: "框选屏幕扫码", action: #selector(scanScreen), keyEquivalent: "q")
        scan.keyEquivalentModifierMask = [.option, .shift]
        menu.addItem(scan)
        menu.addItem(withTitle: "选择图片…", action: #selector(scanFile), keyEquivalent: "")
        menu.addItem(withTitle: "识别剪贴板图片", action: #selector(scanClipboard), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "显示主窗口", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
    }

    private func registerShortcut() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            delegate.scanScreen()
            return noErr
        }, 1, &type, context, &eventHandler)
        let id = EventHotKeyID(signature: 0x5152534E, id: 1)
        let shortcutStatus = RegisterEventHotKey(UInt32(kVK_ANSI_Q), UInt32(optionKey | shiftKey), id,
                                                GetApplicationEventTarget(), 0, &hotKey)
        if handlerStatus != noErr || shortcutStatus != noErr {
            statusLabel.stringValue = "⌥⇧Q 快捷键不可用，请使用按钮或菜单栏扫码。"
        }
    }

    @objc func showWindow() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func setBusy(_ value: Bool, message: String) {
        busy = value
        scanButton.isEnabled = !value
        fileButton.isEnabled = !value
        clipboardButton.isEnabled = !value
        picker.isEnabled = !value
        copyButton.isEnabled = !value && !results.isEmpty
        openButton.isEnabled = !value && QRScanner.webURL(textView.string) != nil
        statusLabel.stringValue = message
        statusLabel.textColor = .secondaryLabelColor
    }

    @objc func scanScreen() {
        guard !busy else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showWindow()
            let alert = NSAlert()
            alert.messageText = "允许轻扫码读取你框选的屏幕区域"
            alert.informativeText = "请在系统设置 → 隐私与安全性 → 屏幕与系统音频录制（或屏幕录制）中开启「轻扫码」。按系统提示退出并重新打开应用后，再试一次。\n\n也可以直接选择图片扫码，无需录屏权限。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LightScan-" + UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch { showError(error.localizedDescription); return }
        let imageURL = directory.appendingPathComponent("selection.png")
        setBusy(true, message: "拖动鼠标框住二维码，按 Esc 取消。")
        window.orderOut(nil)
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", "-t", "png", imageURL.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [self] process in
                // Decode before deleting the private temporary screenshot.
                let result: Result<[String]?, Error>
                if process.terminationStatus != 0 || !FileManager.default.fileExists(atPath: imageURL.path) {
                    result = .success(nil)
                } else {
                    result = Result { try QRScanner.read(QRScanner.image(at: imageURL)) }
                        .map { Optional($0) }
                }
                try? FileManager.default.removeItem(at: directory)
                DispatchQueue.main.async { [self] in
                    showWindow()
                    switch result {
                    case .success(nil): setBusy(false, message: "已取消框选，可以重新扫码。")
                    case .success(let values?): display(values)
                    case .failure(let error): showError(error.localizedDescription)
                    }
                }
            }
            do { try process.run() }
            catch {
                try? FileManager.default.removeItem(at: directory)
                showWindow()
                showError(error.localizedDescription)
            }
        }
    }

    @objc func scanFile() {
        guard !busy else { return }
        showWindow()
        let panel = NSOpenPanel()
        panel.title = "选择包含二维码的图片"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [self] response in
            guard response == .OK, let url = panel.url else { return }
            decode { try QRScanner.image(at: url) }
        }
    }

    @objc func scanClipboard() {
        guard !busy else { return }
        showWindow()
        let board = NSPasteboard.general
        if let image = NSImage(pasteboard: board),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            decode { cgImage }
        } else if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
                  let url = urls.first {
            decode { try QRScanner.image(at: url) }
        } else {
            showError("剪贴板里没有图片。请先复制二维码图片，或用截图快捷键将截图复制到剪贴板。")
        }
    }

    private func decode(_ source: @escaping () throws -> CGImage) {
        setBusy(true, message: "正在本机识别…")
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = Result { try QRScanner.read(source()) }
            DispatchQueue.main.async { [self] in
                switch result {
                case .success(let values): display(values)
                case .failure(let error): showError(error.localizedDescription)
                }
            }
        }
    }

    private func display(_ values: [String]) {
        results = values
        picker.removeAllItems()
        picker.addItems(withTitles: values.enumerated().map { "二维码 \($0.offset + 1)：" + String($0.element.prefix(45)).replacingOccurrences(of: "\n", with: " ") })
        picker.isHidden = values.count < 2
        textView.string = values.first ?? ""
        setBusy(false, message: values.isEmpty ? "没有识别到二维码，请包含完整边缘并换一张更清晰的图片。" : "")
        if !values.isEmpty { copyResult() }
    }

    private func showError(_ message: String) {
        // Clear stale content so an earlier result cannot be mistaken for the failed scan.
        results = []
        textView.string = ""
        picker.removeAllItems()
        picker.isHidden = true
        setBusy(false, message: message)
        statusLabel.textColor = .systemOrange
    }

    @objc func selectResult() {
        guard results.indices.contains(picker.indexOfSelectedItem) else { return }
        textView.string = results[picker.indexOfSelectedItem]
        copyResult()
        openButton.isEnabled = QRScanner.webURL(textView.string) != nil
    }

    @objc func copyResult() {
        guard !busy, !results.isEmpty else { return }
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setString(textView.string, forType: .string)
        let count = results.count > 1 ? "识别到 \(results.count) 个二维码 · " : ""
        statusLabel.stringValue = count + (copied ? "已复制到剪贴板" : "复制失败，请选中文字后手动复制。")
        statusLabel.textColor = copied ? .systemGreen : .systemOrange
        openButton.isEnabled = QRScanner.webURL(textView.string) != nil
    }

    @objc func openLink() {
        guard !busy, let url = QRScanner.webURL(textView.string) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "轻扫码",
            .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "框选即扫码。使用 Apple Vision 在本机识别二维码。\n快捷键：⌥⇧Q\n关闭窗口后，可从菜单栏再次打开；⌘Q 完全退出。")
        ])
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
