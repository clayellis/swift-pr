protocol PRCheckStep {
    associatedtype Output
    static var name: String { get }
    func run() async throws -> Output
}

//extension PRCheckStep {
//    var pr: PR { (any PRCheck).self.pr }
//}

extension PRCheck {
    func run<Step: PRCheckStep>(step: Step) async throws -> Step.Output {
        try await step.run()
    }
}

//struct FirstStep: PRCheckStep {
//    static let name = "First"
//
//    struct Output {
//        let value: Int
//    }
//
//    func run() async throws -> Output {
//
//    }
//}
