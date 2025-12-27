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

    public func saveTMDBKey(_ key: String) {
        store.set(key: "tmdb", value: key)
    }

    public func loadTMDBKey() -> String? {
        store.get(key: "tmdb")
    }

    public func clearTMDBKey() {
        store.remove(key: "tmdb")
    }

    public func saveTVDBKey(_ key: String) {
        store.set(key: "tvdb", value: key)
    }

    public func loadTVDBKey() -> String? {
        store.get(key: "tvdb")
    }

    public func clearTVDBKey() {
        store.remove(key: "tvdb")
    }

    public func saveOpenSubtitlesKey(_ key: String) {
        store.set(key: "opensubtitles", value: key)
    }

    public func loadOpenSubtitlesKey() -> String? {
        store.get(key: "opensubtitles")
    }

    public func clearOpenSubtitlesKey() {
        store.remove(key: "opensubtitles")
    }

    public func saveMusixmatchKey(_ key: String) {
        store.set(key: "musixmatch", value: key)
    }

    public func loadMusixmatchKey() -> String? {
        store.get(key: "musixmatch")
    }

    public func clearMusixmatchKey() {
        store.remove(key: "musixmatch")
    }
}

