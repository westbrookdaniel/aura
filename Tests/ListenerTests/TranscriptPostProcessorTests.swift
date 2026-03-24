import Testing
@testable import Listener

struct TranscriptPostProcessorTests {
    @Test
    func correctsCloseTechnicalTerms() {
        let output = TranscriptPostProcessor.process(
            "open x code and cursor",
            vocabulary: ["Xcode", "Cursor"]
        )

        #expect(output.contains("Xcode"))
        #expect(output.contains("Cursor"))
    }

    @Test
    func preservesTechnicalSeparators() {
        let output = TranscriptPostProcessor.process(
            "go to /users/dan/downloads and package swift",
            vocabulary: ["/Users", "Package.swift"]
        )

        #expect(output.contains("/Users"))
    }
}
