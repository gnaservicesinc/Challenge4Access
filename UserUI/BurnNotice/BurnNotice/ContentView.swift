import SwiftUI

struct ContentView: View {
    @State private var mode: String = "warning"
    @State private var uid: String = ""
    @State private var name: String = "App"
    @State private var currentTemp: Double = 0
    @State private var combustTemp: Double = 0
    @State private var burnedForever: Bool = false
    @State private var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            if mode == "warning" {
                Text("Burn Warning").font(.title).foregroundColor(.orange)
                Text("\(name) is nearing burn temperature.")
                Text(String(format: "Current: %.2f  |  Burn at: %.2f", currentTemp, combustTemp))
                Text("If it burns, access will be blocked until it cools (or permanently if configured). Consider exiting soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("View Status") { openStatus() }
                    Spacer()
                    Button("OK") { NSApp.terminate(nil) }
                }
            } else {
                Text("Burned").font(.title).foregroundColor(.red)
                Text("\(name) is burned.")
                Text(burnedForever ? "It is permanently burned until an admin intervenes." : "It will unburn after the configured cooldown.")
                HStack(spacing: 12) {
                    Button("Upgrade to Permanent") { sendRequest(type: "upgrade_permanent", value: 0) }
                    Button("+1h") { sendRequest(type: "extend_burn", value: 1) }
                    Button("+4h") { sendRequest(type: "extend_burn", value: 4) }
                    Button("+24h") { sendRequest(type: "extend_burn", value: 24) }
                }
                if let msg = message { Text(msg).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 12) {
                    Button("View Status") { openStatus() }
                    Spacer()
                    Button("Close") { NSApp.terminate(nil) }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 220)
        .padding()
        .onAppear { parseArgs() }
    }

    private func parseArgs() {
        let a = CommandLine.arguments
        // Expected: mode uid name currentTemp combustTemp [forever|temp]
        if a.count >= 2 { mode = a[1] }
        if a.count >= 3 { uid = a[2] }
        if a.count >= 4 { name = a[3] }
        if a.count >= 5 { currentTemp = Double(a[4]) ?? 0 }
        if a.count >= 6 { combustTemp = Double(a[5]) ?? 0 }
        if a.count >= 7 { burnedForever = (a[6] == "forever") }
    }

    private func sendRequest(type: String, value: Double) {
        let user = NSUserName()
        let sql = """
        CREATE TABLE IF NOT EXISTS requests (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, user TEXT, type TEXT NOT NULL, app_unique_id TEXT, value REAL DEFAULT 0.0);
        INSERT INTO requests (ts,user,type,app_unique_id,value) VALUES (strftime('%s','now'), '\(user)', '\(type)', '\(uid)', \(value));
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        proc.arguments = ["/opt/c4a/protected/com/requests.sqlite", sql]
        let pipe = Pipe()
        proc.standardError = pipe
        do { try proc.run(); proc.waitUntilExit() } catch { message = "Failed: \(error.localizedDescription)"; return }
        let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if err.isEmpty {
            message = "Request sent. It may take up to a minute to apply."
        } else {
            message = err
        }
    }

    private func openStatus() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-n", "-a", "/opt/c4a/Applications/StatusApp.app"]
        try? p.run()
    }
}
