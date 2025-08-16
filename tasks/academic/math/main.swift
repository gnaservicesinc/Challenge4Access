import Foundation

// Math task application
// Accepts CLI arguments: N (difficulty/length), grade_tasks, min_grade_to_pass
// Returns exit code 1 for pass, 0 for fail

// Default configuration values based on README
let problemsPerN = 5
let attemptsPerProblem = 1
let allowedOperations: [String] = ["+", "-", "*", "/"]

let args = CommandLine.arguments

func printUsage() {
    print("Usage: maths N [grade_tasks=1] [min_grade_to_pass=0.95]")
}

// Parse CLI arguments
if args.count < 2 {
    printUsage()
    exit(-1)
}

let N = Int(args[1]) ?? 1
let gradeTasks = args.count > 2 ? (Int(args[2]) ?? 1) : 1
let minGrade = args.count > 3 ? (Double(args[3]) ?? 0.95) : 0.95

let totalProblems = max(1, N * problemsPerN)
var correctAnswers = 0
var askedProblems = 0

func generateProblem() -> (String, Int) {
    let op = allowedOperations.randomElement()!
    switch op {
    case "+":
        let a = Int.random(in: 1...9)
        let b = Int.random(in: 1...9)
        return ("\(a) + \(b) = ", a + b)
    case "-":
        let a = Int.random(in: 1...9)
        let b = Int.random(in: 1...a) // ensure non-negative
        return ("\(a) - \(b) = ", a - b)
    case "*":
        let a = Int.random(in: 1...9)
        let b = Int.random(in: 1...9)
        return ("\(a) * \(b) = ", a * b)
    default: // division
        let b = Int.random(in: 1...9)
        let ans = Int.random(in: 1...9)
        let a = b * ans
        return ("\(a) / \(b) = ", ans)
    }
}

while askedProblems < totalProblems {
    let (question, answer) = generateProblem()
    var attempts = 0
    var correct = false
    while attempts < attemptsPerProblem {
        print(question, terminator: "")
        guard let line = readLine(), let userAnswer = Int(line) else {
            print("Invalid input")
            attempts += 1
            continue
        }
        if userAnswer == answer {
            correct = true
            break
        } else {
            print("Incorrect")
            attempts += 1
            if gradeTasks == 0 {
                exit(0)
            }
        }
    }
    askedProblems += 1
    if correct { correctAnswers += 1 }
}

let grade = Double(correctAnswers) / Double(totalProblems)

if gradeTasks == 0 {
    if correctAnswers == totalProblems {
        exit(1)
    } else {
        exit(0)
    }
} else {
    if grade >= minGrade {
        exit(1)
    } else {
        exit(0)
    }
}
