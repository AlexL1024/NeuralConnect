import os.log

enum NHLogger {
    static let zone     = Logger(subsystem: "NeuralConnect", category: "Zone")
    static let dialogue = Logger(subsystem: "NeuralConnect", category: "Dialogue")
    static let memory   = Logger(subsystem: "NeuralConnect", category: "Memory")
    static let brain    = Logger(subsystem: "NeuralConnect", category: "Brain")
    static let scene    = Logger(subsystem: "NeuralConnect", category: "Scene")
    static let system   = Logger(subsystem: "NeuralConnect", category: "System")
}
