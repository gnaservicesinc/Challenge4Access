import SwiftUI
import Foundation
import Combine

enum Operation: CaseIterable {
    case add, sub, mul, div

    var symbol: String {
        switch self {
        case .add: return "+"
        case .sub: return "-"
        case .mul: return "*"
        case .div: return "/"
        }
    }
}

struct TaskSettings {
    let problemsPerN: Int
    let attemptsPerProblem: Int
    let timed: Bool
    let resetImmediatelyOnFail: Bool
    let allowedOperations: [Operation]
    let maxSeconds: [Operation: Double]
    let valueRange: ClosedRange<Int>
}

struct TaskMemory {
    var currentNTotal: Int
    var currentNCompleted: Int
    var maxPossibleScore: Int
    var currentScore: Int
}

final class MathsViewModel: ObservableObject {
    @Published var question: String = ""
    @Published var answerInput: String = ""
    @Published var status: String = ""

    private var settings: TaskSettings
    private var memory: TaskMemory
    private let gradeTasks: Bool
    private let minGrade: Double

    private var currentAnswer: Int = 0
    private var currentOperation: Operation = .add
    private var attempts: Int = 0
    private var startTime: Date = Date()

    init(N: Int, gradeTasks: Bool, minGrade: Double) {
        self.gradeTasks = gradeTasks
        self.minGrade = minGrade
        self.settings = Self.loadSettings(path: C4A_OUR_SETTINGS_FILE)
        self.memory = Self.loadMemory(path: C4A_OUR_MEMORY_FILE)
        if memory.currentNTotal == 0 {
            memory.currentNTotal = N
        }
        memory.maxPossibleScore = settings.problemsPerN * memory.currentNTotal
        Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
        nextQuestion()
    }

    // Expose progress and timer to UI
    func progressCounts() -> (completed: Int, total: Int) {
        return (memory.currentNCompleted, memory.maxPossibleScore)
    }

    func timeRemainingSeconds() -> Double? {
        guard settings.timed, let limit = settings.maxSeconds[currentOperation] else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0.0, limit - elapsed)
    }

    func submit() {
        guard let provided = Int(answerInput) else {
            attempts += 1
            evaluate(correct: false)
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        if settings.timed, let limit = settings.maxSeconds[currentOperation], elapsed > limit {
            status = "Too slow"
            attempts += 1
            evaluate(correct: false)
        } else if provided == currentAnswer {
            status = "Correct"
            evaluate(correct: true)
        } else {
            status = "Incorrect"
            attempts += 1
            evaluate(correct: false)
        }
    }

    private func evaluate(correct: Bool) {
        if correct {
            memory.currentScore += 1
        }
        if correct || attempts >= settings.attemptsPerProblem {
            memory.currentNCompleted += 1
            Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
            attempts = 0
            answerInput = ""
            if !correct && !gradeTasks {
                finish(success: false)
                return
            }
            if gradeTasks && settings.resetImmediatelyOnFail {
                let remaining = memory.maxPossibleScore - memory.currentNCompleted
                let possible = memory.currentScore + remaining
                if Double(possible) / Double(memory.maxPossibleScore) < minGrade {
                    memory.currentScore = 0
                    Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
                    finish(success: false)
                    return
                }
            }
            if memory.currentNCompleted >= memory.maxPossibleScore {
                let grade = Double(memory.currentScore) / Double(memory.maxPossibleScore)
                finish(success: grade >= minGrade)
            } else {
                nextQuestion()
            }
        }
    }

    private func nextQuestion() {
        let (op, text, ans) = Self.generateProblem(settings)
        currentOperation = op
        question = text
        currentAnswer = ans
        startTime = Date()
        status = ""
    }

    private func finish(success: Bool) {
        Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
        exit(success ? 1 : 0)
    }

    // MARK: - SQLite helpers

    private static func runSQLite(dbPath: String, sql: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, sql]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func loadSettings(path: String) -> TaskSettings {
        let create = """
        CREATE TABLE IF NOT EXISTS task_maths (
            unique_id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 1,
            problems_per_n INTEGER NOT NULL DEFAULT 5,
            adding_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            attempts_per_problem INTEGER NOT NULL DEFAULT 1,
            timed BOOLEAN NOT NULL DEFAULT 1,
            reset_immediatly_on_fail BOOLEAN NOT NULL DEFAULT 0,
            subtracking_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            multiplication_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            division_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            values_up_to_9_allowed BOOLEAN NOT NULL DEFAULT 1,
            values_up_to_100_allowed BOOLEAN NOT NULL DEFAULT 1,
            values_up_to_1000_allowed BOOLEAN NOT NULL DEFAULT 0,
            max_seconds_per_answer_adding_math_problems FLOAT NOT NULL DEFAULT 20.0,
            max_seconds_per_answer_subtracking_math_problems FLOAT NOT NULL DEFAULT 20.0,
            max_seconds_per_answer_multiplication_math_problems FLOAT NOT NULL DEFAULT 45.0,
            max_seconds_per_answer_division_math_problems FLOAT NOT NULL DEFAULT 45.0
        );
        INSERT OR IGNORE INTO task_maths (unique_id) VALUES (1);
        """
        _ = runSQLite(dbPath: path, sql: create)
        let query = "SELECT problems_per_n, adding_math_problems_allowed, attempts_per_problem, timed, reset_immediatly_on_fail, subtracking_math_problems_allowed, multiplication_math_problems_allowed, division_math_problems_allowed, values_up_to_9_allowed, values_up_to_100_allowed, values_up_to_1000_allowed, max_seconds_per_answer_adding_math_problems, max_seconds_per_answer_subtracking_math_problems, max_seconds_per_answer_multiplication_math_problems, max_seconds_per_answer_division_math_problems FROM task_maths LIMIT 1;"
        let output = runSQLite(dbPath: path, sql: query).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = output.split(separator: "|").map { String($0) }
        let problemsPerN = Int(parts[safe:0] ?? "5") ?? 5
        let addAllowed = (Int(parts[safe:1] ?? "1") ?? 1) != 0
        let attemptsPer = Int(parts[safe:2] ?? "1") ?? 1
        let timed = (Int(parts[safe:3] ?? "1") ?? 1) != 0
        let reset = (Int(parts[safe:4] ?? "0") ?? 0) != 0
        let subAllowed = (Int(parts[safe:5] ?? "1") ?? 1) != 0
        let mulAllowed = (Int(parts[safe:6] ?? "1") ?? 1) != 0
        let divAllowed = (Int(parts[safe:7] ?? "1") ?? 1) != 0
        let up100 = (Int(parts[safe:9] ?? "1") ?? 1) != 0
        let up1000 = (Int(parts[safe:10] ?? "0") ?? 0) != 0
        let secAdd = Double(parts[safe:11] ?? "20.0") ?? 20.0
        let secSub = Double(parts[safe:12] ?? "20.0") ?? 20.0
        let secMul = Double(parts[safe:13] ?? "45.0") ?? 45.0
        let secDiv = Double(parts[safe:14] ?? "45.0") ?? 45.0
        var ops: [Operation] = []
        if addAllowed { ops.append(.add) }
        if subAllowed { ops.append(.sub) }
        if mulAllowed { ops.append(.mul) }
        if divAllowed { ops.append(.div) }
        let maxValue: Int = up1000 ? 1000 : (up100 ? 100 : 9)
        return TaskSettings(
            problemsPerN: problemsPerN,
            attemptsPerProblem: attemptsPer,
            timed: timed,
            resetImmediatelyOnFail: reset,
            allowedOperations: ops,
            maxSeconds: [.add: secAdd, .sub: secSub, .mul: secMul, .div: secDiv],
            valueRange: 1...maxValue
        )
    }

    private static func loadMemory(path: String) -> TaskMemory {
        let create = """
        CREATE TABLE IF NOT EXISTS task_maths_memory (
            unique_id INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE NOT NULL DEFAULT 1,
            last_task_was_for_access_to_app_unique_id STRING UNIQUE NOT NULL DEFAULT '',
            current_N_owned_total INTEGER NOT NULL DEFAULT 0,
            current_N_compleated INTEGER NOT NULL DEFAULT 0,
            max_possible_score INTEGER NOT NULL DEFAULT 0,
            current_score INTEGER NOT NULL DEFAULT 0,
            task_started_at STRING,
            process_ended_without_pass_or_fail BOOLEAN NOT NULL DEFAULT 0
        );
        INSERT OR IGNORE INTO task_maths_memory (unique_id) VALUES (1);
        """
        _ = runSQLite(dbPath: path, sql: create)
        let query = "SELECT current_N_owned_total, current_N_compleated, max_possible_score, current_score FROM task_maths_memory LIMIT 1;"
        let output = runSQLite(dbPath: path, sql: query).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = output.split(separator: "|").map { String($0) }
        let total = Int(parts[safe:0] ?? "0") ?? 0
        let completed = Int(parts[safe:1] ?? "0") ?? 0
        let maxScore = Int(parts[safe:2] ?? "0") ?? 0
        let score = Int(parts[safe:3] ?? "0") ?? 0
        return TaskMemory(currentNTotal: total, currentNCompleted: completed, maxPossibleScore: maxScore, currentScore: score)
    }

    private static func saveMemory(path: String, _ mem: TaskMemory) {
        let update = "UPDATE task_maths_memory SET current_N_owned_total=\(mem.currentNTotal), current_N_compleated=\(mem.currentNCompleted), max_possible_score=\(mem.maxPossibleScore), current_score=\(mem.currentScore), process_ended_without_pass_or_fail=0 WHERE unique_id=1;"
        _ = runSQLite(dbPath: path, sql: update)
    }

    private static func generateProblem(_ settings: TaskSettings) -> (Operation, String, Int) {
        let op = settings.allowedOperations.randomElement() ?? .add
        let range = settings.valueRange
        switch op {
        case .add:
            let a = Int.random(in: range)
            let b = Int.random(in: range)
            return (op, "\(a) + \(b) =", a + b)
        case .sub:
            let a = Int.random(in: range)
            let b = Int.random(in: 1...a)
            return (op, "\(a) - \(b) =", a - b)
        case .mul:
            let a = Int.random(in: range)
            let b = Int.random(in: range)
            return (op, "\(a) * \(b) =", a * b)
        case .div:
            let b = Int.random(in: 1...range.upperBound)
            let ans = Int.random(in: range)
            let a = b * ans
            return (op, "\(a) / \(b) =", ans)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

struct ContentView: View {
    @EnvironmentObject var model: MathsViewModel
    @State private var timeLeft: Double? = nil
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // Header: progress and timer
            let prog = model.progressCounts()
            ProgressView(value: Double(prog.completed), total: Double(prog.total))
                .progressViewStyle(.linear)
            HStack {
                Text("Completed: \(prog.completed)/\(prog.total)")
                Spacer()
                if let tl = timeLeft {
                    Text("Time left: \(Int(ceil(tl)))s")
                        .foregroundColor(tl > 5 ? .primary : .red)
                }
            }

            // Question
            Text(model.question)
                .font(.largeTitle)
                .bold()
            TextField("Answer", text: $model.answerInput)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)
                .onSubmit { model.submit() }
            Button("Submit") { model.submit() }
                .keyboardShortcut(.return)

            if !model.status.isEmpty {
                Text(model.status)
                    .font(.title3)
                    .foregroundColor(model.status == "Correct" ? .green : .red)
            }
        }
        .padding()
        .onReceive(timer) { _ in
            timeLeft = model.timeRemainingSeconds()
        }
    }

    // No additional helpers needed; UI queries VM directly
}

#Preview {
    ContentView().environmentObject(MathsViewModel(N: 1, gradeTasks: true, minGrade: 0.95))
}
