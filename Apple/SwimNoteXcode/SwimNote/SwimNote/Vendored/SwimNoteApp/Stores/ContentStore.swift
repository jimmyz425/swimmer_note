import Foundation

/// P3 Step 2 — bundled strokes/techniques + technique tree / markdown caches (see `docs/refactors/APPMODEL_SPLIT.md`).
@Observable
@MainActor
public final class ContentStore {
    public var strokes: [Stroke] = []
    public var techniques: [Technique] = []

    /// Used by `SwimNoteAppModel.createToolExecutor` until LLMStore extraction.
    public let bundleContentLoader: BundleContentLoader

    private var parsedContentCache: [String: ParsedTechniqueContent] = [:]
    private var treeCache: [StrokeID: TechniqueTree] = [:]

    public init(contentLoader: BundleContentLoader) {
        self.bundleContentLoader = contentLoader
    }

    public func loadBundledContent() {
        parsedContentCache = [:]
        treeCache = [:]
        strokes = (try? bundleContentLoader.loadStrokes()) ?? StrokeID.allCases
            .filter { $0 != .master && $0 != .im }
            .map { Stroke(id: $0, name: $0.rawValue.capitalized, aliases: []) }
        techniques = (try? bundleContentLoader.loadTechniques()) ?? []
    }

    public func tree(for strokeId: StrokeID) -> TechniqueTree? {
        if let cached = treeCache[strokeId] {
            return cached
        }
        guard let tree = try? bundleContentLoader.loadTechniqueTree(strokeId: strokeId) else {
            return nil
        }
        treeCache[strokeId] = tree
        return tree
    }

    public func markdown(filename: String) -> String {
        (try? bundleContentLoader.loadMarkdown(filename: filename)) ?? ""
    }

    public func parsedTechnique(filename: String) -> ParsedTechniqueContent? {
        if let cached = parsedContentCache[filename] {
            return cached
        }
        guard let parsed = try? bundleContentLoader.loadParsedTechnique(filename: filename) else {
            return nil
        }
        parsedContentCache[filename] = parsed
        return parsed
    }
}
