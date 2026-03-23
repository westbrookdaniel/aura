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

    let preferences: AppPreferencesStore
    let permissionsManager: PermissionsManager
    let shortcutMonitor: ShortcutMonitor
    let overlayController: OverlayPanelController
    let audioRecorder: AudioRecorder
    let transcriptionEngine: TranscriptionEngine
    let insertionService: TextInsertionService

    private var cancellables = Set<AnyCancellable>()
    private var activeRecordingURL: URL?
    private var transcriptionTask: Task<Void, Never>?

    init(
        preferences: AppPreferencesStore = .shared,
        permissionsManager: PermissionsManager = PermissionsManager(),
        shortcutMonitor: ShortcutMonitor = ShortcutMonitor(),
        overlayController: OverlayPanelController = OverlayPanelController(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        transcriptionEngine: TranscriptionEngine = WhisperCLITranscriptionEngine(),
        insertionService: TextInsertionService = AccessibilityTextInsertionService()
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
        overlayController.hide()
        transcriptionTask?.cancel()
    }

    func updateShortcut(_ shortcut: ShortcutSpec) {
        preferences.shortcut = shortcut
        shortcutMonitor.updateShortcut(shortcut)
    }

    func updateModelSelection(_ selection: WhisperModelSelection) {
        preferences.modelSelection = selection
    }

    func updateWhisperBinaryPath(_ path: String) {
        preferences.whisperBinaryPath = path
    }

    func updateModelPath(_ path: String) {
        preferences.modelPath = path
    }

    func updateFallbackPolicy(_ policy: TextInsertionFallbackPolicy) {
        preferences.fallbackPolicy = policy
    }

    func updateIdleTimeout(_ timeout: TimeInterval) {
        preferences.workerIdleTimeout = timeout
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

    func requestMicrophonePermission() async {
        _ = await permissionsManager.requestMicrophoneAccess()
        refreshPermissions()
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func bind() {
        audioRecorder.$normalizedLevels
            .receive(on: RunLoop.main)
            .sink { [weak self] levels in
                guard let self else { return }
                waveformSamples = levels.map { CGFloat($0) }
                if sessionState == .recording {
                    overlayController.update(samples: waveformSamples, state: sessionState)
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
    }

    private func beginRecording() {
        guard sessionState == .idle else { return }
        refreshPermissions()

        guard permissionState.microphone != .denied else {
            reportError("Microphone access is required before dictation can start.")
            return
        }

        guard permissionState.inputMonitoring != .denied else {
            reportError("Input Monitoring permission is required for the shortcut.")
            return
        }

        do {
            let fileURL = try audioRecorder.startRecording()
            activeRecordingURL = fileURL
            sessionState = .recording
            overlayController.show(samples: waveformSamples, state: .recording)
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
            overlayController.hide()
            reportError("Could not stop recording: \(error.localizedDescription)")
            return
        }

        activeRecordingURL = fileURL
        sessionState = .transcribing
        overlayController.update(samples: waveformSamples, state: .transcribing)

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriptionEngine.prepare(configuration: preferences.transcriptionConfiguration)
                let transcript = try await transcriptionEngine.transcribe(audioURL: fileURL, configuration: preferences.transcriptionConfiguration)
                await MainActor.run {
                    lastTranscript = transcript
                }
                try await insertTranscript(transcript)
                try? await transcriptionEngine.teardownIfIdle(after: preferences.workerIdleTimeout)
                await MainActor.run {
                    sessionState = .idle
                    overlayController.hide()
                }
            } catch {
                await MainActor.run {
                    sessionState = .idle
                    overlayController.hide()
                    reportError("Dictation failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func insertTranscript(_ transcript: String) async throws {
        await MainActor.run {
            sessionState = .inserting
            overlayController.update(samples: waveformSamples, state: .inserting)
        }

        let result = try insertionService.insert(
            text: transcript,
            fallbackPolicy: preferences.fallbackPolicy
        )

        if case .failed(let message) = result {
            throw DictationError.insertionFailed(message)
        }
    }

    private func reportError(_ message: String) {
        lastErrorMessage = message
        sessionState = .error(message)
        overlayController.show(samples: waveformSamples, state: .error(message))
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
