//
//  ContentView.swift
//  Count
//
//  Created by Andrew Smith on 8/16/25.
//
import SwiftUI
import AppKit
internal import Combine

let C4A_OUR_SETTINGS_FILE = "/opt/c4a/protected/ro/task_settings/count"

enum CShape: CaseIterable { case circle, square, triangle }
struct CColor { let name: String; let color: Color }
let palette: [CColor] = [
    .init(name: "red", color: .red),
    .init(name: "green", color: .green),
    .init(name: "blue", color: .blue),
    .init(name: "orange", color: .orange),
    .init(name: "purple", color: .purple)
]

struct DrawItem: Identifiable { let id = UUID(); let shape: CShape; let color: CColor; let rect: CGRect }

final class CountViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var answerInput: String = ""
    @Published var status: String = ""
    @Published var items: [DrawItem] = []

    private let N: Int
    private let gradeTasks: Bool
    private let minGrade: Double
    private var roundsTotal: Int
    private var roundIndex: Int = 0
    private var score: Int = 0
    private var target: Int = 0
    private var conditions: [(CShape, CColor)] = []
    private var lastCanvasSize: CGSize? = nil

    init(N: Int, gradeTasks: Bool, minGrade: Double) {
        self.N = max(1, N)
        self.gradeTasks = gradeTasks
        self.minGrade = minGrade
        self.roundsTotal = max(1, N)
    }

    func setCanvasSize(_ size: CGSize) { lastCanvasSize = size }

    func nextRound(canvasSize: CGSize) {
        guard roundIndex < roundsTotal else { finish() ; return }
        let count = min(150, 30 + N*5)
        let minSize: CGFloat = 16
        let maxSize: CGFloat = 48
        var placed: [DrawItem] = []
        var forceOverlapCountdown = 5
        let w = max(200.0, canvasSize.width)
        let h = max(200.0, canvasSize.height)
        for _ in 0..<count {
            let shape = CShape.allCases.randomElement()!
            let col = palette.randomElement()!
            let sz = CGFloat.random(in: minSize...maxSize)
            let x = CGFloat.random(in: sz...(w - sz))
            let y = CGFloat.random(in: sz...(h - sz))
            let r = CGRect(x: x - sz/2, y: y - sz/2, width: sz, height: sz)
            var accept = true
            // some overlap but not too much
            if forceOverlapCountdown == 0 {
                // allow forced overlaps occasionally
                forceOverlapCountdown = 5
            } else {
                for it in placed {
                    let inter = it.rect.intersection(r)
                    if !inter.isNull {
                        let overlapRatio = (inter.width * inter.height) / (r.width * r.height)
                        if overlapRatio > 0.5 { accept = false; break }
                    }
                }
                forceOverlapCountdown -= 1
            }
            if accept { placed.append(DrawItem(shape: shape, color: col, rect: r)) }
        }
        self.items = placed

        // Choose 1 or 2 conditions depending on N
        var conds: [(CShape, CColor)] = []
        conds.append( (CShape.allCases.randomElement()!, palette.randomElement()!) )
        if N >= 4 && Bool.random() {
            var k: (CShape, CColor)
            repeat { k = (CShape.allCases.randomElement()!, palette.randomElement()!) } while (k.0 == conds[0].0 && k.1.name == conds[0].1.name)
            conds.append(k)
        }
        self.conditions = conds
        self.target = placed.filter { it in conds.contains(where: { $0.0 == it.shape && $0.1.name == it.color.name }) }.count

        if conds.count == 1 {
            prompt = "Count all of the \(conds[0].1.name) \(name(of: conds[0].0))."
        } else {
            prompt = "Count all of the \(conds[0].1.name) \(name(of: conds[0].0)) and \(conds[1].1.name) \(name(of: conds[1].0))."
        }
        answerInput = ""
        status = ""
    }

    func submit() {
        guard let v = Int(answerInput) else { wrong() ; return }
        if v == target { right() } else { wrong() }
    }

    private func right() {
        score += 1
        roundIndex += 1
        if roundIndex >= roundsTotal { finish() } else if let size = lastCanvasSize { nextRound(canvasSize: size) }
    }

    private func wrong() {
        if !gradeTasks { exit(0) }
        roundIndex += 1
        if roundIndex >= roundsTotal { finish() } else if let size = lastCanvasSize { nextRound(canvasSize: size) }
    }

    private func finish() {
        if gradeTasks {
            let grade = Double(score) / Double(roundsTotal)
            exit(grade >= minGrade ? 1 : 0)
        } else {
            exit(score == roundsTotal ? 1 : 0)
        }
    }

    func fail(reason: String) { status = reason; exit(0) }

    private func name(of s: CShape) -> String { switch s { case .circle: return "circles"; case .square: return "squares"; case .triangle: return "triangles" } }
}

struct ContentView: View {
    @EnvironmentObject var model: CountViewModel
    @State private var canvasSize: CGSize = .zero
    @State private var localMonitor: Any? = nil
    @State private var globalMonitor: Any? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("Count Task").font(.title)
            Text(model.prompt).font(.headline)
                .padding(.bottom, 8)
            GeometryReader { proxy in
                Canvas { ctx, size in
                    drawItems(ctx: ctx)
                }
                .onAppear {
                    canvasSize = proxy.size
                    model.setCanvasSize(proxy.size)
                    model.nextRound(canvasSize: proxy.size)
                }
                .onChange(of: proxy.size) { oldSize, newSize in
                    canvasSize = newSize
                    model.setCanvasSize(newSize)
                }
            }
            .background(Color.black.opacity(0.05))

            HStack {
                TextField("Answer", text: $model.answerInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .multilineTextAlignment(.center)
                    .onSubmit { model.submit() }
                Button("Submit") { model.submit() }
                    .keyboardShortcut(.return)
            }
            if !model.status.isEmpty { Text(model.status).foregroundColor(.red) }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .onAppear { enterFullScreen(); installMonitors() }
        .onDisappear { removeMonitors() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            model.fail(reason: "Lost focus")
        }
    }

    private func drawItems(ctx: GraphicsContext) {
        for it in model.items {
            var path = Path()
            switch it.shape {
            case .circle:
                path.addEllipse(in: it.rect)
            case .square:
                path.addRect(it.rect)
            case .triangle:
                let r = it.rect
                path.move(to: CGPoint(x: r.midX, y: r.minY))
                path.addLines([
                    CGPoint(x: r.minX, y: r.maxY),
                    CGPoint(x: r.maxX, y: r.maxY),
                    CGPoint(x: r.midX, y: r.minY)
                ])
            }
            ctx.fill(path, with: .color(it.color.color))
            ctx.stroke(path, with: .color(.black.opacity(0.2)))
        }
    }

    private func enterFullScreen() {
        if let w = NSApplication.shared.windows.first { w.toggleFullScreen(nil) }
    }

    private func installMonitors() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if let chars = event.characters, chars.range(of: "^[0-9\r\n]$", options: .regularExpression) != nil {
                    return event
                } else {
                    model.fail(reason: "Invalid key")
                    return nil
                }
            }
        }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                model.fail(reason: "Mouse moved")
            }
        }
    }

    private func removeMonitors() {
        if let lm = localMonitor { NSEvent.removeMonitor(lm); localMonitor = nil }
        if let gm = globalMonitor { NSEvent.removeMonitor(gm); globalMonitor = nil }
    }
}
