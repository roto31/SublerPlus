import Foundation

public protocol APIKeyStore {
    func set(key: String, value: String)
    func get(key: String) -> String?
    func remove(key: String)
}

public final class APIKeyManager {
    private let store: APIKeyStore

    public init(store: APIKeyStore) {
        self.store = store
    }

    public func saveTPDBKey(_ key: String) {
        store.set(key: "tpdb", value: key)
    }

    public func loadTPDBKey() -> String? {
        store.get(key: "tpdb")
    }

    public func clearTPDBKey() {
        store.remove(key: "tpdb")
    }

    public func saveWebToken(_ token: String) {
        store.set(key: "webui_token", value: token)
    }

    public func loadWebToken() -> String? {
        store.get(key: "webui_token")
    }

    public func clearWebToken() {
        store.remove(key: "webui_token")
    }
}

