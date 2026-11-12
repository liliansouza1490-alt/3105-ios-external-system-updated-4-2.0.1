import SwiftUI
import Combine

struct ExternalToggleItem: Identifiable, Equatable {
    let id: String
    var title: String
    var isOn: Bool
    var category: ExternalCategory
    var packageID: UUID?
    var packageURL: URL?
}

enum ExternalCategory: String, CaseIterable, Identifiable {
    case aimbot = "Aimbots"
    case hologramas = "Hologramas"
    case borrar = "Borrar Invitado"

    var id: String { rawValue }
}

final class ExternalPatchStore: ObservableObject {
    @Published var items: [ExternalToggleItem] = []
    @Published var selectedCategory: ExternalCategory = .aimbot
    @Published var lastError: String?
    @Published var isBusy = false
    @Published var statusMessage: String?

    var visibleItems: [ExternalToggleItem] {
        items.filter { $0.category == selectedCategory }
    }

    func registerPatch(
        id: String,
        title: String,
        category: ExternalCategory,
        packageID: UUID? = nil,
        packageURL: URL? = nil,
        defaultOn: Bool = false
    ) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].title = title
            items[idx].category = category
            items[idx].packageID = packageID
            items[idx].packageURL = packageURL
        } else {
            items.append(
                ExternalToggleItem(
                    id: id,
                    title: title,
                    isOn: defaultOn,
                    category: category,
                    packageID: packageID,
                    packageURL: packageURL
                )
            )
        }
    }

    func removePatch(id: String) {
        items.removeAll { $0.id == id }
    }

    /// Wait until AppState has working exploit access, then continue.
    func ensureAccess(appState: AppState, completion: @escaping (Bool) -> Void) {
#if targetEnvironment(simulator)
        completion(true)
        return
#else
        // Already have sandbox?
        if KernelExploit.hasSandboxAccess() {
            completion(true)
            return
        }
        // Already marked success and iOS < 26 (kernel path)
        if appState.exploitStatus.isSuccess, !KernelExploit.requiresSandboxEscape {
            completion(true)
            return
        }
        if appState.exploitStatus.isSuccess, KernelExploit.hasSandboxAccess() {
            completion(true)
            return
        }

        // Kick exploit (retry if previous fail)
        let force = appState.exploitStatus.isFailed
        appState.runKernelExploitIfNeeded(force: force)

        // Poll until finished (max ~45s)
        var tries = 0
        func tick() {
            tries += 1
            if KernelExploit.hasSandboxAccess()
                || (appState.exploitStatus.isSuccess && !KernelExploit.requiresSandboxEscape) {
                completion(true)
                return
            }
            if appState.exploitStatus.isFailed && !appState.kernelExploitRunning {
                self.lastError = "Falha ao obter acesso (exploit). Status: \(appState.exploitStatus.displayText)"
                completion(false)
                return
            }
            if tries > 90 {
                self.lastError = "Timeout esperando exploit."
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { tick() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tick() }
#endif
    }

    @MainActor
    func setToggle(id: String, isOn: Bool, patchStore: PatchProjectStore?, appState: AppState?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isOn = isOn
        lastError = nil
        statusMessage = nil

        var packageURL = items[idx].packageURL
        if packageURL == nil, let pid = items[idx].packageID {
            packageURL = patchStore?.items.first(where: { $0.id == pid })?.packageURL
            if let packageURL {
                items[idx].packageURL = packageURL
            }
        }

        guard let url = packageURL else {
            lastError = "Arquivo .3105 não vinculado a este toggle."
            items[idx].isOn = !isOn
            return
        }

        guard let appState else {
            lastError = "AppState indisponível."
            items[idx].isOn = !isOn
            return
        }

        isBusy = true
        statusMessage = isOn ? "Preparando acesso…" : "Restaurando…"
        let contentKeysByPackageID = (patchStore?.items ?? []).reduce(into: [UUID: Data]()) { result, item in
            if let contentKey = item.contentKey {
                result[item.id] = contentKey
            }
        }

        ensureAccess(appState: appState) { [weak self] ready in
            guard let self else { return }
            guard ready else {
                self.isBusy = false
                self.items[idx].isOn = !isOn
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try PatchProjectLibrary.readPackage(at: url)
                    let decoded: DecodedPatchPackage
                    if let summary = try? PatchPackageCodec.inspect(data),
                       summary.isPasswordProtected,
                       let contentKey = contentKeysByPackageID[summary.packageID] {
                        decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                    } else {
                        decoded = try PatchPackageCodec.decode(data, password: nil)
                    }
                    let project = decoded.project

                    if isOn {
                        _ = try DevicePatchService.apply(project: project)
                        DispatchQueue.main.async {
                            self.statusMessage = "Aplicado: \(project.name)"
                            self.isBusy = false
                        }
                    } else {
                        if let receipt = DevicePatchService.latestReceipt(projectID: project.id) {
                            try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                            DispatchQueue.main.async {
                                self.statusMessage = "Restaurado: \(project.name)"
                                self.isBusy = false
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.statusMessage = "Nada para restaurar"
                                self.isBusy = false
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isBusy = false
                        if let i = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[i].isOn = !isOn
                        }
                        self.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    func clearAll() {
        items.removeAll()
    }
}
