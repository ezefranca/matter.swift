@MainActor
protocol P5SketchInternal {
    var isLooping: Bool { get set }
    var framesPerSecond: Double { get set }
    var userWantsRedraw: Bool { get set }

    func addOperation(_ operation: P5Operation)
}
