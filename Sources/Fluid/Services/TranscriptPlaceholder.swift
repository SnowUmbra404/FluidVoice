import Foundation

/// Transcript placeholder substitution for dictation prompts.
/// ponytail: only the <transcript> wrapper gets the transcript; stray
/// mentions of the placeholder become the literal word "transcript" so a
/// template can never render a corrupted sentence into the model input.
enum TranscriptPlaceholder {
    static let token = "${transcript}"

    static func render(template: String, transcript: String) -> String {
        let wrapper = "<transcript>\(token)</transcript>"
        if template.contains(wrapper) {
            return template
                .replacingOccurrences(of: wrapper, with: "<transcript>\(transcript)</transcript>")
                .replacingOccurrences(of: token, with: "transcript")
        }
        if template.contains(token) {
            return template.replacingOccurrences(of: token, with: transcript)
        }
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return transcript }
        return template + "\n\n" + transcript
    }
}
