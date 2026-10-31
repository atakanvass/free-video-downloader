import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var item: NSStatusItem!
    let popover = NSPopover()
    let input = NSTextField()
    let button = NSButton(title: "", target: nil, action: nil)
    let quality = NSPopUpButton()
    var qualityURL: String?
    var lookup: DispatchWorkItem?
    let bar = NSProgressIndicator()
    let message = NSTextField(wrappingLabelWithString: "")
    var task: Process?
    var largestProgress = 0.0
    func menuIcon() -> NSImage {
        let icon = NSImage(size: NSSize(width: 19, height: 20), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let frame = NSBezierPath(roundedRect: NSRect(x: 2.0, y: 4.0, width: 15.0, height: 11.5), xRadius: 2.5, yRadius: 2.5)
            frame.lineWidth = 1.5; frame.stroke()
            let play = NSBezierPath(); play.move(to: NSPoint(x: 7.6, y: 7.1)); play.line(to: NSPoint(x: 7.6, y: 12.4)); play.line(to: NSPoint(x: 12.0, y: 9.75)); play.close(); play.fill()
            return true
        }
        icon.isTemplate = true
        icon.accessibilityDescription = "Video indir"
        return icon
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = menuIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.action = #selector(toggle); item.button?.target = self
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 166))
        view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        input.placeholderString = "https://..."; input.frame = NSRect(x: 20, y: 117, width: 320, height: 28); input.delegate = self
        input.font = .systemFont(ofSize: 13); input.focusRingType = .default
        quality.frame = NSRect(x: 20, y: 67, width: 155, height: 33); quality.controlSize = .large; addFormat("MP3", symbol: "headphones"); quality.isEnabled = false
        button.frame = NSRect(x: 185, y: 67, width: 155, height: 33); button.bezelStyle = .rounded; button.controlSize = .large; button.target = self; button.action = #selector(download)
        button.image = NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "Download"); button.imagePosition = .imageOnly; button.contentTintColor = .controlAccentColor
        button.toolTip = "Download"; button.isEnabled = false
        bar.frame = NSRect(x: 22, y: 39, width: 315, height: 12); bar.isIndeterminate = false; bar.minValue = 0; bar.maxValue = 100; bar.doubleValue = 0
        message.frame = NSRect(x: 22, y: 12, width: 315, height: 18); message.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium); message.textColor = .secondaryLabelColor
        [input,quality,button,bar,message].forEach { view.addSubview($0) }
        let controller = NSViewController(); controller.view = view; popover.contentViewController = controller; popover.behavior = .transient; popover.contentSize = view.frame.size
    }
    func addFormat(_ title: String, symbol: String, height: Int? = nil) {
        quality.addItem(withTitle: title)
        guard let item = quality.lastItem else { return }
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol == "headphones" ? "Audio" : "Video")
        item.representedObject = height
    }
    @objc func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let b = item.button { popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY); popover.contentViewController?.view.window?.makeKey(); popover.contentViewController?.view.window?.makeFirstResponder(input) }
    }
    func setBusy(_ busy: Bool) {
        input.isEnabled = !busy
        quality.isEnabled = !busy && qualityURL != nil
        button.isEnabled = !busy && qualityURL != nil
    }
    func controlTextDidChange(_ notification: Notification) {
        let url = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard qualityURL != url else { return }
        lookup?.cancel(); qualityURL = nil; quality.removeAllItems(); addFormat("MP3", symbol: "headphones"); quality.isEnabled = false; button.isEnabled = false
        message.stringValue = ""; message.toolTip = nil
        guard validURL(url) else { return }
        let work = DispatchWorkItem { [weak self] in self?.loadQualities() }
        lookup = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
    func validURL(_ value: String) -> Bool {
        guard let c = URLComponents(string: value), let scheme = c.scheme?.lowercased(), ["http", "https"].contains(scheme), c.user == nil, let host = c.host?.lowercased() else { return false }
        return ["youtube.com", "youtu.be", "instagram.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    func loadQualities() {
        let url = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validURL(url) else { message.stringValue = "⚠"; return }
        guard let ytdlp = ([Bundle.main.resourceURL?.appendingPathComponent("yt-dlp").path].compactMap { $0 } + ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]).first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { message.stringValue = "⚠"; return }
        qualityURL = nil; quality.removeAllItems(); quality.addItem(withTitle: "…"); setBusy(true)
        bar.isIndeterminate = true; bar.startAnimation(nil); message.stringValue = "…"
        DispatchQueue.global(qos: .utility).async {
            do {
                var heights = Set<Int>()
                let runtime = Bundle.main.resourceURL?.appendingPathComponent("node").path
                let js = runtime != nil && FileManager.default.isExecutableFile(atPath: runtime!) ? ["--js-runtimes", "node:" + runtime!] : []
                let result = try self.run(ytdlp, ["--ignore-config", "--no-playlist", "--skip-download", "--dump-single-json"] + js + ["--", url]) { line in
                    guard line.first == "{", let data = line.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let formats = json["formats"] as? [[String: Any]] else { return }
                    for format in formats {
                        guard let codec = format["vcodec"] as? String, codec != "none", let height = (format["height"] as? NSNumber)?.intValue, height > 0 else { continue }
                        heights.insert(height)
                    }
                }
                let sorted = heights.sorted(by: >)
                DispatchQueue.main.async {
                    self.bar.stopAnimation(nil); self.bar.isIndeterminate = false; self.bar.doubleValue = 0
                    self.quality.removeAllItems()
                    if result.0 == 0 && !sorted.isEmpty {
                        self.addFormat("MP3", symbol: "headphones")
                        for height in sorted { self.addFormat("\(height)p", symbol: "video", height: height) }
                        self.qualityURL = url; self.message.stringValue = ""
                    } else {
                        self.quality.addItem(withTitle: "—")
                        self.message.stringValue = "⚠"
                        self.message.toolTip = String(result.1.suffix(400))
                    }
                    self.setBusy(false)
                }
            } catch {
                DispatchQueue.main.async { self.bar.stopAnimation(nil); self.bar.isIndeterminate = false; self.message.stringValue = "⚠"; self.message.toolTip = error.localizedDescription; self.setBusy(false) }
            }
        }
    }
    func run(_ executable: String, _ args: [String], output: @escaping (String) -> Void) throws -> (Int32, String) {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = args
        process.environment = ProcessInfo.processInfo.environment.merging(["PATH": (Bundle.main.resourceURL?.path ?? "") + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"]) { _, new in new }
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try process.run(); var pending = ""; var all = ""
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            pending += String(decoding: data, as: UTF8.self)
            while let end = pending.firstIndex(of: "\n") {
                let line = String(pending[..<end]); pending.removeSubrange(...end); all += line + "\n"; if all.count > 30000 { all = String(all.suffix(30000)) }; output(line)
            }
        }
        if !pending.isEmpty { all += pending; output(pending) }
        process.waitUntilExit(); return (process.terminationStatus, all)
    }
    @objc func download() {
        let url = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validURL(url) else { message.stringValue = "⚠"; return }
        guard let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { message.stringValue = "⚠"; return }
        guard let ytdlp = ([Bundle.main.resourceURL?.appendingPathComponent("yt-dlp").path].compactMap { $0 } + ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]).first(where: { FileManager.default.isExecutableFile(atPath: $0) }), let ffmpeg = ([Bundle.main.resourceURL?.appendingPathComponent("ffmpeg").path].compactMap { $0 } + ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]).first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { message.stringValue = "⚠"; return }
        let audioOnly = quality.selectedItem?.title == "MP3"
        var selector = "bestaudio/best"
        if !audioOnly {
            guard qualityURL == url, let height = quality.selectedItem?.representedObject as? Int else { message.stringValue = "⚠"; return }
            selector = "bv*[height=\(height)]+ba/b[height=\(height)][acodec!=none]"
        }
        setBusy(true); bar.stopAnimation(nil); bar.isIndeterminate = false; bar.doubleValue = 0; largestProgress = 0; message.stringValue = "0%"
        DispatchQueue.global(qos: .utility).async {
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("kaydet-" + UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: temporary) }
            do {
                try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
                var outputPath: String?
                let runtime = Bundle.main.resourceURL?.appendingPathComponent("node").path
                let js = runtime != nil && FileManager.default.isExecutableFile(atPath: runtime!) ? ["--js-runtimes", "node:" + runtime!] : []
                let args = js + ["--ignore-config", "--no-playlist", "--newline", "--progress", "--progress-template", "download:KAYDET_PROGRESS:%(progress._percent_str)s", "--print", "after_move:KAYDET_FILE:%(filepath)s", "-f", selector, "-o", temporary.appendingPathComponent("%(title).120s [%(id)s].%(ext)s").path, "--", url]
                let result = try self.run(ytdlp, args) { line in
                    if let range = line.range(of: "KAYDET_FILE:") { outputPath = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) }
                    if let range = line.range(of: "KAYDET_PROGRESS:") {
                        let raw = String(line[range.upperBound...]).replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let percent = Double(raw) { DispatchQueue.main.async { self.largestProgress = max(self.largestProgress, min(90, percent * 0.9)); self.bar.doubleValue = self.largestProgress; self.message.stringValue = "\(Int(self.largestProgress))%" } }
                    }
                }
                guard result.0 == 0, let path = outputPath, FileManager.default.fileExists(atPath: path) else { throw NSError(domain: "Kaydet", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video indirilemedi. \(String(result.1.suffix(400)))"]) }
                let source = URL(fileURLWithPath: path)
                let ffprobe = URL(fileURLWithPath: ffmpeg).deletingLastPathComponent().appendingPathComponent("ffprobe").path
                var duration: Double?
                if FileManager.default.isExecutableFile(atPath: ffprobe) {
                    let probe = try self.run(ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", source.path]) { _ in }
                    if probe.0 == 0, let seconds = Double(probe.1.trimmingCharacters(in: .whitespacesAndNewlines)), seconds.isFinite, seconds > 0 { duration = seconds }
                }
                let totalDuration = duration
                DispatchQueue.main.async {
                    self.bar.stopAnimation(nil); self.bar.isIndeterminate = totalDuration == nil
                    if totalDuration == nil { self.bar.startAnimation(nil); self.message.stringValue = "⚙ …" }
                    else { self.bar.doubleValue = 0; self.message.stringValue = "⚙ 0%" }
                }
                let converted = temporary.appendingPathComponent(audioOnly ? "sonuc.mp3" : "sonuc.mp4")
                let convert = audioOnly ? ["-i", source.path, "-vn", "-c:a", "libmp3lame", "-q:a", "2", converted.path] : ["-i", source.path, "-map", "0:v:0", "-map", "0:a:0?", "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", converted.path]
                let conversion = try self.run(ffmpeg, ["-nostdin", "-hide_banner", "-loglevel", "error", "-progress", "pipe:1", "-nostats", "-y"] + convert) { line in
                    guard let duration = totalDuration, line.hasPrefix("out_time_us="), let microseconds = Double(line.dropFirst("out_time_us=".count)), microseconds.isFinite, microseconds >= 0 else { return }
                    let percent = min(99, max(0, microseconds / 1_000_000 / duration * 100))
                    DispatchQueue.main.async { self.bar.doubleValue = percent; self.message.stringValue = "⚙ \(Int(percent))%" }
                }
                guard conversion.0 == 0, FileManager.default.fileExists(atPath: converted.path) else { throw NSError(domain: "Kaydet", code: 2, userInfo: [NSLocalizedDescriptionKey: "Dönüştürme başarısız. \(String(conversion.1.suffix(400)))"]) }
                let name = source.deletingPathExtension().lastPathComponent
                let ext = audioOnly ? "mp3" : "mp4"
                var destination = folder.appendingPathComponent(name).appendingPathExtension(ext); var i = 2
                while FileManager.default.fileExists(atPath: destination.path) { destination = folder.appendingPathComponent("\(name) (\(i))").appendingPathExtension(ext); i += 1 }
                try FileManager.default.copyItem(at: converted, to: destination)
                DispatchQueue.main.async { self.bar.stopAnimation(nil); self.bar.isIndeterminate = false; self.bar.doubleValue = 100; self.message.stringValue = "100% ✓"; self.message.toolTip = destination.path; self.input.stringValue = ""; self.qualityURL = nil; self.quality.removeAllItems(); self.addFormat("MP3", symbol: "headphones"); self.setBusy(false) }
            } catch {
                DispatchQueue.main.async { self.bar.stopAnimation(nil); self.bar.isIndeterminate = false; self.message.stringValue = "⚠"; self.message.toolTip = error.localizedDescription; self.setBusy(false) }
            }
        }
    }
}
final class MenuApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            let actions: [String: Selector] = ["v": #selector(NSText.paste(_:)), "c": #selector(NSText.copy(_:)), "x": #selector(NSText.cut(_:)), "a": #selector(NSText.selectAll(_:))]
            if let key = event.charactersIgnoringModifiers?.lowercased(), let action = actions[key], sendAction(action, to: nil, from: self) { return }
        }
        super.sendEvent(event)
    }
}
let app = MenuApplication.shared
let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.accessory); app.run()
