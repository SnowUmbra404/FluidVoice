import Foundation

// Compile: swiftc -O Sources/Fluid/Services/TranscriptPlaceholder.swift Tests/TranscriptPlaceholderTests.swift -o phcheck
@main
enum TranscriptPlaceholderTests {
    static func main() {
        var failures = 0
        func check(_ cond: Bool, _ name: String) {
            if cond { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") }
        }

        let t = "hello"
        check(
            TranscriptPlaceholder.render(template: "A <transcript>${transcript}</transcript> B", transcript: t)
                == "A <transcript>hello</transcript> B",
            "wrapper-only substitution"
        )
        check(
            TranscriptPlaceholder.render(
                template: "embedded via the ${transcript} variable. <transcript>${transcript}</transcript>",
                transcript: t)
                == "embedded via the transcript variable. <transcript>hello</transcript>",
            "stray mention becomes literal word"
        )
        check(
            TranscriptPlaceholder.render(template: "prefix ${transcript} suffix", transcript: t)
                == "prefix hello suffix",
            "bare placeholder legacy path"
        )
        check(
            TranscriptPlaceholder.render(template: "PROMPT", transcript: t) == "PROMPT\n\nhello",
            "no placeholder appends transcript"
        )
        check(
            TranscriptPlaceholder.render(template: "  \n ", transcript: t) == t,
            "empty template returns transcript"
        )
        check(
            TranscriptPlaceholder.render(template: "<transcript>${transcript}</transcript>", transcript: "")
                == "<transcript></transcript>",
            "empty transcript keeps wrapper"
        )

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILURES")
        exit(failures == 0 ? 0 : 1)
    }
}
