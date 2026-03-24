import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var sessionState: RecordingSessionState = .idle
    @Published var permissionState: PermissionState = .unknown
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published var lastErrorMessage: String?
    @Published var lastTranscript: String = ""
    @Published var isSettingsPresented = false
    @Published var isLaunchAtLoginEnabled = false
    @Published var whisperSetupState: InstallProgressState = .idle
    @Published var accuracyVocabularyText: String = ""
    @Published var availableMicrophones: [MicrophoneDevice] = []

    let preferences: AppPreferencesStore
    let permissionsManager: PermissionsManager
    let shortcutMonitor: ShortcutMonitor
    let overlayController: OverlayPanelController
    let audioRecorder: AudioRecorder
    let transcriptionEngine: TranscriptionEngine
    let insertionService: TextInsertionService
    let vocabularyStore: VocabularyStore

    private var cancellables = Set<AnyCancellable>()
    private var activeRecordingURL: URL?
    private var recordingStartedAt: Date?
    private var transcriptionTask: Task<Void, Never>?

    init(
        preferences: AppPreferencesStore = .shared,
        permissionsManager: PermissionsManager = PermissionsManager(),
        shortcutMonitor: ShortcutMonitor = ShortcutMonitor(),
        overlayController: OverlayPanelController = OverlayPanelController(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        transcriptionEngine: TranscriptionEngine = WhisperCLITranscriptionEngine(),
        insertionService: TextInsertionService = AccessibilityTextInsertionService(),
        vocabularyStore: VocabularyStore = VocabularyStore()
    ) {
        self.preferences = preferences
        self.permissionsManager = permissionsManager
        self.shortcutMonitor = shortcutMonitor
        self.overlayController = overlayController
        self.audioRecorder = audioRecorder
        self.transcriptionEngine = transcriptionEngine
        self.insertionService = insertionService
        self.vocabularyStore = vocabularyStore
        self.accuracyVocabularyText = vocabularyStore.customTermsText

        bind()
    }

    func start() {
        refreshPermissions()
        refreshMicrophones()
        isLaunchAtLoginEnabled = LaunchAtLoginController.shared.isEnabled
        shortcutMonitor.start(
            shortcut: preferences.shortcut,
            onPress: { [weak self] in
                Task { @MainActor in
                    self?.beginRecording()
                }
            },
            onRelease: { [weak self] in
                Task { @MainActor in
                    await self?.finishRecording()
                }
            }
        )
    }

    func stop() {
        shortcutMonitor.stop()
        _ = try? audioRecorder.stop()
        overlayController.hideAll()
        transcriptionTask?.cancel()
    }

    func updateShortcut(_ shortcut: ShortcutSpec) {
        preferences.shortcut = shortcut
        shortcutMonitor.updateShortcut(shortcut)
    }

    func updateWhisperBinaryPath(_ path: String) {
        preferences.whisperBinaryPath = path
    }

    func updateModelPath(_ path: String) {
        preferences.modelPath = path
    }

    func updateIdleTimeout(_ timeout: TimeInterval) {
        preferences.workerIdleTimeout = timeout
    }

    func refreshMicrophones() {
        let devices = AudioDeviceManager.availableInputDevices()
        availableMicrophones = devices

        if let selectedID = preferences.selectedMicrophoneID,
           devices.contains(where: { $0.stableID == selectedID }) == false {
            preferences.selectedMicrophoneID = nil
        }
    }

    func updateSelectedMicrophoneID(_ id: UInt32?) {
        preferences.selectedMicrophoneID = id
        refreshMicrophones()
    }

    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try LaunchAtLoginController.shared.enable()
            } else {
                try LaunchAtLoginController.shared.disable()
            }
            isLaunchAtLoginEnabled = enabled
        } catch {
            reportError("Could not update launch at login: \(error.localizedDescription)")
        }
    }

    func openAccessibilitySettings() {
        permissionsManager.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        permissionsManager.openInputMonitoringSettings()
    }

    func requestAccessibilityPermission() {
        permissionsManager.requestAccessibilityAccess()
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        permissionsManager.requestInputMonitoringAccess()
        refreshPermissions()
    }

    func requestMicrophonePermission() async {
        _ = await permissionsManager.requestMicrophoneAccess()
        refreshPermissions()
    }

    func downloadWhisperSetup() {
        let selection: WhisperModelSelection = .baseEn
        preferences.modelSelection = selection
        Task {
            do {
                let binaryPath = NSString(string: preferences.whisperBinaryPath).expandingTildeInPath
                if !FileManager.default.isExecutableFile(atPath: binaryPath) {
                    await MainActor.run {
                        whisperSetupState = .working("Installing whisper.cpp with Homebrew…")
                    }
                    let installedCLIPath = try await WhisperInstallService.installCLI()
                    await MainActor.run {
                        preferences.whisperBinaryPath = installedCLIPath
                    }
                }

                await MainActor.run {
                    whisperSetupState = .working("Downloading Base English…")
                }
                let path = try await WhisperInstallService.downloadModel(selection: selection)
                await MainActor.run {
                    preferences.modelPath = path
                    whisperSetupState = .success("Base English is ready")
                }
            } catch {
                await MainActor.run {
                    whisperSetupState = .failure(error.localizedDescription)
                    reportError(error.localizedDescription)
                }
            }
        }
    }

    func revealWhisperFiles() {
        let modelPath = NSString(string: preferences.modelPath).expandingTildeInPath
        let binaryPath = NSString(string: preferences.whisperBinaryPath).expandingTildeInPath
        let urls = [binaryPath, modelPath]
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func revealModelFile() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: NSString(string: preferences.modelPath).expandingTildeInPath)])
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func updateAccuracyVocabularyText(_ text: String) {
        vocabularyStore.customTermsText = text
        accuracyVocabularyText = text
    }

    func resetAccuracyVocabulary() {
        vocabularyStore.resetCustomTerms()
        accuracyVocabularyText = vocabularyStore.customTermsText
    }

    func importAccuracyVocabulary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.vocabularyStore.importTerms(from: url)
                self?.accuracyVocabularyText = self?.vocabularyStore.customTermsText ?? ""
            } catch {
                self?.reportError("Could not import vocabulary: \(error.localizedDescription)")
            }
        }
    }

    func exportAccuracyVocabulary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "listener-vocabulary.txt"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.vocabularyStore.exportTerms(to: url)
            } catch {
                self?.reportError("Could not export vocabulary: \(error.localizedDescription)")
            }
        }
    }

    func openSettingsWindow() {
        SettingsWindowController.shared.show(appState: self)
    }

    private func bind() {
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        vocabularyStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.accuracyVocabularyText = self?.vocabularyStore.customTermsText ?? ""
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        audioRecorder.$normalizedLevels
            .receive(on: RunLoop.main)
            .sink { [weak self] levels in
                guard let self else { return }
                waveformSamples = levels.map { CGFloat($0) }
                if sessionState == .recording {
                    overlayController.updateRecorder(samples: waveformSamples)
                }
            }
            .store(in: &cancellables)

        preferences.$shortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] shortcut in
                self?.shortcutMonitor.updateShortcut(shortcut)
            }
            .store(in: &cancellables)
    }

    private func refreshPermissions() {
        permissionState = permissionsManager.currentState()
        refreshInstallStatus()
    }

    private func refreshInstallStatus() {
        preferences.modelSelection = .baseEn
        let modelPath = NSString(string: preferences.modelPath).expandingTildeInPath
        let binaryPath = NSString(string: preferences.whisperBinaryPath).expandingTildeInPath
        let hasCLI = FileManager.default.isExecutableFile(atPath: binaryPath)
        let hasModel = FileManager.default.fileExists(atPath: modelPath)

        if case .working = whisperSetupState {
        } else {
            whisperSetupState = hasCLI && hasModel ? .success("Base English is ready") : .idle
        }
    }

    private func beginRecording() {
        guard sessionState != .recording,
              sessionState != .transcribing,
              sessionState != .inserting
        else {
            return
        }

        lastErrorMessage = nil
        overlayController.hideAlert()
        refreshPermissions()

        guard permissionState.microphone != .denied else {
            reportError("Microphone access is required before dictation can start.")
            return
        }

        do {
            let fileURL = try audioRecorder.startRecording(preferredDeviceID: preferences.selectedMicrophoneID)
            activeRecordingURL = fileURL
            recordingStartedAt = Date()
            sessionState = .recording
            overlayController.showRecorder(samples: waveformSamples)
        } catch {
            reportError("Could not start recording: \(error.localizedDescription)")
        }
    }

    private func finishRecording() async {
        guard sessionState == .recording else { return }

        let fileURL: URL
        do {
            fileURL = try audioRecorder.stop()
        } catch {
            sessionState = .idle
            overlayController.hideRecorder()
            reportError("Could not stop recording: \(error.localizedDescription)")
            return
        }

        activeRecordingURL = fileURL
        let recordingDuration = Date().timeIntervalSince(recordingStartedAt ?? Date())
        recordingStartedAt = nil
        sessionState = .transcribing
        overlayController.hideRecorder()

        if recordingDuration < 0.18 {
            sessionState = .idle
            return
        }

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let preprocessing = try AudioPreprocessor.preprocess(
                    audioURL: fileURL,
                    configuration: preferences.transcriptionConfiguration.preprocessing
                )
                if preprocessing.analysis.profile == .mostlySilent {
                    await MainActor.run {
                        sessionState = .idle
                    }
                    return
                }

                let configuration = makeTranscriptionConfiguration()
                try await transcriptionEngine.prepare(configuration: configuration)
                let result = try await transcriptionEngine.transcribe(audioURL: preprocessing.fileURL, configuration: configuration)
                let normalizedTranscript = normalizeTranscript(result.text)
                if normalizedTranscript.isEmpty {
                    await MainActor.run {
                        sessionState = .idle
                    }
                    return
                }
                await MainActor.run {
                    lastTranscript = normalizedTranscript
                }
                let corrected = TranscriptPostProcessor.process(normalizedTranscript, vocabulary: vocabularyStore.allTerms)
                try await insertTranscript(corrected)
                await MainActor.run {
                    sessionState = .idle
                    overlayController.hideRecorder()
                }
                Task.detached { [transcriptionEngine, idleTimeout = preferences.workerIdleTimeout] in
                    try? await transcriptionEngine.teardownIfIdle(after: idleTimeout)
                }
            } catch {
                if shouldIgnoreTranscriptionFailure(error) {
                    await MainActor.run {
                        sessionState = .idle
                        overlayController.hideRecorder()
                    }
                    return
                }
                await MainActor.run {
                    sessionState = .idle
                    overlayController.hideRecorder()
                    reportError("Dictation failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func insertTranscript(_ transcript: String) async throws {
        await MainActor.run { sessionState = .inserting }

        let result = try await MainActor.run {
            try insertionService.insert(text: transcript)
        }

        if case .failed(let message) = result {
            throw DictationError.insertionFailed(message)
        }
    }

    private func reportError(_ message: String) {
        lastErrorMessage = message
        sessionState = .error(message)
        overlayController.showAlert(message: message)
    }

    private func normalizeTranscript(_ transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "[BLANK_AUDIO]" {
            return ""
        }

        return trimmed
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeTranscriptionConfiguration() -> TranscriptionConfiguration {
        var configuration = preferences.transcriptionConfiguration
        configuration.promptTerms = Array(vocabularyStore.allTerms.prefix(120))
        return configuration
    }

    private func shouldIgnoreTranscriptionFailure(_ error: Error) -> Bool {
        guard let whisperError = error as? WhisperEngineError else {
            return false
        }

        switch whisperError {
        case .transcriptionOutputMissing(let message), .transcriptionFailed(let message):
            let lowered = message.lowercased()
            return lowered.contains("failed to read audio file")
                || lowered.contains("failed to read the frames of audio data")
                || lowered.contains("invalid argument")
                || lowered.contains("no transcript file was produced")
        default:
            return false
        }
    }
}

enum DictationError: LocalizedError {
    case insertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .insertionFailed(let message):
            return message
        }
    }
}
