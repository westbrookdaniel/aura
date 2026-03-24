import Foundation

@MainActor
final class VocabularyStore: ObservableObject {
    @Published var customTermsText: String {
        didSet {
            UserDefaults.standard.set(customTermsText, forKey: Keys.customTermsText)
        }
    }

    private enum Keys {
        static let customTermsText = "accuracy.customTermsText"
    }

    private let bundledTerms: [String]

    init() {
        self.customTermsText = UserDefaults.standard.string(forKey: Keys.customTermsText) ?? ""
        self.bundledTerms = Self.loadBundledTerms()
    }

    var bundledDisplayText: String {
        bundledTerms.joined(separator: "\n")
    }

    var customTerms: [String] {
        normalizedTerms(from: customTermsText)
    }

    var allTerms: [String] {
        Array(Set(bundledTerms + customTerms)).sorted()
    }

    func resetCustomTerms() {
        customTermsText = ""
    }

    func importTerms(from url: URL) throws {
        let imported = try String(contentsOf: url, encoding: .utf8)
        customTermsText = imported
    }

    func exportTerms(to url: URL) throws {
        try customTermsText.write(to: url, atomically: true, encoding: .utf8)
    }

    private func normalizedTerms(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private static func loadBundledTerms() -> [String] {
        guard let url = Bundle.module.url(forResource: "BundledVocabulary", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
