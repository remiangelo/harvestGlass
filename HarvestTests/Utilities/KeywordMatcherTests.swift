import XCTest
@testable import Harvest

final class KeywordMatcherTests: XCTestCase {

    // MARK: - Whole-word matching

    /// The bug that started this: "hello" matched the keyword "hell".
    func testDoesNotMatchInsideALongerWord() {
        let hello = KeywordMatcher.normalize("hello")
        XCTAssertFalse(KeywordMatcher.contains("hell", in: hello))

        XCTAssertFalse(KeywordMatcher.contains("hoe", in: KeywordMatcher.normalize("Nice shoes!")))
        XCTAssertFalse(KeywordMatcher.contains("break", in: KeywordMatcher.normalize("grab breakfast")))
        XCTAssertFalse(KeywordMatcher.contains("act now", in: KeywordMatcher.normalize("I'll contact now")))
    }

    /// "one of us" and "half up" both contain the literal substring "f u".
    func testDoesNotMatchAcrossWordInteriors() {
        XCTAssertFalse(KeywordMatcher.contains("f u", in: KeywordMatcher.normalize("One of us should pick")))
        XCTAssertFalse(KeywordMatcher.contains("f u", in: KeywordMatcher.normalize("half up front")))
        XCTAssertFalse(KeywordMatcher.contains("i love you", in: KeywordMatcher.normalize("I love your dog")))
    }

    func testMatchesWholeWords() {
        XCTAssertTrue(KeywordMatcher.contains("hell", in: KeywordMatcher.normalize("go to hell")))
        XCTAssertTrue(KeywordMatcher.contains("f u", in: KeywordMatcher.normalize("f u")))
        XCTAssertTrue(KeywordMatcher.contains("i love you", in: KeywordMatcher.normalize("I love you")))
    }

    func testMatchesSimpleInflectionsOfSingleWords() {
        for text in ["he is stalking me", "she stalked me", "he stalks everyone"] {
            XCTAssertTrue(
                KeywordMatcher.contains("stalk", in: KeywordMatcher.normalize(text)),
                "expected \(text) to match"
            )
        }
    }

    func testDoesNotInflectPhrases() {
        XCTAssertFalse(KeywordMatcher.contains("send money", in: KeywordMatcher.normalize("send moneys")))
    }

    // MARK: - Normalization

    func testIgnoresCasePunctuationAndApostropheStyle() {
        XCTAssertTrue(KeywordMatcher.contains("can't leave me", in: KeywordMatcher.normalize("You CAN'T leave me!")))
        XCTAssertTrue(KeywordMatcher.contains("can't leave me", in: KeywordMatcher.normalize("you can\u{2019}t leave me")))
        XCTAssertTrue(KeywordMatcher.contains("can't leave me", in: KeywordMatcher.normalize("you cant leave me")))
    }

    func testEmojiAndPunctuationDoNotBreakMatching() {
        XCTAssertTrue(KeywordMatcher.contains("send nudes", in: KeywordMatcher.normalize("send nudes 😏😏")))
        XCTAssertEqual(KeywordMatcher.normalize("hi!!"), "hi")
    }

    // MARK: - Directed matching

    func testDirectedTermNeedsASecondPersonWordInTheSameClause() {
        let benign = KeywordMatcher.clauses("I need to kill some time before our date")
        XCTAssertFalse(KeywordMatcher.containsDirected("kill", inClauses: benign))

        let threat = KeywordMatcher.clauses("I'll kill you if you leave")
        XCTAssertTrue(KeywordMatcher.containsDirected("kill", inClauses: threat))
    }

    /// Clause splitting is what keeps a second-person word in one half of the
    /// sentence from arming an insult in the other half.
    func testSecondPersonInADifferentClauseDoesNotCount() {
        let clauses = KeywordMatcher.clauses("You know, that was stupid of me")
        XCTAssertFalse(KeywordMatcher.containsDirected("stupid", inClauses: clauses))

        XCTAssertTrue(
            KeywordMatcher.containsDirected("stupid", inClauses: KeywordMatcher.clauses("you are stupid"))
        )
    }

    func testAddressesOtherPersonRecognizesShorthand() {
        XCTAssertTrue(KeywordMatcher.addressesOtherPerson(KeywordMatcher.normalize("ur the worst")))
        XCTAssertTrue(KeywordMatcher.addressesOtherPerson(KeywordMatcher.normalize("u there")))
        XCTAssertFalse(KeywordMatcher.addressesOtherPerson(KeywordMatcher.normalize("young and free")))
    }
}
