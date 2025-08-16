//
//  ContentView.swift
//  Count
//
//  Created by Andrew Smith on 8/16/25.
//
internal import Combine
let C4A_OUR_SETTINGS_FILE = "/opt/c4a/protected/ro/task_settings/count"

import SwiftUI

final class CountViewModel: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()
    
    @Published var prompt: String = ""
    @Published var answerInput: String = ""
    @Published var status: String = ""
    private var target: Int = 0
    private let gradeTasks: Bool
    private let minGrade: Double
    private var startedAt: Date = Date()

    init(N: Int, gradeTasks: Bool, minGrade: Double) {
        self.gradeTasks = gradeTasks
        self.minGrade = minGrade
        // Placeholder: pick a target derived from N
        self.target = max(1, min(999, N * 5))
        self.prompt = "Type \(target) and press Enter"
        self.startedAt = Date()
    }

    func submit() {
        if Int(answerInput) == target {
            exit(1)
        } else {
            exit(0)
        }
    }

    func fail(reason: String) {
        status = reason
        exit(0)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: CountViewModel
    var body: some View {
        VStack(spacing: 16) {
            Text("Count Task")
                .font(.title)
            Text(model.prompt)
                .font(.headline)
            TextField("Answer", text: $model.answerInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.center)
                .onSubmit { model.submit() }
            Button("Submit") { model.submit() }
                .keyboardShortcut(.return)
            if !model.status.isEmpty { Text(model.status).foregroundColor(.red) }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
