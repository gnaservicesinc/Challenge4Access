import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = AdminViewModel()
    @State private var newGroupName = ""
    @State private var showDirPicker = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                // Ruleset directory controls
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ruleset Directory").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(vm.rulesDir.path)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { vm.chooseRulesDir() }
                        Button("Open") { vm.revealRulesDirInFinder() }
                    }
                }
                .padding(.horizontal)
                HStack {
                    TextField("New group name", text: $newGroupName)
                    Button("Add") { vm.addGroup(name: newGroupName); newGroupName = "" }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                List(selection: $vm.selectedGroup) {
                    ForEach(vm.groups, id: \.self) { g in
                        Text(g).tag(g as String?)
                    }
                }
                .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                    vm.handleDroppedItems(providers: providers)
                }
                .onAppear { vm.reloadGroups() }
            }
            .frame(minWidth: 240)
            .navigationTitle("Groups")
        } content: {
            VStack(spacing: 8) {
                if let g = vm.selectedGroup {
                    HStack {
                        Text("Group: \(g)").font(.headline)
                        Spacer()
                        Button("Refresh") { vm.reloadApps() }
                    }
                    Table(vm.apps) {
                        TableColumn("Name") { Text($0.displayName) }
                        TableColumn("Type") { Text($0.triggerType) }
                        TableColumn("Data") { Text($0.triggerData) }
                        TableColumn("Tasks") { Text($0.tasksSummary) }
                    }
                } else {
                    Text("Select a group").foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Apps")
        } detail: {
            Form {
                Section("Automatic Rules") {
                    HStack {
                        Button("Steam + Local Apps") { vm.generateSteamAndLocal() }
                        Button("Social") { vm.generateSocial() }
                        Button("Streaming") { vm.generateStreaming() }
                    }
                    Text("Generates grouped .sqlv files and inserts app/URL triggers.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Scan Steam", isOn: $vm.scanSteam)
                    Toggle("Scan ~/Applications", isOn: $vm.scanUserApps)
                    Toggle("Scan /Applications", isOn: $vm.scanSystemApps)
                    Toggle("Auto Rescan (60s)", isOn: $vm.autoRescan)
                    HStack {
                        Button("Rescan Now") { vm.generateSteamAndLocal() }
                        Spacer()
                    }
                }
                Section("New App / Bin / Website") {
                    TextField("Display name", text: $vm.form.displayName)
                    Picker("Trigger type", selection: $vm.form.triggerType) {
                        Text("name").tag("name")
                        Text("command").tag("command")
                        Text("external").tag("external")
                        Text("url").tag("url")
                    }
                    TextField("Trigger data", text: $vm.form.triggerData)
                    Toggle("Always blocked", isOn: $vm.form.alwaysBlocked)
                    Toggle("Discouraged", isOn: $vm.form.alwaysDiscouraged)
                    Stepper(value: $vm.form.secondsBeforeTask, in: 0...7200, step: 30) {
                        Text("Seconds before new task: \(vm.form.secondsBeforeTask)")
                    }
                    Text("Drag & drop .app bundles or executables here to add rules.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color.black.opacity(0.03))
                        .cornerRadius(6)
                        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                            vm.handleDroppedItemsInForm(providers: providers)
                        }
                }
                Section("Tasks available") {
                    Toggle("Maths", isOn: $vm.form.taskMaths)
                    Toggle("Lines", isOn: $vm.form.taskLines)
                    Toggle("Clicks", isOn: $vm.form.taskClicks)
                    Toggle("Count", isOn: $vm.form.taskCount)
                }
                HStack {
                    Button("Create/Update") { vm.createOrUpdateApp() }
                        .disabled(vm.selectedGroup == nil || vm.form.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Reset form") { vm.form = AppForm() }
                }
                if let msg = vm.message { Text(msg).foregroundStyle(.secondary) }
            }
            .padding()
            .navigationTitle("Edit")
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                if vm.autoRescan { vm.generateSteamAndLocal() }
            }
        }
    }
}

struct AppRow: Identifiable, Hashable { let id = UUID(); let displayName: String; let triggerType: String; let triggerData: String; let tasksSummary: String }

struct AppForm {
    var displayName: String = ""
    var triggerType: String = "name"
    var triggerData: String = ""
    var alwaysBlocked: Bool = false
    var alwaysDiscouraged: Bool = true
    var taskMaths: Bool = true
    var taskLines: Bool = true
    var taskClicks: Bool = true
    var taskCount: Bool = true
    var secondsBeforeTask: Int = 300
}

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var groups: [String] = []
    @Published var selectedGroup: String? { didSet { reloadApps() } }
    @Published var apps: [AppRow] = []
    @Published var form = AppForm()
    @Published var message: String? = nil

    // Settings
    @Published var autoRescan: Bool = UserDefaults.standard.bool(forKey: "c4a.autoRescan") { didSet { UserDefaults.standard.set(autoRescan, forKey: "c4a.autoRescan") } }
    @Published var scanSteam: Bool = UserDefaults.standard.object(forKey: "c4a.scanSteam") as? Bool ?? true { didSet { UserDefaults.standard.set(scanSteam, forKey: "c4a.scanSteam") } }
    @Published var scanUserApps: Bool = UserDefaults.standard.object(forKey: "c4a.scanUserApps") as? Bool ?? true { didSet { UserDefaults.standard.set(scanUserApps, forKey: "c4a.scanUserApps") } }
    @Published var scanSystemApps: Bool = UserDefaults.standard.object(forKey: "c4a.scanSystemApps") as? Bool ?? false { didSet { UserDefaults.standard.set(scanSystemApps, forKey: "c4a.scanSystemApps") } }

    private(set) var rulesDir: URL
    private let fileManager = FileManager.default

    init() {
        if let saved = UserDefaults.standard.url(forKey: "c4a.rulesDir") {
            self.rulesDir = saved
        } else {
            self.rulesDir = URL(fileURLWithPath: "/opt/c4a/protected/ro/app_settings")
        }
    }

    func chooseRulesDir() {
        let panel = NSOpenPanel()
        panel.title = "Choose Ruleset Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            rulesDir = url
            UserDefaults.standard.set(url, forKey: "c4a.rulesDir")
            reloadGroups()
        }
    }

    func revealRulesDirInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([rulesDir])
    }

    func reloadGroups() {
        do {
            let items = try fileManager.contentsOfDirectory(at: rulesDir, includingPropertiesForKeys: nil)
            let names = items.filter { $0.pathExtension == "sqlv" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
            self.groups = names
            if selectedGroup == nil { selectedGroup = names.first }
        } catch {
            self.groups = []
            self.message = "Cannot list groups: \(error.localizedDescription)"
        }
    }

    func addGroup(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ensureDirExists(rulesDir)
        let db = rulesDir.appendingPathComponent(trimmed + ".sqlv").path
        ensureAppSchema(dbPath: db)
        reloadGroups()
        selectedGroup = trimmed
    }

    func reloadApps() {
        guard let g = selectedGroup else { apps = []; return }
        let db = rulesDir.appendingPathComponent(g + ".sqlv").path
        ensureAppSchema(dbPath: db)
        let sql = "SELECT display_name, trigger_id_type, trigger_id_data, task_maths_available, task_lines_available, task_clicks_available, task_count_available FROM app_settings;"
        let out = runSQLite(dbPath: db, sql: sql)
        let rows = out.split(separator: "\n").map { String($0) }
        self.apps = rows.compactMap { line in
            let f = line.split(separator: "|").map(String.init)
            guard f.count >= 7 else { return nil }
            let tasks = [ ("M", f[3] == "1"), ("L", f[4] == "1"), ("Ck", f[5] == "1"), ("Ct", f[6] == "1") ].filter { $0.1 }.map { $0.0 }.joined(separator: ",")
            return AppRow(displayName: f[0], triggerType: f[1], triggerData: f[2], tasksSummary: tasks)
        }
    }

    func createOrUpdateApp() {
        guard let g = selectedGroup else { return }
        let db = rulesDir.appendingPathComponent(g + ".sqlv").path
        ensureAppSchema(dbPath: db)
        let f = form
        let insert = "INSERT INTO app_settings (display_name, trigger_id_type, trigger_id_data, always_blocked, always_discouraged, seconds_of_usage_before_new_task, task_maths_available, task_lines_available, task_clicks_available, task_count_available) VALUES (\'\(escape(f.displayName))\', \'\(escape(f.triggerType))\', \'\(escape(f.triggerData))\', \(f.alwaysBlocked ? 1:0), \(f.alwaysDiscouraged ? 1:0), \(f.secondsBeforeTask), \(f.taskMaths ? 1:0), \(f.taskLines ? 1:0), \(f.taskClicks ? 1:0), \(f.taskCount ? 1:0));"
        let res = runSQLite(dbPath: db, sql: insert)
        if res.contains("Error") || res.contains("error") { self.message = "Insert may have failed: \(res)" } else { self.message = "Saved" }
        reloadApps()
    }

    // MARK: - SQLite helpers
    func ensureAppSchema(dbPath: String) {
        let create = """
        CREATE TABLE IF NOT EXISTS app_settings (
          unique_id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 1,
          display_name STRING NOT NULL,
          trigger_id_type STRING NOT NULL,
          trigger_id_data STRING NOT NULL,
          always_blocked BOOLEAN NOT NULL DEFAULT 0,
          always_discouraged BOOLEAN NOT NULL DEFAULT 1,
          sensitivity FLOAT NOT NULL DEFAULT 3.0,
          starting_temperature FLOAT NOT NULL DEFAULT 1.0,
          heat_rate FLOAT NOT NULL DEFAULT 1.0,
          cool_rate FLOAT NOT NULL DEFAULT 0.05,
          seconds_of_usage_before_new_task INTEGER NOT NULL DEFAULT 300,
          temperature_refresh_interval_in_seconds FLOAT NOT NULL DEFAULT 60.0,
          heat FLOAT NOT NULL DEFAULT 0.15,
          task_maths_available BOOLEAN NOT NULL DEFAULT 1,
          task_lines_available BOOLEAN NOT NULL DEFAULT 1,
          task_clicks_available BOOLEAN NOT NULL DEFAULT 1,
          task_count_available BOOLEAN NOT NULL DEFAULT 1,
          conbustion_possible BOOLEAN NOT NULL DEFAULT 1,
          can_recover_from_conbustion_possible BOOLEAN NOT NULL DEFAULT 0,
          conbustion_temp FLOAT NOT NULL DEFAULT 3000.0,
          recovery_length_in_hours_from_conbustion INTEGER NOT NULL DEFAULT 72
        );
        """
        _ = runSQLite(dbPath: dbPath, sql: create)
    }

    func runSQLite(dbPath: String, sql: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [dbPath, sql]
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        do { try p.run() } catch { return "Error: \(error.localizedDescription)" }
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let s = String(data: data, encoding: .utf8) ?? ""
        if !s.isEmpty { return s }
        let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return e
    }

    private func escape(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }

    // MARK: - Automatic Rules
    private func slug(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return s.lowercased().components(separatedBy: allowed.inverted).filter { !$0.isEmpty }.joined(separator: "_")
    }

    private func ensureDirExists(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func existingTriggers(in dbPath: String) -> Set<String> {
        let out = runSQLite(dbPath: dbPath, sql: "SELECT trigger_id_type||'|'||trigger_id_data FROM app_settings;")
        return Set(out.split(separator: "\n").map(String.init))
    }

    private func insertTrigger(db: String, name: String, type: String, data: String) {
        let key = type + "|" + data
        let existing = existingTriggers(in: db)
        if existing.contains(key) { return }
        let sql = "INSERT INTO app_settings (display_name, trigger_id_type, trigger_id_data) VALUES (\'\(escape(name))\', \'\(escape(type))\', \'\(escape(data))\');"
        _ = runSQLite(dbPath: db, sql: sql)
    }

    func generateSteamAndLocal() {
        ensureDirExists(rulesDir)
        let home = fileManager.homeDirectoryForCurrentUser.path
        let steamCommon = home + "/Library/Application Support/Steam/steamapps/common"
        let localApps = home + "/Applications"
        var created = 0
        // Steam scan
        if scanSteam, let subs = try? fileManager.contentsOfDirectory(atPath: steamCommon) {
            for entry in subs {
                let path = steamCommon + "/" + entry
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    let group = "steam_" + slug(entry)
                    let db = rulesDir.appendingPathComponent(group + ".sqlv").path
                    ensureAppSchema(dbPath: db)
                    insertTrigger(db: db, name: entry, type: "command", data: path)
                    // Look for .app bundles beneath (depth 2)
                    if let en = fileManager.enumerator(atPath: path) {
                        for case let sub as String in en {
                            if sub.lowercased().hasSuffix(".app") {
                                let appName = URL(fileURLWithPath: sub).deletingPathExtension().lastPathComponent
                                insertTrigger(db: db, name: appName, type: "name", data: appName)
                            }
                        }
                    }
                    created += 1
                }
            }
        }
        // Local ~/Applications
        if scanUserApps, let subs = try? fileManager.contentsOfDirectory(atPath: localApps) {
            for entry in subs where entry.lowercased().hasSuffix(".app") {
                let appName = URL(fileURLWithPath: entry).deletingPathExtension().lastPathComponent
                let group = "local_" + slug(appName)
                let db = rulesDir.appendingPathComponent(group + ".sqlv").path
                ensureAppSchema(dbPath: db)
                insertTrigger(db: db, name: appName, type: "name", data: appName)
                insertTrigger(db: db, name: appName, type: "command", data: localApps + "/" + entry)
                created += 1
            }
        }
        // System /Applications
        if scanSystemApps, let subs = try? fileManager.contentsOfDirectory(atPath: "/Applications") {
            for entry in subs where entry.lowercased().hasSuffix(".app") {
                let appName = URL(fileURLWithPath: entry).deletingPathExtension().lastPathComponent
                let group = "sys_" + slug(appName)
                let db = rulesDir.appendingPathComponent(group + ".sqlv").path
                ensureAppSchema(dbPath: db)
                insertTrigger(db: db, name: appName, type: "name", data: appName)
                insertTrigger(db: db, name: appName, type: "command", data: "/Applications/" + entry)
                created += 1
            }
        }
        self.message = "Generated Steam+Local groups: \(created)"
        reloadGroups(); reloadApps()
    }

    func generateSocial() {
        ensureDirExists(rulesDir)
        let db = rulesDir.appendingPathComponent("social.sqlv").path
        ensureAppSchema(dbPath: db)
        ["facebook.com", "x.com", "reddit.com"].forEach { domain in
            insertTrigger(db: db, name: domain, type: "url", data: domain)
        }
        self.message = "Generated Social rules"
        reloadGroups(); reloadApps()
    }

    func generateStreaming() {
        ensureDirExists(rulesDir)
        // YouTube (web only)
        var db = rulesDir.appendingPathComponent("stream_youtube.sqlv").path
        ensureAppSchema(dbPath: db)
        insertTrigger(db: db, name: "YouTube", type: "url", data: "youtube.com")

        // Apple TV (web + app)
        db = rulesDir.appendingPathComponent("stream_apple_tv.sqlv").path
        ensureAppSchema(dbPath: db)
        insertTrigger(db: db, name: "Apple TV", type: "url", data: "tv.apple.com")
        let tvAppPaths = ["/System/Applications/TV.app", "/Applications/TV.app", fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/TV.app").path]
        for p in tvAppPaths where fileManager.fileExists(atPath: p) {
            insertTrigger(db: db, name: "TV", type: "name", data: "TV")
            insertTrigger(db: db, name: "TV", type: "command", data: p)
            break
        }

        // Netflix
        db = rulesDir.appendingPathComponent("stream_netflix.sqlv").path
        ensureAppSchema(dbPath: db)
        insertTrigger(db: db, name: "Netflix", type: "url", data: "netflix.com")
        let netflixApps = ["/Applications/Netflix.app", fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Netflix.app").path]
        for p in netflixApps where fileManager.fileExists(atPath: p) {
            insertTrigger(db: db, name: "Netflix", type: "name", data: "Netflix")
            insertTrigger(db: db, name: "Netflix", type: "command", data: p)
            break
        }

        // Hulu
        db = rulesDir.appendingPathComponent("stream_hulu.sqlv").path
        ensureAppSchema(dbPath: db)
        insertTrigger(db: db, name: "Hulu", type: "url", data: "hulu.com")

        // Paramount+
        db = rulesDir.appendingPathComponent("stream_paramount.sqlv").path
        ensureAppSchema(dbPath: db)
        insertTrigger(db: db, name: "Paramount+", type: "url", data: "paramountplus.com")

        self.message = "Generated Streaming rules"
        reloadGroups(); reloadApps()
    }

    // MARK: - Drag & Drop
    func handleDroppedItems(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, _) in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        self.importFileURL(url)
                    }
                }
                handled = true
            }
        }
        return handled
    }

    func handleDroppedItemsInForm(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, _) in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        self.addRuleFromFile(url: url)
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private func importFileURL(_ url: URL) {
        ensureDirExists(rulesDir)
        if url.pathExtension.lowercased() == "sqlv" {
            let dest = rulesDir.appendingPathComponent(url.lastPathComponent)
            do {
                if fileManager.fileExists(atPath: dest.path) { try fileManager.removeItem(at: dest) }
                try fileManager.copyItem(at: url, to: dest)
                DispatchQueue.main.async { self.message = "Imported \(url.lastPathComponent)"; self.reloadGroups() }
            } catch { DispatchQueue.main.async { self.message = "Import failed: \(error.localizedDescription)" } }
        } else {
            // Not a ruleset; attempt to add a rule from it
            addRuleFromFile(url: url)
        }
    }

    private func addRuleFromFile(url: URL) {
        // Derive a reasonable group from file name if none selected
        let group = selectedGroup ?? slug(url.deletingPathExtension().lastPathComponent)
        if selectedGroup == nil { addGroup(name: group) }
        guard let g = selectedGroup else { return }
        let db = rulesDir.appendingPathComponent(g + ".sqlv").path
        ensureAppSchema(dbPath: db)
        let name = url.deletingPathExtension().lastPathComponent
        // .app bundle: add name and command triggers
        if url.pathExtension.lowercased() == "app" {
            insertTrigger(db: db, name: name, type: "name", data: name)
            insertTrigger(db: db, name: name, type: "command", data: url.path)
        } else {
            // Fallback: treat as executable/binary path
            insertTrigger(db: db, name: name, type: "command", data: url.path)
        }
        DispatchQueue.main.async { self.message = "Added rule for \(name)"; self.reloadApps() }
    }
}
