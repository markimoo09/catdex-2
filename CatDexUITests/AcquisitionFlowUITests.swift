import XCTest

/// End to end: a photo goes through the appraisal, the seal is broken, and the
/// lot lands in the collection with a dossier.
final class AcquisitionFlowUITests: XCTestCase {

    private func fixture(_ name: String) -> String {
        Bundle(for: Self.self).path(forResource: name, ofType: nil)!
    }

    override func setUp() {
        continueAfterFailure = false
    }

    func testPhotoBecomesALotInTheCollection() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "RESET": "1",
            "NO_SPLASH": "1",
            "AUTO_PHOTO": fixture("fixture-cat.jpg"),
            "AUTO_PRECUT": fixture("fixture-cat-cutout.png"),
            "FORCE_MARQUE": "gold",
            "AUTO_UNSEAL": "1",
            "AUTO_ADD": "1",
        ]
        app.launch()

        let audience = app.buttons["Request an Audience"]
        XCTAssertTrue(audience.waitForExistence(timeout: 40), "the new lot's dossier should open")
        XCTAssertTrue(app.staticTexts["Curator's note"].exists)

        app.buttons["Back"].tap()
        if !app.buttons["Salon"].waitForExistence(timeout: 5) {
            let lines = app.debugDescription.split(separator: "\n").filter { $0.contains("Button") }.joined(separator: " | ")
            XCTFail("tab bar should return after leaving the dossier. Buttons: \(lines)")
        }
        app.buttons["Patron"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Patron card'")).firstMatch
            .waitForExistence(timeout: 5))
    }

    func testConcoursPlaysThroughToAVerdict() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "RESET": "1",
            "NO_SPLASH": "1",
            "SEED_DIR": (fixture("fixture-cat.jpg") as NSString).deletingLastPathComponent,
            "SEED_REPEAT": "3",
            "OPEN": "match",
            "AUTO_MATCH": "1",
            "AUTO_PLAY": "1",
        ]
        app.launch()

        let verdict = app.staticTexts.matching(NSPredicate(format: "label == 'Best in show' OR label == 'Runner-up'")).firstMatch
        XCTAssertTrue(verdict.waitForExistence(timeout: 40), "the match should reach a verdict")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Shows"].waitForExistence(timeout: 5))
    }

    func testAudienceRepliesInCharacter() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "RESET": "1",
            "NO_SPLASH": "1",
            "AUTO_PHOTO": fixture("fixture-cat.jpg"),
            "AUTO_PRECUT": fixture("fixture-cat-cutout.png"),
            "AUTO_UNSEAL": "1",
            "AUTO_ADD": "1",
        ]
        app.launch()

        let audience = app.buttons["Request an Audience"]
        XCTAssertTrue(audience.waitForExistence(timeout: 40))
        audience.tap()

        let letters = app.descendants(matching: .any).matching(identifier: "catLetter")
        XCTAssertTrue(letters.firstMatch.waitForExistence(timeout: 5), "the cat should greet first")

        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Are you hungry?")
        app.buttons["sendLetter"].tap()

        expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: letters)
        waitForExpectations(timeout: 25)
    }
}
