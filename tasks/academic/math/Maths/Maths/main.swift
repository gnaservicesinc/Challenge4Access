import Foundation

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

struct Settings {
    let problemsPerN: Int
    let attemptsPerProblem: Int
    let timed: Bool
    let resetImmediatelyOnFail: Bool
    let allowedOperations: [Operation]
    let maxSeconds: [Operation: Double]
    let valueRange: ClosedRange<Int>
}

struct Memory {
    var currentNTotal: Int
    var currentNCompleted: Int
    var maxPossibleScore: Int
    var currentScore: Int
}

func runSQLite(dbPath: String, sql: String) -> String {
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

func loadSettings(path: String) -> Settings {
    let createSQL = """
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
    _ = runSQLite(dbPath: path, sql: createSQL)
    let query = "SELECT problems_per_n, adding_math_problems_allowed, attempts_per_problem, timed, reset_immediatly_on_fail, subtracking_math_problems_allowed, multiplication_math_problems_allowed, division_math_problems_allowed, values_up_to_9_allowed, values_up_to_100_allowed, values_up_to_1000_allowed, max_seconds_per_answer_adding_math_problems, max_seconds_per_answer_subtracking_math_problems, max_seconds_per_answer_multiplication_math_problems, max_seconds_per_answer_division_math_problems FROM task_maths LIMIT 1;"
    let output = runSQLite(dbPath: path, sql: query).trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = output.split(separator: "|").map { String($0) }
    let problemsPerN = Int(parts[0]) ?? 5
    let addAllowed = (Int(parts[1]) ?? 1) != 0
    let attemptsPerProblem = Int(parts[2]) ?? 1
    let timed = (Int(parts[3]) ?? 1) != 0
    let reset = (Int(parts[4]) ?? 0) != 0
    let subAllowed = (Int(parts[5]) ?? 1) != 0
    let mulAllowed = (Int(parts[6]) ?? 1) != 0
    let divAllowed = (Int(parts[7]) ?? 1) != 0
    let up100 = (Int(parts[9]) ?? 1) != 0
    let up1000 = (Int(parts[10]) ?? 0) != 0
    let secAdd = Double(parts[11]) ?? 20.0
    let secSub = Double(parts[12]) ?? 20.0
    let secMul = Double(parts[13]) ?? 45.0
    let secDiv = Double(parts[14]) ?? 45.0
    var ops: [Operation] = []
    if addAllowed { ops.append(.add) }
    if subAllowed { ops.append(.sub) }
    if mulAllowed { ops.append(.mul) }
    if divAllowed { ops.append(.div) }
    let maxValue: Int
    if up1000 { maxValue = 1000 } else if up100 { maxValue = 100 } else { maxValue = 9 }
    return Settings(
        problemsPerN: problemsPerN,
        attemptsPerProblem: attemptsPerProblem,
        timed: timed,
        resetImmediatelyOnFail: reset,
        allowedOperations: ops,
        maxSeconds: [.add: secAdd, .sub: secSub, .mul: secMul, .div: secDiv],
        valueRange: 1...maxValue
    )
}

func loadMemory(path: String) -> Memory {
    let createSQL = """
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
    _ = runSQLite(dbPath: path, sql: createSQL)
    let query = "SELECT current_N_owned_total, current_N_compleated, max_possible_score, current_score FROM task_maths_memory LIMIT 1;"
    let output = runSQLite(dbPath: path, sql: query).trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = output.split(separator: "|").map { String($0) }
    let total = Int(parts[0]) ?? 0
    let completed = Int(parts[1]) ?? 0
    let maxScore = Int(parts[2]) ?? 0
    let score = Int(parts[3]) ?? 0
    return Memory(currentNTotal: total, currentNCompleted: completed, maxPossibleScore: maxScore, currentScore: score)
}

func saveMemory(path: String, _ mem: Memory) {
    let update = "UPDATE task_maths_memory SET current_N_owned_total=\(mem.currentNTotal), current_N_compleated=\(mem.currentNCompleted), max_possible_score=\(mem.maxPossibleScore), current_score=\(mem.currentScore), process_ended_without_pass_or_fail=0 WHERE unique_id=1;"
    _ = runSQLite(dbPath: path, sql: update)
}

func generateProblem(_ settings: Settings) -> (Operation, String, Int) {
    let op = settings.allowedOperations.randomElement() ?? .add
    let range = settings.valueRange
    switch op {
    case .add:
        let a = Int.random(in: range)
        let b = Int.random(in: range)
        return (op, "\(a) + \(b) = ", a + b)
    case .sub:
        let a = Int.random(in: range)
        let b = Int.random(in: 1...a)
        return (op, "\(a) - \(b) = ", a - b)
    case .mul:
        let a = Int.random(in: range)
        let b = Int.random(in: range)
        return (op, "\(a) * \(b) = ", a * b)
    case .div:
        let b = Int.random(in: 1...range.upperBound)
        let ans = Int.random(in: range)
        let a = b * ans
        return (op, "\(a) / \(b) = ", ans)
    }
}

func printUsage() {
    print("Usage: maths_task N [grade_tasks=1] [min_grade_to_pass=0.95]")
}

let args = CommandLine.arguments
if args.count < 2 {
    printUsage()
    exit(-1)
}
let N = Int(args[1]) ?? 1
let gradeTasks = args.count > 2 ? (Int(args[2]) ?? 1) : 1
let minGrade = args.count > 3 ? (Double(args[3]) ?? 0.95) : 0.95

let settingsPath = ProcessInfo.processInfo.environment["C4A_OUR_SETTINGS_FILE"] ?? "maths_settings.sqlite"
let memoryPath = ProcessInfo.processInfo.environment["C4A_OUR_MEMORY_FILE"] ?? "maths_memory.sqlite"

let settings = loadSettings(path: settingsPath)
var memory = loadMemory(path: memoryPath)
if memory.currentNTotal == 0 {
    memory.currentNTotal = N
}
memory.maxPossibleScore = settings.problemsPerN * memory.currentNTotal
saveMemory(path: memoryPath, memory)

let totalProblems = memory.maxPossibleScore
while memory.currentNCompleted < totalProblems {
    let (op, question, answer) = generateProblem(settings)
    var attempts = 0
    var correct = false
    while attempts < settings.attemptsPerProblem {
        print(question, terminator: "")
        let start = Date()
        guard let line = readLine(), let userAnswer = Int(line) else {
            print("Invalid input")
            attempts += 1
            continue
        }
        let elapsed = Date().timeIntervalSince(start)
        if settings.timed, let limit = settings.maxSeconds[op], elapsed > limit {
            print("Too slow")
        } else if userAnswer == answer {
            correct = true
            break
        } else {
            print("Incorrect")
        }
        attempts += 1
        if gradeTasks == 0 {
            memory.currentNCompleted += 1
            saveMemory(path: memoryPath, memory)
            exit(0)
        }
    }
    memory.currentNCompleted += 1
    if correct { memory.currentScore += 1 }
    saveMemory(path: memoryPath, memory)
    if gradeTasks == 1 && settings.resetImmediatelyOnFail {
        let remaining = totalProblems - memory.currentNCompleted
        let possible = memory.currentScore + remaining
        let projected = Double(possible) / Double(totalProblems)
        if projected < minGrade {
            memory.currentScore = 0
            saveMemory(path: memoryPath, memory)
            exit(0)
        }
    }
}

let grade = Double(memory.currentScore) / Double(totalProblems)
saveMemory(path: memoryPath, memory)
if gradeTasks == 0 {
    exit(memory.currentScore == totalProblems ? 1 : 0)
} else {
    exit(grade >= minGrade ? 1 : 0)
}
