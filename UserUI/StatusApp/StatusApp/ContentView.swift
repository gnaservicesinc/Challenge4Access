import SwiftUI

struct AppStatus: Identifiable {
    let id = UUID()
    let uid: String
    let name: String
    let group: String
    let currentTemp: Double
    let startingTemp: Double
    let combustTemp: Double
    let burned: Bool
    let burnedForever: Bool
    let hoursRemaining: Double
}

struct ContentView: View {
    @State private var rulesDir = URL(fileURLWithPath: "/opt/c4a/protected/ro/app_settings")
    @State private var memDir = URL(fileURLWithPath: "/opt/c4a/protected/memory/app_mem")
    @State private var appsAll: [AppStatus] = []
    @State private var apps: [AppStatus] = []
    @State private var ambient: Double = 0
    @State private var incAmount: Double = 0.25
    @State private var groups: [String] = []
    @State private var selectedGroup: String = "All"
    @State private var autoRefresh: Bool = true
    @State private var refreshInterval: Double = 10
    @State private var showHistoryForUID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ambient temperature: \(String(format: "%.2f", ambient))")
                Spacer()
                Button("Choose Rules…") { chooseDir(binding: $rulesDir) }
                Button("Choose Memory…") { chooseDir(binding: $memDir) }
                Button("Refresh") { refresh() }
            }
            HStack(spacing: 12) {
                Picker("Group", selection: $selectedGroup) {
                    Text("All").tag("All")
                    ForEach(groups, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                Toggle("Auto Refresh", isOn: $autoRefresh).toggleStyle(.switch)
                HStack(spacing: 6) {
                    Text("every")
                    Stepper(value: $refreshInterval, in: 2...60, step: 1) { Text("\(Int(refreshInterval))s") }
                }
                Spacer()
            }
            Table(apps) {
                TableColumn("Name") { Text($0.name) }
                TableColumn("Group") { Text($0.group) }
                TableColumn("Temp") { Text(String(format: "%.2f", $0.currentTemp)) }
                TableColumn("Start") { Text(String(format: "%.1f", $0.startingTemp)) }
                TableColumn("Burn @") { Text(String(format: "%.1f", $0.combustTemp)) }
                TableColumn("State") { Text($0.burned ? ($0.burnedForever ? "Permanent" : String(format: "Temp (%.1fh)", $0.hoursRemaining)) : "OK") }
                TableColumn("Actions") { row in
                    HStack {
                        Button("Burn 1h") { sendRequest(type: "burn", uid: row.uid, value: 1) }
                        Button("Burn 24h") { sendRequest(type: "burn", uid: row.uid, value: 24) }
                        Stepper(value: $incAmount, in: 0.05...5.0, step: 0.05) { Text("+\(String(format: "%.2f", incAmount)) temp") }
                        Button("Apply") { sendRequest(type: "increase_temp", uid: row.uid, value: incAmount) }
                        Button("History") { showHistoryForUID = row.uid }
                    }
                }
            }
        }
        .padding()
        .onAppear { refresh() }
        .onReceive(Timer.publish(every: max(2, refreshInterval), on: .main, in: .common).autoconnect()) { _ in
            if autoRefresh { refresh() }
        }
        .onChange(of: selectedGroup) { _ in applyGroupFilter() }
        .sheet(item: Binding(
            get: { showHistoryForUID.map { Identified(uid: $0) } },
            set: { showHistoryForUID = $0?.uid }
        )) { ident in
            HistoryView(uid: ident.uid, memDir: memDir)
                .frame(minWidth: 560, minHeight: 360)
        }
    }

    private func chooseDir(binding: Binding<URL>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url; refresh() }
    }

    private func refresh() {
        let mapping = loadSettingsMap()
        let mems = loadMemories()
        let merged = mems.map { mem in
            let meta = mapping[mem.uid] ?? (name: "App \(mem.uid)", group: "", starting: 1.0, combust: 0.0)
            return AppStatus(uid: mem.uid, name: meta.name, group: meta.group, currentTemp: mem.temp, startingTemp: meta.starting, combustTemp: meta.combust, burned: mem.burned, burnedForever: mem.forever, hoursRemaining: mem.hours)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        appsAll = merged
        let gs = Set(merged.map { $0.group }).sorted()
        groups = gs
        applyGroupFilter()
        let running = mems.filter { !$0.cooled }
        if !running.isEmpty { ambient = running.map { $0.temp }.reduce(0, +) / Double(running.count) } else { ambient = 0 }
    }

    private func applyGroupFilter() {
        if selectedGroup == "All" { apps = appsAll } else { apps = appsAll.filter { $0.group == selectedGroup } }
    }

    private func sendRequest(type: String, uid: String, value: Double) {
        let user = NSUserName()
        let sql = """
        CREATE TABLE IF NOT EXISTS requests (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, user TEXT, type TEXT NOT NULL, app_unique_id TEXT, value REAL DEFAULT 0.0);
        INSERT INTO requests (ts,user,type,app_unique_id,value) VALUES (strftime('%s','now'), '\(user)', '\(type)', '\(uid)', \(value));
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        proc.arguments = ["/opt/c4a/protected/com/requests.sqlite", sql]
        try? proc.run(); proc.waitUntilExit()
        refresh()
    }

    private func runSQLite(dbPath: String, sql: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [dbPath, sql]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func loadSettingsMap() -> [String:(name: String, group: String, starting: Double, combust: Double)] {
        var map: [String:(String, String, Double, Double)] = [:]
        if let items = try? FileManager.default.contentsOfDirectory(at: rulesDir, includingPropertiesForKeys: nil) {
            for f in items where f.pathExtension == "sqlv" {
                let group = f.deletingPathExtension().lastPathComponent
                let s = runSQLite(dbPath: f.path, sql: "SELECT unique_id, display_name, starting_temperature, conbustion_temp FROM app_settings;")
                s.split(separator: "\n").forEach { line in
                    let parts = line.split(separator: "|").map(String.init)
                    if parts.count >= 4 {
                        let uid = parts[0]
                        let name = parts[1]
                        let start = Double(parts[2]) ?? 1.0
                        let combust = Double(parts[3]) ?? 0.0
                        map[uid] = (name, group, start, combust)
                    }
                }
            }
        }
        return map
    }

    private func loadMemories() -> [(uid: String, temp: Double, cooled: Bool, burned: Bool, forever: Bool, hours: Double)] {
        var rows: [(String, Double, Bool, Bool, Bool, Double)] = []
        if let items = try? FileManager.default.contentsOfDirectory(atPath: memDir.path) {
            for entry in items where entry.hasSuffix(".sqlite") {
                let db = memDir.appendingPathComponent(entry).path
                let s = runSQLite(dbPath: db, sql: "SELECT app_unique_id,current_temperature,cooled,burned,burned_forever,hours_remaining_until_not_burned FROM app_memories LIMIT 1;")
                s.split(separator: "\n").forEach { line in
                    let p = line.split(separator: "|").map(String.init)
                    if p.count >= 6 {
                        rows.append((p[0], Double(p[1]) ?? 0.0, (Int(p[2]) ?? 1) != 0, (Int(p[3]) ?? 0) != 0, (Int(p[4]) ?? 0) != 0, Double(p[5]) ?? 0.0))
                    }
                }
            }
        }
        return rows
    }
}

private struct Identified: Identifiable { let uid: String; var id: String { uid } }

struct HistoryView: View {
    let uid: String
    let memDir: URL

    private func runSQLite(dbPath: String, sql: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [dbPath, sql]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func loadMemDetails() -> [(String, String)] {
        let db = memDir.appendingPathComponent("\(uid).sqlite").path
        let sql = "SELECT last_open_time,lifetime_opens,opens_since_last_cooled,last_burned_date_time,lifetime_numbr_of_times_burned FROM app_memories LIMIT 1;"
        let s = runSQLite(dbPath: db, sql: sql)
        if let line = s.split(separator: "\n").first {
            let p = String(line).split(separator: "|").map(String.init)
            if p.count >= 5 {
                return [
                    ("Last open", p[0]),
                    ("Lifetime opens", p[1]),
                    ("Opens since cooled", p[2]),
                    ("Last burned", p[3]),
                    ("Times burned", p[4])
                ]
            }
        }
        return []
    }

    private func loadRecentRequests(limit: Int = 50) -> [(String, String, String, String)] {
        let db = "/opt/c4a/protected/com/requests.sqlite"
        let sql = "SELECT datetime(ts,'unixepoch','localtime'), user, type, printf('%.3f', value) FROM requests WHERE app_unique_id='\(uid)' ORDER BY ts DESC LIMIT \(limit);"
        let s = runSQLite(dbPath: db, sql: sql)
        var rows: [(String,String,String,String)] = []
        s.split(separator: "\n").forEach { line in
            let p = String(line).split(separator: "|").map(String.init)
            if p.count >= 4 { rows.append((p[0], p[1], p[2], p[3])) }
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History for \(uid)").font(.title3)
            if loadMemDetails().isEmpty && loadRecentRequests().isEmpty {
                Text("No history available.").foregroundStyle(.secondary)
            } else {
                GroupBox("Memory") {
                    ForEach(loadMemDetails(), id: \.0) { kv in
                        HStack { Text(kv.0 + ":").foregroundStyle(.secondary); Spacer(); Text(kv.1) }
                    }
                }
                GroupBox("Recent Requests") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Time").frame(width: 160, alignment: .leading)
                            Text("User").frame(width: 120, alignment: .leading)
                            Text("Type").frame(width: 140, alignment: .leading)
                            Text("Value").frame(width: 80, alignment: .trailing)
                        }.font(.caption).foregroundStyle(.secondary)
                        Divider()
                        ScrollView {
                            ForEach(Array(loadRecentRequests().enumerated()), id: \.offset) { _, r in
                                HStack {
                                    Text(r.0).frame(width: 160, alignment: .leading)
                                    Text(r.1).frame(width: 120, alignment: .leading)
                                    Text(r.2).frame(width: 140, alignment: .leading)
                                    Text(r.3).frame(width: 80, alignment: .trailing)
                                }.font(.system(size: 12))
                            }
                        }.frame(maxHeight: 180)
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}
