import Foundation

struct TranscriptionResult: Equatable {
    var text: String
    var analysis: AudioAnalysisResult?
}

enum TranscriptPostProcessor {
    static func process(_ transcript: String, vocabulary: [String]) -> String {
        let normalized = transcript
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else { return "" }
        guard vocabulary.isEmpty == false else { return normalized }

        let termMap = Dictionary(uniqueKeysWithValues: vocabulary.map { ($0.lowercased(), $0) })
        let tokenPattern = #"[A-Za-z0-9._/\-]+"#
        let regex = try? NSRegularExpression(pattern: tokenPattern)
        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex?.matches(in: normalized, range: nsRange) ?? []

        var output = normalized
        for match in matches.reversed() {
            guard let range = Range(match.range, in: output) else { continue }
            let token = String(output[range])
            let corrected = bestCorrection(for: token, terms: termMap)
            if corrected != token {
                output.replaceSubrange(range, with: corrected)
            }
        }
        return output
    }

    private static func bestCorrection(for token: String, terms: [String: String]) -> String {
        let lowered = token.lowercased()
        if let exact = terms[lowered] {
            return exact
        }

        let tokenSegments = splitPreservingTechnicalSeparators(token)
        let correctedSegments = tokenSegments.map { segment -> String in
            guard segment.range(of: #"^[A-Za-z0-9]+$"#, options: .regularExpression) != nil else {
                return segment
            }
            return bestSingleTokenCorrection(for: segment, terms: terms)
        }
        return correctedSegments.joined()
    }

    private static func splitPreservingTechnicalSeparators(_ token: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for character in token {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else {
                if current.isEmpty == false {
                    parts.append(current)
                    current = ""
                }
                parts.append(String(character))
            }
        }
        if current.isEmpty == false {
            parts.append(current)
        }
        return parts
    }

    private static func bestSingleTokenCorrection(for token: String, terms: [String: String]) -> String {
        let lowered = token.lowercased()
        guard token.count >= 3 else { return token }

        var best: (candidate: String, distance: Int)?
        for (key, original) in terms {
            guard abs(key.count - lowered.count) <= 2 else { continue }
            let distance = levenshtein(lowered, key)
            let threshold = lowered.count >= 7 ? 2 : 1
            guard distance <= threshold else { continue }
            if best == nil || distance < best!.distance {
                best = (original, distance)
            }
        }

        return best?.candidate ?? token
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var distances = Array(0...b.count)
        for (i, charA) in a.enumerated() {
            var previous = distances[0]
            distances[0] = i + 1
            for (j, charB) in b.enumerated() {
                let current = distances[j + 1]
                if charA == charB {
                    distances[j + 1] = previous
                } else {
                    distances[j + 1] = min(previous, distances[j], current) + 1
                }
                previous = current
            }
        }
        return distances[b.count]
    }
}
