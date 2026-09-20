import Foundation

/// Splitting for provider API-key rotation pools.
/// Stored values remain one string per provider; callers may paste keys
/// separated by newlines, commas, or whitespace.
enum APIKeyPool {
    static func keys(from raw: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        for part in raw.components(separatedBy: separators) {
            let key = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            ordered.append(key)
        }
        return ordered
    }
}

/// In-memory health tracking for API-key rotation.
/// ponytail: fixed cooldowns (60s for rate limits, 30s for server faults);
/// no Retry-After parsing and no cross-launch persistence until needed.
actor APIKeyRotator {
    static let shared = APIKeyRotator()
    private var cooledUntil: [String: Date] = [:]

    static func isRotatable(statusCode: Int) -> Bool {
        switch statusCode {
        case 408, 425, 429, 500, 502, 503, 504, 529:
            return true
        default:
            // Never rotate on auth/permission failures: a bad or blocked key
            // stays bad on every other key too, so rotating only spams.
            return false
        }
    }

    static func cooldownSeconds(for statusCode: Int) -> TimeInterval {
        statusCode == 429 || statusCode == 529 ? 60 : 30
    }

    /// Healthy keys first in stored order, then cooled keys soonest-expiring first.
    /// If every key is cooled, still return the pool instead of failing rotation.
    func orderedKeys(_ pool: [String], provider: String) -> [String] {
        let now = Date()
        let healthy = pool.filter { (self.cooledUntil[self.slot(provider: provider, key: $0)] ?? .distantPast) <= now }
        guard healthy.count != pool.count else { return pool }
        let cooled = pool.filter { !healthy.contains($0) }.sorted {
            (self.cooledUntil[self.slot(provider: provider, key: $0)] ?? now)
                < (self.cooledUntil[self.slot(provider: provider, key: $1)] ?? now)
        }
        return healthy + cooled
    }

    func markDown(provider: String, key: String, statusCode: Int) {
        self.cooledUntil[self.slot(provider: provider, key: key)] =
            Date().addingTimeInterval(Self.cooldownSeconds(for: statusCode))
    }

    private func slot(provider: String, key: String) -> String {
        "\(provider)\n\(key)"
    }
}
