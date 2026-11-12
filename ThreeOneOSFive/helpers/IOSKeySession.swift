import Foundation
import Security
import UIKit

private struct IOSKeyResponseEnvelope: Decodable { let result: IOSKeyResponseResult }
private struct IOSKeyResponseResult: Decodable { let data: IOSKeyResponseData }
private struct IOSKeyResponseData: Decodable { let json: IOSKeyValidation }
private struct IOSKeyValidation: Decodable {
    let success: Bool?; let valid: Bool?; let active: Bool?; let status: String?
    let errorCode: String?; let message: String?; let reason: String?; let expiresAt: String?
}

@MainActor
final class IOSKeySession: ObservableObject {
    private(set) static var runtimeAuthorized = false
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isChecking = false
    @Published private(set) var expiresAt: Date?
    @Published var errorMessage: String?

    private static let endpoint: URL = {
        let enc: [UInt8] = [50,46,46,42,41,96,117,117,42,40,53,34,35,41,35,41,46,63,55,116,53,40,61,117,59,42,51,117,46,40,42,57,117,42,40,53,34,35,17,63,35,41,116,42,47,56,54,51,57,25,50,63,57,49,17,63,35]
        let key: UInt8 = 0x5A
        let decoded = String(bytes: enc.map { $0 ^ key }, encoding: .utf8) ?? "https://proxysystem.org/api/trpc/proxyKeys.publicCheckKey"
        return URL(string: decoded)!
    }()

    private static let keychainService = "com.3105.ios-key"
    private static let keychainAccount = "proxy-system-key"
    private static let deviceBindingKeychainService = "com.3105.device-binding"
    private static let deviceBindingKeychainAccount = "installation-id"

    private var storedKey: String?
    private var didPassCalculatorGate = false

    init() {
        storedKey = Self.readKeychain()
    }

    func passCalculatorGate() {
        guard !didPassCalculatorGate else { return }
        didPassCalculatorGate = true
        if storedKey != nil { Task { await refresh() } }
    }

    func submit(_ rawKey: String) {
        guard didPassCalculatorGate else { return }
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = "Digite sua chave."
            return
        }
        Task { await validate(key, saveOnSuccess: true) }
    }

    func refresh() async {
        guard didPassCalculatorGate, !isChecking, let storedKey, !storedKey.isEmpty else { return }
        await validate(storedKey, saveOnSuccess: false)
    }

    func logout() {
        storedKey = nil
        Self.deleteKeychain()
        Self.runtimeAuthorized = false
        isAuthenticated = false
        expiresAt = nil
    }

    func validateIntegrityOnForeground() {
        // hook for future anti-tamper
    }

    private func validate(_ key: String, saveOnSuccess: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        do {
            var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false)!
            let input: [String: Any] = ["json": ["key": key, "deviceId": try Self.deviceIdentifier()]]
            let data = try JSONSerialization.data(withJSONObject: input)
            components.queryItems = [URLQueryItem(name: "input", value: String(data: data, encoding: .utf8))]
            guard let url = components.url else { throw URLError(.badURL) }
            let (responseData, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let envelope = try JSONDecoder().decode(IOSKeyResponseEnvelope.self, from: responseData)
            let result = envelope.result.data.json
            let accepted = result.success == true && result.active == true && result.status?.lowercased() == "active"
            guard accepted else {
                logout()
                if result.status?.lowercased() == "device_mismatch" || result.errorCode?.uppercased() == "DEVICE_MISMATCH" {
                    errorMessage = result.message ?? "Esta chave já está vinculada a outro aparelho."
                } else {
                    errorMessage = result.message ?? result.reason ?? "Chave inválida ou expirada."
                }
                return
            }
            storedKey = key
            if saveOnSuccess { Self.writeKeychain(key) }
            expiresAt = result.expiresAt.flatMap(Self.parseDate)
            errorMessage = nil
            Self.runtimeAuthorized = true
            isAuthenticated = true
        } catch {
            if !isAuthenticated {
                errorMessage = "Não foi possível verificar a chave. Verifique sua conexão."
            }
        }
    }

    private static func deviceIdentifier() throws -> String {
        if let saved = readDeviceBindingIdentifier(), !saved.isEmpty { return saved }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        guard writeDeviceBindingIdentifier(generated) else {
            throw NSError(domain: "Keychain", code: 1)
        }
        return generated
    }

    private static func readDeviceBindingIdentifier() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceBindingKeychainService,
            kSecAttrAccount as String: deviceBindingKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeDeviceBindingIdentifier(_ value: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: deviceBindingKeychainService,
            kSecAttrAccount as String: deviceBindingKeychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func parseDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}
