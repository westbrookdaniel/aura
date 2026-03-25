import AppKit
import Combine
import Foundation
import Sparkle

enum SparkleConfigurationError: LocalizedError, Equatable {
    case notPackagedApp
    case missingFeedURL
    case missingPublicEDKey

    var errorDescription: String? {
        switch self {
        case .notPackagedApp:
            return "Automatic updates are only available from the packaged Aura.app build."
        case .missingFeedURL:
            return "Automatic updates are unavailable because this build is missing a Sparkle feed URL."
        case .missingPublicEDKey:
            return "Automatic updates are unavailable because this build is missing a Sparkle EdDSA public key."
        }
    }
}

struct SparkleConfiguration: Equatable {
    let feedURL: URL
    let publicEDKey: String

    static func resolve(
        infoDictionary: [String: Any],
        bundleURL: URL
    ) -> Result<Self, SparkleConfigurationError> {
        guard bundleURL.pathExtension == "app" else {
            return .failure(.notPackagedApp)
        }

        guard let feedURLString = trimmedStringValue(infoDictionary["SUFeedURL"]),
              let feedURL = URL(string: feedURLString),
              feedURL.scheme?.isEmpty == false
        else {
            return .failure(.missingFeedURL)
        }

        guard let publicEDKey = trimmedStringValue(infoDictionary["SUPublicEDKey"]) else {
            return .failure(.missingPublicEDKey)
        }

        return .success(Self(feedURL: feedURL, publicEDKey: publicEDKey))
    }

    private static func trimmedStringValue(_ value: Any?) -> String? {
        guard let stringValue = value as? String else { return nil }
        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false
    @Published private(set) var unavailableReason: String?

    private let updaterController: SPUStandardUpdaterController?
    private var cancellables = Set<AnyCancellable>()

    init(bundle: Bundle = .main) {
        switch SparkleConfiguration.resolve(
            infoDictionary: bundle.infoDictionary ?? [:],
            bundleURL: bundle.bundleURL
        ) {
        case .success:
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            self.unavailableReason = nil
            self.isAvailable = true
        case .failure(let error):
            self.updaterController = nil
            self.unavailableReason = error.errorDescription
            self.isAvailable = false
        }

        allowsAutomaticUpdates = Self.booleanInfoValue(
            forKey: "SUAllowsAutomaticUpdates",
            defaultValue: true,
            bundle: bundle
        )

        bind()
        synchronizeState()
    }

    func configure(checkForUpdatesMenuItem menuItem: NSMenuItem) {
        guard let updaterController else {
            menuItem.isHidden = true
            menuItem.isEnabled = false
            return
        }

        menuItem.target = updaterController
        menuItem.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        menuItem.isHidden = false
        menuItem.isEnabled = canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard let updater = updaterController?.updater else { return }
        updater.automaticallyChecksForUpdates = enabled
        synchronizeState()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        guard let updater = updaterController?.updater, allowsAutomaticUpdates else { return }
        updater.automaticallyDownloadsUpdates = enabled
        synchronizeState()
    }

    private func bind() {
        guard let updater = updaterController?.updater else { return }

        updater.publisher(for: \.canCheckForUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheckForUpdates in
                self?.canCheckForUpdates = canCheckForUpdates
            }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyChecksForUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] automaticallyChecksForUpdates in
                self?.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyDownloadsUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] automaticallyDownloadsUpdates in
                self?.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            }
            .store(in: &cancellables)
    }

    private func synchronizeState() {
        guard let updater = updaterController?.updater else {
            canCheckForUpdates = false
            automaticallyChecksForUpdates = false
            automaticallyDownloadsUpdates = false
            return
        }

        canCheckForUpdates = updater.canCheckForUpdates
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    private static func booleanInfoValue(forKey key: String, defaultValue: Bool, bundle: Bundle) -> Bool {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? NSNumber else {
            return defaultValue
        }

        return value.boolValue
    }
}
