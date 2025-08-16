//
//  CountApp.swift
//  Count
//
//  Created by Andrew Smith on 8/16/25.
//

import SwiftUI

@main
struct CountApp: App {
    @StateObject private var model: CountViewModel

    init() {
        let args = CommandLine.arguments
        let n = (args.count > 1 ? Int(args[1]) : nil) ?? 1
        let grade = (args.count > 2 ? (Int(args[2]) ?? 1) : 1) != 0
        let minGrade = (args.count > 3 ? (Double(args[3]) ?? 0.95) : 0.95)
        _model = StateObject(wrappedValue: CountViewModel(N: n, gradeTasks: grade, minGrade: minGrade))
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model)
        }
    }
}
