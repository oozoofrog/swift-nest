import Foundation

enum HarnessDocumentLoader {
    static func loadObject(at url: URL) throws -> [String: Any] {
        let text = try String(contentsOf: url, encoding: .utf8)
        if url.pathExtension.lowercased() == "json" {
            return try loadJSON(text: text, url: url)
        }
        return loadSimpleYAML(text: text)
    }

    private static func loadJSON(text: String, url: URL) throws -> [String: Any] {
        guard let data = text.data(using: .utf8) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.couldNotDecodeUTF8Text, url.path))
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw SwiftNestError(SwiftNestLocalizer.text(.expectedTopLevelObject, url.path))
        }
        return dictionary
    }

    private static func loadSimpleYAML(text: String) -> [String: Any] {
        var result: [String: Any] = [:]
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .newlines)
            index += 1

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                continue
            }

            guard let colonIndex = line.firstIndex(of: ":") else {
                continue
            }

            let rawKey = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if rawValue.isEmpty {
                var items: [String] = []
                while index < lines.count {
                    let next = lines[index]
                    guard next.hasPrefix("  -") else {
                        break
                    }
                    let item = next.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
                        .last?
                        .trimmingCharacters(in: .whitespaces) ?? ""
                    items.append(item)
                    index += 1
                }
                result[rawKey] = items
                continue
            }

            if rawValue == "true" {
                result[rawKey] = true
            } else if rawValue == "false" {
                result[rawKey] = false
            } else if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
                result[rawKey] = String(rawValue.dropFirst().dropLast())
            } else {
                result[rawKey] = rawValue
            }
        }

        return result
    }

    static func string(_ values: [String: Any], key: String, default fallback: String) -> String {
        if let stringValue = values[key] as? String {
            return stringValue
        }
        if let boolValue = values[key] as? Bool {
            return boolValue ? "true" : "false"
        }
        return fallback
    }

    static func stringArray(_ values: [String: Any], key: String) -> [String] {
        if let direct = values[key] as? [String] {
            return direct
        }
        if let bridged = values[key] as? [NSString] {
            return bridged.map { $0 as String }
        }
        return []
    }
}
