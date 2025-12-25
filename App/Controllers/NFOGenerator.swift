import Foundation

public final class NFOGenerator {
    public init() {}

    public func generate(details: MetadataDetails) -> String {
        var lines: [String] = []
        lines.append("<movie>")
        lines.append("  <title>\(details.title)</title>")
        if let synopsis = details.synopsis { lines.append("  <plot>\(synopsis)</plot>") }
        if let studio = details.studio { lines.append("  <studio>\(studio)</studio>") }
        if !details.performers.isEmpty {
            let joined = details.performers.joined(separator: ", ")
            lines.append("  <actors>\(joined)</actors>")
        }
        if !details.tags.isEmpty {
            let joined = details.tags.joined(separator: ", ")
            lines.append("  <genres>\(joined)</genres>")
        }
        lines.append("</movie>")
        return lines.joined(separator: "\n")
    }
}

