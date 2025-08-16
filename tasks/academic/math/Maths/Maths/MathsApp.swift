//
//  MathsApp.swift
//  Maths
//
//  Created by Andrew Smith on 8/16/25.
//
import SwiftUI
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let C4A_OUR_SETTINGS_FILE = "/opt/c4a/protected/ro/task_settings/maths"
let C4A_OUR_MEMORY_FILE = "/opt/c4a/protected/memory/task_memories/maths"

@main
struct MathsApp: App {
    @StateObject private var model: MathsViewModel

    init() {
        let args = CommandLine.arguments
        guard args.count >= 2, let n = Int(args[1]) else {
            print("-1")
            fflush(stdout)
            exit(-1)
        }
        let gradeFlag = args.count > 2 ? (Int(args[2]) ?? 1) : 1
        let minGrade = args.count > 3 ? (Double(args[3]) ?? 0.95) : 0.95
        _model = StateObject(wrappedValue: MathsViewModel(N: n, gradeTasks: gradeFlag != 0, minGrade: minGrade))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
