import XCTest
@testable import Harvest

final class QuestionScoringTests: XCTestCase {
    /// Helper: build a question with N options on N axes, given a weighting.
    private func makeQuestion(
        id: String,
        weighting: QuestionWeighting,
        optionAxes: [ValueAxis]
    ) -> Question {
        let options = optionAxes.enumerated().map { i, axis in
            QuestionOption(
                id: "\(id)_\(i)",
                questionId: id,
                label: "opt \(i)",
                axis: axis,
                displayOrder: i
            )
        }
        return Question(
            id: id,
            prompt: "prompt \(id)",
            weighting: weighting,
            displayOrder: 0,
            options: options
        )
    }

    func testWeightMatrix_needQuestion() {
        let (n, b) = AxisScoring.weights(for: .need)
        XCTAssertEqual(n, 1.0)
        XCTAssertEqual(b, 0.5)
    }

    func testWeightMatrix_bringQuestion() {
        let (n, b) = AxisScoring.weights(for: .bring)
        XCTAssertEqual(n, 0.5)
        XCTAssertEqual(b, 1.0)
    }

    func testWeightMatrix_bothQuestion() {
        let (n, b) = AxisScoring.weights(for: .both)
        XCTAssertEqual(n, 1.0)
        XCTAssertEqual(b, 1.0)
    }

    func testComputeVectors_emptyAnswers() {
        let result = AxisScoring.computeVectors(answers: [:], questions: [])
        XCTAssertTrue(result.need.isZero)
        XCTAssertTrue(result.bring.isZero)
    }

    func testComputeVectors_singleNeedAnswer() {
        let q = makeQuestion(
            id: "q1",
            weighting: .need,
            optionAxes: [.emotionalIntelligence, .stability, .integrity, .connection, .growth]
        )
        let answers = ["q1": "q1_0"]   // user picked Emotional Intelligence

        let result = AxisScoring.computeVectors(answers: answers, questions: [q])

        // need: 1.0 to EI; normalized => EI = 1.0
        XCTAssertEqual(result.need.emotionalIntelligence, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.need.sum, 1.0, accuracy: 0.0001)
        // bring: 0.5 to EI; normalized => EI = 1.0
        XCTAssertEqual(result.bring.emotionalIntelligence, 1.0, accuracy: 0.0001)
    }

    func testComputeVectors_mixedWeightings() {
        let qNeed = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let qBring = makeQuestion(id: "q2", weighting: .bring, optionAxes: [.growth])
        let qBoth = makeQuestion(id: "q3", weighting: .both, optionAxes: [.integrity])

        let answers = ["q1": "q1_0", "q2": "q2_0", "q3": "q3_0"]

        let result = AxisScoring.computeVectors(answers: answers, questions: [qNeed, qBring, qBoth])

        // need raw: connection=1.0, growth=0.5, integrity=1.0 -> total 2.5
        XCTAssertEqual(result.need.connection, 1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.growth,     0.5 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.integrity,  1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.need.sum, 1.0, accuracy: 0.0001)

        // bring raw: connection=0.5, growth=1.0, integrity=1.0 -> total 2.5
        XCTAssertEqual(result.bring.connection, 0.5 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.bring.growth,     1.0 / 2.5, accuracy: 0.0001)
        XCTAssertEqual(result.bring.integrity,  1.0 / 2.5, accuracy: 0.0001)
    }

    func testComputeVectors_answerForUnknownQuestionIsIgnored() {
        let q = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let answers = ["qX": "qX_0", "q1": "q1_0"]   // qX has no question
        let result = AxisScoring.computeVectors(answers: answers, questions: [q])
        XCTAssertEqual(result.need.connection, 1.0, accuracy: 0.0001)
    }

    func testComputeVectors_unknownOptionIsIgnored() {
        let q = makeQuestion(id: "q1", weighting: .need, optionAxes: [.connection])
        let answers = ["q1": "q1_99"]   // option id doesn't exist
        let result = AxisScoring.computeVectors(answers: answers, questions: [q])
        XCTAssertTrue(result.need.isZero)
    }
}
