import SwiftUI
import UIKit

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @StateObject private var externalStore = ExternalPatchStore()
    @StateObject private var keySession = IOSKeySession()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        setupLogCapture()
        log("app: EXTERNAL SYSTEM launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environmentObject(fileOperationCoordinator)
                .environmentObject(patchStore)
                .environmentObject(repositoryStore)
                .environmentObject(externalStore)
                .environmentObject(keySession)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.detectSupport()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        appState.detectSupport()
                        keySession.validateIntegrityOnForeground()
                        Task { await keySession.refresh() }
                    }
                }
                .onOpenURL { url in
                    patchDraftCoordinator.presentImport(url)
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false
    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif
        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }
        guard KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        ) else { return }
        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
            }
        } else if KernelExploit.hasSandboxAccess() || /* kernel-only path */ false {
            // hasSandboxAccess is the strong check; on <26 run() may succeed with kernel only
        }
    }

    /// Public — can be called from UI when user retries apply
    func runKernelExploitIfNeeded(force: Bool = false) {
        refreshKernelExploitStatus()
        if force, exploitStatus.isFailed {
            exploitStatus = .notStarted
        }
        guard !kernelExploitRunning, !exploitStatus.isSuccess else { return }
        if exploitStatus.isFailed && !force { return }

        kernelExploitRunning = true
        if case .failed = exploitStatus {
            exploitStatus = .notStarted
        }
        DispatchQueue.global(qos: .userInitiated).async {
            log("appstate: starting KernelExploit.run()…")
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                self.exploitStatus = ok
                    ? .success(method: "kexploit")
                    : .failed(method: "kexploit", code: -1)
                log("appstate: exploit finished ok=\(ok)")
            }
        }
    }
}
