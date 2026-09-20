import Foundation

// Compile: swiftc -O Sources/Fluid/Services/APIKeyRotator.swift Tests/APIKeyRotationTests.swift -o rotcheck
@main
enum APIKeyRotationTests {
    static func main() async {
        var failures = 0
        func check(_ cond: Bool, _ name: String) {
            if cond { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") }
        }

        check(APIKeyPool.keys(from: "a\nb\nc") == ["a", "b", "c"], "multiline split")
        check(APIKeyPool.keys(from: "a,b,c") == ["a", "b", "c"], "comma split")
        check(APIKeyPool.keys(from: "a b  c") == ["a", "b", "c"], "whitespace split")
        check(APIKeyPool.keys(from: "\n a \n\nb\na\n") == ["a", "b"], "trim + drop empties + dedupe")
        check(APIKeyPool.keys(from: "solo") == ["solo"], "single key unchanged")
        check(APIKeyPool.keys(from: "   \n,") == [], "blank yields empty pool")
        check(APIKeyPool.keys(from: "key-abc-\nkey2") == ["key-abc-", "key2"], "dashes preserved")

        check(APIKeyRotator.isRotatable(statusCode: 429), "429 rotates")
        check(APIKeyRotator.isRotatable(statusCode: 529), "529 rotates")
        check(APIKeyRotator.isRotatable(statusCode: 503), "503 rotates")
        check(!APIKeyRotator.isRotatable(statusCode: 401), "401 never rotates")
        check(!APIKeyRotator.isRotatable(statusCode: 403), "403 never rotates")
        check(!APIKeyRotator.isRotatable(statusCode: 200), "200 never rotates")
        check(APIKeyRotator.cooldownSeconds(for: 429) == 60, "429 cooldown 60s")
        check(APIKeyRotator.cooldownSeconds(for: 503) == 30, "503 cooldown 30s")

        let rotator = APIKeyRotator()
        let fresh = await rotator.orderedKeys(["a", "b", "c"], provider: "groq")
        check(fresh == ["a", "b", "c"], "healthy pool keeps stored order")
        await rotator.markDown(provider: "groq", key: "a", statusCode: 429)
        let cooled = await rotator.orderedKeys(["a", "b", "c"], provider: "groq")
        check(cooled == ["b", "c", "a"], "cooled key drops to back")
        await rotator.markDown(provider: "groq", key: "b", statusCode: 429)
        await rotator.markDown(provider: "groq", key: "c", statusCode: 429)
        let allCooled = await rotator.orderedKeys(["a", "b", "c"], provider: "groq")
        check(allCooled.count == 3, "all-cooled still serves pool, never hard-fails")
        let other = await rotator.orderedKeys(["a", "b"], provider: "openai")
        check(other == ["a", "b"], "cooldowns scoped per provider")

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILURES")
        exit(failures == 0 ? 0 : 1)
    }
}
