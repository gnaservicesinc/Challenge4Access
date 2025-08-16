import SwiftUI
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Problem definitions

enum ProblemType: CaseIterable {
    case addition, subtraction, multiplication, division
    case simpleAlgebra, simpleGeometry, algebra, geometry

    func generate(range: ClosedRange<Int>) -> (String, Int) {
        switch self {
        case .addition:
            let a = Int.random(in: range)
            let b = Int.random(in: range)
            return ("\(a) + \(b) =", a + b)
        case .subtraction:
            let a = Int.random(in: range)
            let b = Int.random(in: 1...a)
            return ("\(a) - \(b) =", a - b)
        case .multiplication:
            let a = Int.random(in: range)
            let b = Int.random(in: range)
            return ("\(a) * \(b) =", a * b)
        case .division:
            let b = Int.random(in: 1...range.upperBound)
            let answer = Int.random(in: range)
            let a = b * answer
            return ("\(a) / \(b) =", answer)
        case .simpleAlgebra:
            let x = Int.random(in: range)
            let a = Int.random(in: range)
            let b = x + a
            return ("Solve x: x + \(a) = \(b)", x)
        case .simpleGeometry:
            let w = Int.random(in: range)
            let h = Int.random(in: range)
            return ("Area of rectangle \(w)×\(h)?", w * h)
        case .algebra:
            let x = Int.random(in: range)
            let a = Int.random(in: 1...max(1, range.upperBound/2))
            let b = Int.random(in: range)
            let c = a * x + b
            return ("Solve x: \(a)x + \(b) = \(c)", x)
        case .geometry:
            let base = Int.random(in: 1...max(1, range.upperBound/2)) * 2
            let height = Int.random(in: range)
            let area = (base * height) / 2
            return ("Area of triangle with base \(base) and height \(height)?", area)
        }
    }
}

struct TaskSettings {
    let attemptsPerProblem: Int
    let timed: Bool
    let resetImmediatelyOnFail: Bool
    let allowedTypes: [ProblemType]
    let perN: [ProblemType: Double]
    let maxSeconds: [ProblemType: Double]
    let valueRange: ClosedRange<Int>
}

struct TaskMemory {
    var currentNTotal: Int
    var currentNCompleted: Int
    var maxPossibleScore: Int
    var currentScore: Int
}

struct Problem {
    let type: ProblemType
    let question: String
    let answer: Int
}

// MARK: - View model

final class MathsViewModel: ObservableObject {
    @Published var question: String = ""
    @Published var answerInput: String = ""
    @Published var status: String = ""

    private var settings: TaskSettings
    @Published private(set) var memory: TaskMemory
    private let gradeTasks: Bool
    private let minGrade: Double

    private var problems: [Problem] = []
    private var startTime: Date = Date()
    private var attempts: Int = 0

    init(N: Int, gradeTasks: Bool, minGrade: Double) {
        self.gradeTasks = gradeTasks
        self.minGrade = minGrade
        self.settings = Self.loadSettings(path: C4A_OUR_SETTINGS_FILE)
        self.memory = Self.loadMemory(path: C4A_OUR_MEMORY_FILE)
        if memory.currentNTotal == 0 {
            memory.currentNTotal = N
        }
        self.problems = Self.buildProblems(N: memory.currentNTotal, settings: settings)
        memory.maxPossibleScore = problems.count
        Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
        nextQuestion()
    }

    func submit() {
        guard let provided = Int(answerInput) else {
            attempts += 1
            evaluate(correct: false)
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let currentType = problems[memory.currentNCompleted].type
        if settings.timed, let limit = settings.maxSeconds[currentType], elapsed > limit {
            status = "Too slow"
            attempts += 1
            evaluate(correct: false)
        } else if provided == problems[memory.currentNCompleted].answer {
            status = "Correct"
            evaluate(correct: true)
        } else {
            status = "Incorrect"
            attempts += 1
            evaluate(correct: false)
        }
    }

    private func evaluate(correct: Bool) {
        if correct { memory.currentScore += 1 }
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
            nextQuestion()
        }
    }

    private func nextQuestion() {
        if memory.currentNCompleted >= problems.count {
            let grade = Double(memory.currentScore) / Double(memory.maxPossibleScore)
            finish(success: grade >= minGrade)
            return
        }
        let problem = problems[memory.currentNCompleted]
        question = problem.question
        startTime = Date()
        status = ""
    }

    private func finish(success: Bool) {
        Self.saveMemory(path: C4A_OUR_MEMORY_FILE, memory)
        let result = success ? 1 : 0
        print("\(result)")
        fflush(stdout)
        exit(Int32(result))
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
            simple_algebra_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            simple_geometry_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            algebra_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            geometry_math_problems_allowed BOOLEAN NOT NULL DEFAULT 1,
            adding_math_problems_per_n FLOAT NOT NULL DEFAULT 0.1,
            subtracking_math_problems_per_n FLOAT NOT NULL DEFAULT 0.1,
            multiplication_math_problems_per_n FLOAT NOT NULL DEFAULT 0.2,
            division_math_problems_per_n FLOAT NOT NULL DEFAULT 0.2,
            simple_algebra_math_problems_per_n FLOAT NOT NULL DEFAULT 0.5,
            simple_geometry_math_problems_per_n FLOAT NOT NULL DEFAULT 0.5,
            algebra_math_problems_per_n FLOAT NOT NULL DEFAULT 0.9,
            geometry_math_problems_per_n FLOAT NOT NULL DEFAULT 0.9,
            max_seconds_per_answer_adding_math_problems FLOAT NOT NULL DEFAULT 20.0,
            max_seconds_per_answer_subtracking_math_problems FLOAT NOT NULL DEFAULT 20.0,
            max_seconds_per_answer_multiplication_math_problems FLOAT NOT NULL DEFAULT 45.0,
            max_seconds_per_answer_division_math_problems FLOAT NOT NULL DEFAULT 45.0,
            max_seconds_per_answer_simple_algebra_math_problems FLOAT NOT NULL DEFAULT 90.0,
            max_seconds_per_answer_simple_geometry_math_problems FLOAT NOT NULL DEFAULT 90.0,
            max_seconds_per_answer_algebra_math_problems FLOAT NOT NULL DEFAULT 240.0,
            max_seconds_per_answer_geometry_math_problems FLOAT NOT NULL DEFAULT 240.0
        );
        INSERT OR IGNORE INTO task_maths (unique_id) VALUES (1);
        """
        _ = runSQLite(dbPath: path, sql: create)
        let query = """
        SELECT attempts_per_problem, timed, reset_immediatly_on_fail,
               adding_math_problems_allowed, subtracking_math_problems_allowed, multiplication_math_problems_allowed, division_math_problems_allowed,
               simple_algebra_math_problems_allowed, simple_geometry_math_problems_allowed, algebra_math_problems_allowed, geometry_math_problems_allowed,
               adding_math_problems_per_n, subtracking_math_problems_per_n, multiplication_math_problems_per_n, division_math_problems_per_n,
               simple_algebra_math_problems_per_n, simple_geometry_math_problems_per_n, algebra_math_problems_per_n, geometry_math_problems_per_n,
               values_up_to_9_allowed, values_up_to_100_allowed, values_up_to_1000_allowed,
               max_seconds_per_answer_adding_math_problems, max_seconds_per_answer_subtracking_math_problems,
               max_seconds_per_answer_multiplication_math_problems, max_seconds_per_answer_division_math_problems,
               max_seconds_per_answer_simple_algebra_math_problems, max_seconds_per_answer_simple_geometry_math_problems,
               max_seconds_per_answer_algebra_math_problems, max_seconds_per_answer_geometry_math_problems
        FROM task_maths LIMIT 1;
        """
        let output = runSQLite(dbPath: path, sql: query).trimmingCharacters(in: .whitespacesAndNewlines)
        let p = output.split(separator: "|").map { String($0) }

        func bool(_ i: Int, _ def: Int = 0) -> Bool { (Int(p[safe: i]) ?? def) != 0 }
        func dbl(_ i: Int, _ def: Double) -> Double { Double(p[safe: i] ?? "") ?? def }

        let attempts = Int(p[safe:0]) ?? 1
        let timed = bool(1,1)
        let reset = bool(2,0)

        let addAllowed = bool(3,1)
        let subAllowed = bool(4,1)
        let mulAllowed = bool(5,1)
        let divAllowed = bool(6,1)
        let sAlgAllowed = bool(7,1)
        let sGeoAllowed = bool(8,1)
        let algAllowed = bool(9,1)
        let geoAllowed = bool(10,1)

        let addPerN = dbl(11,0.1)
        let subPerN = dbl(12,0.1)
        let mulPerN = dbl(13,0.2)
        let divPerN = dbl(14,0.2)
        let sAlgPerN = dbl(15,0.5)
        let sGeoPerN = dbl(16,0.5)
        let algPerN = dbl(17,0.9)
        let geoPerN = dbl(18,0.9)

        let up9 = bool(19,1)
        let up100 = bool(20,1)
        let up1000 = bool(21,0)

        let maxAdd = dbl(22,20)
        let maxSub = dbl(23,20)
        let maxMul = dbl(24,45)
        let maxDiv = dbl(25,45)
        let maxSAlg = dbl(26,90)
        let maxSGeo = dbl(27,90)
        let maxAlg = dbl(28,240)
        let maxGeo = dbl(29,240)

        var types: [ProblemType] = []
        if addAllowed { types.append(.addition) }
        if subAllowed { types.append(.subtraction) }
        if mulAllowed { types.append(.multiplication) }
        if divAllowed { types.append(.division) }
        if sAlgAllowed { types.append(.simpleAlgebra) }
        if sGeoAllowed { types.append(.simpleGeometry) }
        if algAllowed { types.append(.algebra) }
        if geoAllowed { types.append(.geometry) }

        let maxValue: Int = up1000 ? 1000 : (up100 ? 100 : 9)

        var perN: [ProblemType: Double] = [:]
        perN[.addition] = addPerN
        perN[.subtraction] = subPerN
        perN[.multiplication] = mulPerN
        perN[.division] = divPerN
        perN[.simpleAlgebra] = sAlgPerN
        perN[.simpleGeometry] = sGeoPerN
        perN[.algebra] = algPerN
        perN[.geometry] = geoPerN

        var maxSecs: [ProblemType: Double] = [:]
        maxSecs[.addition] = maxAdd
        maxSecs[.subtraction] = maxSub
        maxSecs[.multiplication] = maxMul
        maxSecs[.division] = maxDiv
        maxSecs[.simpleAlgebra] = maxSAlg
        maxSecs[.simpleGeometry] = maxSGeo
        maxSecs[.algebra] = maxAlg
        maxSecs[.geometry] = maxGeo

        return TaskSettings(
            attemptsPerProblem: attempts,
            timed: timed,
            resetImmediatelyOnFail: reset,
            allowedTypes: types,
            perN: perN,
            maxSeconds: maxSecs,
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
        let total = Int(parts[safe:0]) ?? 0
        let completed = Int(parts[safe:1]) ?? 0
        let maxScore = Int(parts[safe:2]) ?? 0
        let score = Int(parts[safe:3]) ?? 0
        return TaskMemory(currentNTotal: total, currentNCompleted: completed, maxPossibleScore: maxScore, currentScore: score)
    }

    private static func saveMemory(path: String, _ mem: TaskMemory) {
        let update = "UPDATE task_maths_memory SET current_N_owned_total=\(mem.currentNTotal), current_N_compleated=\(mem.currentNCompleted), max_possible_score=\(mem.maxPossibleScore), current_score=\(mem.currentScore), process_ended_without_pass_or_fail=0 WHERE unique_id=1;"
        _ = runSQLite(dbPath: path, sql: update)
    }

    private static func buildProblems(N: Int, settings: TaskSettings) -> [Problem] {
        var list: [Problem] = []
        for type in settings.allowedTypes {
            if let per = settings.perN[type], per > 0 {
                let count = Int(ceil(Double(N) / per))
                for _ in 0..<count {
                    let (q, a) = type.generate(range: settings.valueRange)
                    list.append(Problem(type: type, question: q, answer: a))
                }
            }
        }
        return list.shuffled()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - View

struct ContentView: View {
    @EnvironmentObject var model: MathsViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Problem \(model.memory.currentNCompleted + 1)/\(model.memory.maxPossibleScore)")
            Text(model.question)
            TextField("Answer", text: $model.answerInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.submit() }
            Button("Submit") { model.submit() }
            if !model.status.isEmpty {
                Text(model.status)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView().environmentObject(MathsViewModel(N: 1, gradeTasks: true, minGrade: 0.95))
}


