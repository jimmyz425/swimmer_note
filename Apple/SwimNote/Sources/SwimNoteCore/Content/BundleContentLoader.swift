import Foundation

public struct BundleContentLoader: Sendable {
    private let bundle: Bundle
    private let decoder = SwimNoteJSONDecoder()

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    public static func bundled() -> BundleContentLoader {
        BundleContentLoader(bundle: .module)
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
        let normalized = filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
        let url = try resourceURL(named: normalized, extension: "md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func loadAllTechniqueTrees() throws -> [TechniqueTree] {
        StrokeID.allCases
            .filter { $0 != .im }
            .compactMap { try? loadTechniqueTree(strokeId: $0) }
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
