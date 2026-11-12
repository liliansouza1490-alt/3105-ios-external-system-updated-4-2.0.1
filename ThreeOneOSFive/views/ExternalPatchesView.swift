import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ExternalPatchesView: View {
    @EnvironmentObject private var patchStore: ExternalPatchStore
    @EnvironmentObject private var libraryStore: PatchProjectStore
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @State private var showAddPatch = false
    @State private var showImporter = false
    @State private var pendingFileURL: URL?
    @State private var pendingFileName = ""
    @State private var newPatchCategory: ExternalCategory = .aimbot
    @State private var importError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXTERNAL SYSTEM")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("soportado")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    Button {
                        pendingFileURL = nil
                        pendingFileName = ""
                        newPatchCategory = patchStore.selectedCategory
                        importError = nil
                        patchStore.lastError = nil
                        showAddPatch = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.white, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Categories
                HStack(spacing: 0) {
                    ForEach(ExternalCategory.allCases) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                patchStore.selectedCategory = cat
                            }
                        } label: {
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(
                                    patchStore.selectedCategory == cat ? .black : Color.white.opacity(0.55)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    Group {
                                        if patchStore.selectedCategory == cat {
                                            Capsule().fill(Color.white)
                                        } else {
                                            Capsule().fill(Color.clear)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(Color(white: 0.14)))
                .padding(.horizontal, 18)
                .padding(.bottom, 20)

                // List
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if patchStore.visibleItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(Color.white.opacity(0.22))
                                Text("Nenhum patch")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                Text("Toque no + e escolha um arquivo .3105")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 70)
                        } else {
                            ForEach(patchStore.visibleItems) { item in
                                toggleRow(item)
                            }
                        }

                        if appState.kernelExploitRunning {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Executando exploit… aguarde")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            .padding(.top, 8)
                        } else if let msg = patchStore.statusMessage {
                            Text(msg)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.green.opacity(0.8))
                                .padding(.top, 8)
                        }
                        // Only show error when user has patches / after an action
                        if let err = patchStore.lastError, !patchStore.visibleItems.isEmpty {
                            Text(err)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 100)
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                Button {
                    openFreeFire()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Abrir Free Fire")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.25), radius: 14)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            patchStore.lastError = nil
            libraryStore.reload()
            appState.detectSupport()
        }
        .sheet(isPresented: $showSettings) {
            ExternalSettingsView()
        }
        .sheet(isPresented: $showAddPatch) {
            addPatchSheet
        }
    }

    private var addPatchSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arquivo .3105")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))

                        Button {
                            // Present importer from the sheet itself
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: pendingFileURL == nil ? "doc.badge.plus" : "doc.fill")
                                    .foregroundStyle(.white)
                                Text(pendingFileName.isEmpty ? "Selecionar arquivo .3105" : pendingFileName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(white: 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if let importError {
                            Text(importError)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enviar para")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))

                        VStack(spacing: 0) {
                            ForEach(ExternalCategory.allCases) { cat in
                                Button {
                                    newPatchCategory = cat
                                } label: {
                                    HStack {
                                        Text(cat.rawValue)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: newPatchCategory == cat ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(newPatchCategory == cat ? .white : Color.white.opacity(0.3))
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if cat != ExternalCategory.allCases.last {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 0.5)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(white: 0.12))
                        )
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Adicionar Patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { showAddPatch = false }
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Adicionar") { addPatch() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .disabled(pendingFileURL == nil)
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showImporter) {
                DocumentPicker(
                    onPick: { url in
                        // asCopy: true → local copy already in tmp
                        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                            ?? FileManager.default.temporaryDirectory
                        let dest = destDir.appendingPathComponent(url.lastPathComponent)
                        do {
                            if FileManager.default.fileExists(atPath: dest.path) {
                                try FileManager.default.removeItem(at: dest)
                            }
                            try FileManager.default.copyItem(at: url, to: dest)
                            pendingFileURL = dest
                        } catch {
                            // fallback to picker-provided URL
                            pendingFileURL = url
                        }
                        pendingFileName = url.lastPathComponent
                        importError = nil
                        showImporter = false
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addPatch() {
        guard let url = pendingFileURL else { return }

        var title = pendingFileName
            .replacingOccurrences(of: ".3105", with: "", options: .caseInsensitive)
        var packageID: UUID?
        var storedURL: URL? = url

        if let data = try? Data(contentsOf: url) {
            if let summary = try? PatchPackageCodec.inspect(data) {
                packageID = summary.packageID
            }
            if let decoded = try? PatchPackageCodec.decode(data, password: nil) {
                let name = decoded.project.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { title = name }
                packageID = decoded.project.id
            }
        }

        libraryStore.importPackage(at: url)

        let id = packageID?.uuidString ?? UUID().uuidString
        patchStore.registerPatch(
            id: id,
            title: title.isEmpty ? "Patch" : title,
            category: newPatchCategory,
            packageID: packageID,
            packageURL: storedURL
        )
        patchStore.selectedCategory = newPatchCategory
        showAddPatch = false

        if let packageID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                libraryStore.reload()
                if let libURL = libraryStore.items.first(where: { $0.id == packageID })?.packageURL,
                   let idx = patchStore.items.firstIndex(where: { $0.id == id }) {
                    patchStore.items[idx].packageURL = libURL
                    patchStore.items[idx].packageID = packageID
                }
            }
        }
    }

    @ViewBuilder
    private func toggleRow(_ item: ExternalToggleItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if item.packageURL != nil || item.packageID != nil {
                    Text(".3105")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isOn },
                set: { patchStore.setToggle(id: item.id, isOn: $0, patchStore: libraryStore, appState: appState) }
            ))
            .labelsHidden()
            .tint(Color.white)
            .disabled(patchStore.isBusy)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                patchStore.removePatch(id: item.id)
            } label: {
                Label("Remover", systemImage: "trash")
            }
        }
    }

    private func openFreeFire() {
        let schemes = ["freefire://", "ff://", "https://apps.apple.com/app/id1300146617"]
        for s in schemes {
            if let url = URL(string: s), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
    }
}
