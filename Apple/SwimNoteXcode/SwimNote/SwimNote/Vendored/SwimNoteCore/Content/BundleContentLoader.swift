import Foundation
import OSLog

private let contentLog = Logger(subsystem: "com.swimnote.content", category: "BundleContentLoader")

public struct TechniqueFileInfo: Sendable {
    public let filename: String
    public let stroke: String
    public let title: String
    public let difficulty: String?
}

public struct BundleContentLoader: Sendable {
    private let bundle: Bundle
    private let decoder = SwimNoteJSONDecoder()

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    public static func bundled() -> BundleContentLoader {
        BundleContentLoader(bundle: .main)
    }

    public func loadStrokes() throws -> [Stroke] {
        struct StrokesConfig: Decodable {
            var strokes: [Stroke]
        }

        return try loadJSON(StrokesConfig.self, named: "strokes", extension: "json").strokes
    }

    public func loadTechniques() throws -> [Technique] {
        struct TechniquesConfig: Decodable {
            var techniques: [Technique]
        }

        return try loadJSON(TechniquesConfig.self, named: "techniques", extension: "json").techniques
    }

    public func loadTechniqueTree(strokeId: StrokeID) throws -> TechniqueTree {
        try loadJSON(TechniqueTree.self, named: strokeId.rawValue, extension: "json")
    }

    public func loadMarkdown(filename: String) throws -> String {
        let normalized = filename.hasSuffix(".md") ? filename : "\(filename).md"

        // Direct approach: check file exists in bundle root
        let bundleURL = bundle.bundleURL
        let fileURL = bundleURL.appendingPathComponent(normalized)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            contentLog.info("Loaded markdown from bundle root: \(normalized)")
            return try String(contentsOf: fileURL, encoding: .utf8)
        }

        // Try subdirectories
        let subdirectories = ["swimming-strokes", "Resources/swimming-strokes"]
        for subdirectory in subdirectories {
            let subdirectoryURL = bundleURL.appendingPathComponent(subdirectory).appendingPathComponent(normalized)
            if FileManager.default.fileExists(atPath: subdirectoryURL.path) {
                contentLog.info("Loaded markdown from: \(subdirectory)/\(normalized)")
                return try String(contentsOf: subdirectoryURL, encoding: .utf8)
            }
        }

        // Fallback: use Bundle API to find resource
        contentLog.warning("File not found directly, trying Bundle.url for: \(normalized)")
        if let url = bundle.url(forResource: String(normalized.dropLast(3)), withExtension: "md") {
            return try String(contentsOf: url, encoding: .utf8)
        }

        throw ContentLoaderError.missingResource(normalized)
    }
    
    public func loadParsedTechnique(filename: String) throws -> ParsedTechniqueContent {
        let rawContent = try loadMarkdown(filename: filename)
        return TechniqueMarkdownParser().parse(filename: filename, rawContent: rawContent)
    }

    public func loadAllTechniqueTrees() throws -> [TechniqueTree] {
        StrokeID.allCases
            .filter { $0 != .im }
            .compactMap { try? loadTechniqueTree(strokeId: $0) }
    }

    public func listTechniqueMarkdownFiles() throws -> [TechniqueFileInfo] {
        let parser = TechniqueMarkdownParser()
        var files: [TechniqueFileInfo] = []

        // Direct approach: list files in bundle directory
        let bundleURL = bundle.bundleURL
        let fileManager = FileManager.default

        // Get all files in bundle
        if let allFiles = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) {
            // Filter for .md files that are technique files
            let techniqueFiles = allFiles.filter { url in
                let filename = url.lastPathComponent
                return filename.hasSuffix(".md") &&
                       (filename.hasPrefix("freestyle-") ||
                        filename.hasPrefix("backstroke-") ||
                        filename.hasPrefix("breaststroke-") ||
                        filename.hasPrefix("butterfly-") ||
                        filename.hasPrefix("starting-") ||
                        filename.hasPrefix("turning-") ||
                        filename == "freestyle.md" ||
                        filename == "backstroke.md" ||
                        filename == "breaststroke.md" ||
                        filename == "butterfly.md")
            }

            contentLog.info("Found \(techniqueFiles.count) technique files in bundle")

            for url in techniqueFiles {
                let filename = url.lastPathComponent
                let stroke = extractStrokeFromFilename(filename)

                let content = try String(contentsOf: url, encoding: .utf8)
                let parsed = parser.parse(filename: filename, rawContent: content)

                files.append(TechniqueFileInfo(
                    filename: filename,
                    stroke: stroke,
                    title: parsed.title,
                    difficulty: parsed.difficulty.isEmpty ? nil : parsed.difficulty
                ))
            }
        }

        if files.isEmpty {
            contentLog.warning("No technique markdown files found - trying Bundle.urls fallback")
            // Fallback to Bundle API approach
            if let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) {
                for url in urls {
                    let filename = url.lastPathComponent
                    let stroke = extractStrokeFromFilename(filename)

                    let content = try String(contentsOf: url, encoding: .utf8)
                    let parsed = parser.parse(filename: filename, rawContent: content)

                    files.append(TechniqueFileInfo(
                        filename: filename,
                        stroke: stroke,
                        title: parsed.title,
                        difficulty: parsed.difficulty.isEmpty ? nil : parsed.difficulty
                    ))
                }
            }
        }

        return files.sorted { a, b in
            if a.stroke != b.stroke {
                return a.stroke < b.stroke
            }
            return a.filename < b.filename
        }
    }

    private func extractStrokeFromFilename(_ filename: String) -> String {
        let prefix = filename.split(separator: "-").first ?? ""
        return String(prefix)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, named name: String, extension fileExtension: String) throws -> T {
        let url = try resourceURL(named: name, extension: fileExtension)
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    private func resourceURL(named name: String, extension fileExtension: String) throws -> URL {
        let subdirectories = [
            "config",
            "config/technique_trees",
            "swimming-strokes",
            nil
        ]

        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory) {
                return url
            }
        }

        let allMatches = bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: nil) ?? []
        if let url = allMatches.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
            return url
        }

        throw ContentLoaderError.missingResource("\(name).\(fileExtension)")
    }
}

public enum ContentLoaderError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)

    public var description: String {
        switch self {
        case .missingResource(let name):
            return "Missing bundled content resource: \(name)"
        }
    }
}

public struct LegacyJSONImporter: Sendable {
    private let decoder = SwimNoteJSONDecoder()

    public init() {}

    public func importNote(from data: Data) throws -> TrainingNote {
        try decoder.decode(TrainingNote.self, from: data)
    }

    public func importTechniqueTree(from data: Data) throws -> TechniqueTree {
        try decoder.decode(TechniqueTree.self, from: data)
    }
}
