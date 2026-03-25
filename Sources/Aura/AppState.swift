import AppKit
import Combine
import Foundation

extension AppAppearanceOption {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

extension OrbAppearanceOption {
    var nsAppearance: NSAppearance? {
        switch self {
        case .inherit:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var sessionState: RecordingSessionState = .idle
    @Published var permissionState: PermissionState = .unknown
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published var lastErrorMessage: String?
    @Published var lastTranscript: String = ""
    @Published var isSettingsPresented = false
    @Published var isLaunchAtLoginEnabled = false
    @Published var isSetupFlowPresented = false
    @Published var whisperSetupState: InstallProgressState = .idle
    @Published var availableMicrophones: [MicrophoneDevice] = []

    let preferences: AppPreferencesStore
    let permissionsManager: PermissionsManager
    let shortcutMonitor: ShortcutMonitor
    let overlayController: OverlayPanelController
    let audioRecorder: AudioRecorder
    let transcriptionEngine: TranscriptionEngine
    let insertionService: TextInsertionService

    private var cancellables = Set<AnyCancellable>()
    private var activeRecordingURL: URL?
    private var recordingStartedAt: Date?
    private var transcriptionTask: Task<Void, Never>?
    private var activeRecordingSessionID = UUID()

    init(
        preferences: AppPreferencesStore = .shared,
        permissionsManager: PermissionsManager = PermissionsManager(),
        shortcutMonitor: ShortcutMonitor = ShortcutMonitor(),
        overlayController: OverlayPanelController = OverlayPanelController(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        transcriptionEngine: TranscriptionEngine = WhisperCPPTranscriptionEngine(),
        insertionService: TextInsertionService = PasteTextInsertionService()
    ) {
        self.preferences = preferences
        self.permissionsManager = permissionsManager
        self.shortcutMonitor = shortcutMonitor
        self.overlayController = overlayController
        self.audioRecorder = audioRecorder
        self.transcriptionEngine = transcriptionEngine
        self.insertionService = insertionService

        bind()
    }

    func start() {
        refreshPermissions()
        refreshMicrophones()
        Task { [weak self] in
            await self?.synchronizeWhisperModelLocation()
        }
        isLaunchAtLoginEnabled = LaunchAtLoginController.shared.isEnabled
        overlayController.updateAuraColor(preferences.auraColor)
        applyAppearance(preferences.appearance)
        applyOverlayAppearance()
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

    func refreshMicrophones() {
        let devices = AudioDeviceManager.availableInputDevices()
        availableMicrophones = devices

        if let selectedID = preferences.selectedMicrophoneID {
            if devices.contains(where: { $0.stableID == selectedID }) == false {
                preferences.selectedMicrophoneID = nil
            }
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
        Task {
            do {
                await MainActor.run {
                    whisperSetupState = .working(message: "Preparing Medium English...", progress: nil)
                }
                let path = try await WhisperInstallService.prepareBaseModel(
                    onStageChange: { stage in
                        Task { @MainActor in
                            self.whisperSetupState = .working(message: stage, progress: nil)
                        }
                    },
                    onProgress: { progress in
                    let percentage = Int((progress * 100).rounded())
                    Task { @MainActor in
                        self.whisperSetupState = .working(
                            message: "Downloading Medium English... \(percentage)%",
                            progress: progress
                        )
                    }
                    }
                )
                await MainActor.run {
                    preferences.modelPath = path
                    whisperSetupState = .success("Medium English is ready")
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
        let urls = [URL(fileURLWithPath: modelPath)]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openTranscriptionsFolder() {
        NSWorkspace.shared.open(FileManager.default.temporaryDirectory)
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func openSettingsWindow() {
        refreshPermissions()
        refreshMicrophones()
        isSetupFlowPresented = !isSetupComplete
        SettingsWindowController.shared.show(appState: self)
    }

    func reopenSetupFlow() {
        refreshPermissions()
        refreshMicrophones()
        isSetupFlowPresented = true
    }

    func clearVoiceTextHistory() {
        preferences.clearVoiceTextHistory()
    }

    func removeVoiceTextHistoryItem(id: UUID) {
        preferences.removeVoiceTextHistoryItem(id: id)
    }

    private func bind() {
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
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

        preferences.$auraColor
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] auraColor in
                self?.overlayController.updateAuraColor(auraColor)
            }
            .store(in: &cancellables)

        preferences.$appearance
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] appearance in
                self?.applyAppearance(appearance)
            }
            .store(in: &cancellables)

        preferences.$orbAppearance
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyOverlayAppearance()
            }
            .store(in: &cancellables)
    }

    private func applyAppearance(_ appearance: AppAppearanceOption) {
        let nsAppearance = appearance.nsAppearance
        NSApp.appearance = nsAppearance
        SettingsWindowController.shared.updateAppearance(nsAppearance)
        applyOverlayAppearance()
    }

    private func applyOverlayAppearance() {
        let nsAppearance: NSAppearance?
        switch preferences.orbAppearance {
        case .inherit:
            nsAppearance = preferences.appearance.nsAppearance
        case .light, .dark:
            nsAppearance = preferences.orbAppearance.nsAppearance
        }

        overlayController.updateAppearance(nsAppearance)
    }

    private func refreshPermissions() {
        permissionState = permissionsManager.currentState()
        refreshInstallStatus()
    }

    private func synchronizeWhisperModelLocation() async {
        do {
            let synchronizedPath = try await Task.detached(priority: .utility) {
                try WhisperInstallService.synchronizeModelLocationIfNeeded()
            }.value

            if let synchronizedPath {
                preferences.modelPath = synchronizedPath
            }

            refreshInstallStatus()
        } catch {
            refreshInstallStatus()
        }
    }

    private func refreshInstallStatus() {
        let modelPath = NSString(string: preferences.modelPath).expandingTildeInPath
        let hasModel = FileManager.default.fileExists(atPath: modelPath)

        if case .working = whisperSetupState {
        } else {
            whisperSetupState = hasModel ? .success("Medium English is ready") : .idle
        }

        if isSetupComplete == false {
            isSetupFlowPresented = true
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
            activeRecordingSessionID = UUID()
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

        let sessionID = activeRecordingSessionID
        let startedAt = recordingStartedAt ?? Date()
        recordingStartedAt = nil
        sessionState = .transcribing
        overlayController.showLoading()

        let fileURL: URL
        do {
            fileURL = try await Task.detached(priority: .userInitiated) { [audioRecorder] in
                try audioRecorder.stop()
            }.value
        } catch {
            sessionState = .idle
            overlayController.hideRecorder()
            reportError("Could not stop recording: \(error.localizedDescription)")
            return
        }

        guard sessionID == activeRecordingSessionID else {
            overlayController.hideRecorder()
            return
        }

        activeRecordingURL = fileURL
        let recordingDuration = Date().timeIntervalSince(startedAt)

        if recordingDuration < 0.18 {
            sessionState = .idle
            overlayController.showShortHoldWarning()
            return
        }

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let preprocessing = try AudioPreprocessor.preprocess(
                    audioURL: fileURL,
                    configuration: AudioPreprocessingConfiguration()
                )

                let configuration = makeTranscriptionConfiguration()
                try await transcriptionEngine.prepare(configuration: configuration)
                let result = try await transcriptionEngine.transcribe(audioURL: preprocessing.fileURL, configuration: configuration)
                let normalizedTranscript = normalizeTranscript(result.text)
                if normalizedTranscript.isEmpty {
                    await MainActor.run {
                        sessionState = .idle
                        overlayController.hideRecorder()
                    }
                    return
                }
                await MainActor.run {
                    lastTranscript = normalizedTranscript
                    preferences.addVoiceTextHistoryItem(VoiceTextHistoryItem(text: normalizedTranscript))
                }
                try await insertTranscript(normalizedTranscript)
                await MainActor.run {
                    sessionState = .idle
                    if preprocessing.analysis.clippedStartLikely {
                        overlayController.showClippedStartWarning()
                    } else {
                        overlayController.hideRecorder()
                    }
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
        preferences.transcriptionConfiguration
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

    var isSetupComplete: Bool {
        let modelPath = NSString(string: preferences.modelPath).expandingTildeInPath

        return permissionState.microphone == .granted
            && permissionState.accessibility == .granted
            && FileManager.default.fileExists(atPath: modelPath)
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
