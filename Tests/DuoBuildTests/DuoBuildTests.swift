import XCTest
@testable import DuoBuild

final class SpecTests: XCTestCase {
    func testSpecRoundTripsThroughJSON() throws {
        let spec = DemoTemplates.expenses("Budget")
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(UISpec.self, from: data)
        XCTAssertEqual(decoded, spec)
    }

    func testUnknownValuesDecodeToSafeFallbacks() throws {
        let json = """
        {"title":"X","theme":{"accent":"Hotpink","spacing":"LARGE"},
         "nodes":[{"type":"webview","text":"evil"},{"type":"Text","text":"Hi","style":"giant"}]}
        """
        let spec = try JSONDecoder().decode(UISpec.self, from: Data(json.utf8))
        XCTAssertEqual(spec.theme.accent, .blue)
        XCTAssertEqual(spec.theme.spacing, .large)
        XCTAssertEqual(spec.nodes[0].kind, .unsupported)
        XCTAssertEqual(spec.nodes[1].kind, .text)
        XCTAssertEqual(spec.nodes[1].style, .body)
        XCTAssertFalse(spec.nodes[0].id.isEmpty)
    }

    func testValidatorRejectsEmptyAndHugeSpecs() {
        XCTAssertThrowsError(try SpecValidator.validate(UISpec(title: "Empty", nodes: [])))
        let huge = UISpec(title: "Huge", nodes: (0...SpecValidator.maxNodes).map { .text("\($0)") })
        XCTAssertThrowsError(try SpecValidator.validate(huge))
        var deep = UINode.text("leaf")
        for _ in 0..<SpecValidator.maxDepth { deep = .vstack([deep]) }
        XCTAssertThrowsError(try SpecValidator.validate(UISpec(title: "Deep", nodes: [deep])))
    }

    func testValidatorCleansNodes() throws {
        let a = UINode(id: "same", kind: .text, text: "  hello  ")
        let b = UINode(id: "same", kind: .image, symbol: "../../etc/passwd")
        let clean = try SpecValidator.validate(UISpec(title: " T ", nodes: [a, b]))
        XCTAssertEqual(clean.title, "T")
        XCTAssertEqual(clean.nodes[0].text, "hello")
        XCTAssertNil(clean.nodes[1].symbol)
        XCTAssertNotEqual(clean.nodes[0].id, clean.nodes[1].id)
    }
}

final class DemoEngineTests: XCTestCase {
    func testStarterPromptsPickTheirTemplates() {
        XCTAssertTrue(DemoEngine.generate(name: "H", prompt: "A personal habit tracker").summary.contains("habit tracker"))
        XCTAssertTrue(DemoEngine.generate(name: "R", prompt: "A restaurant landing page").summary.contains("restaurant"))
        XCTAssertTrue(DemoEngine.generate(name: "E", prompt: "A simple expense tracker").summary.contains("expense"))
    }

    func testGenerationIsDeterministicAndLabeled() {
        let a = DemoEngine.generate(name: "Zap", prompt: "Something nobody has a template for")
        let b = DemoEngine.generate(name: "Zap", prompt: "Something nobody has a template for")
        XCTAssertEqual(a.summary, b.summary)
        XCTAssertEqual(a.spec.nodes.map(\.kind), b.spec.nodes.map(\.kind))
        XCTAssertTrue(a.summary.hasPrefix("Demo mode"))
    }

    func testStylingWordsApplyOnFirstPrompt() {
        let result = DemoEngine.generate(name: "Party", prompt: "A party invite in purple")
        XCTAssertEqual(result.spec.theme.accent, .purple)
    }

    func testRefineHandlesSeveralChangesAtOnce() throws {
        let spec = DemoTemplates.habitTracker("Habits")
        let result = try DemoEngine.refine(spec, instruction: "Make it green and add a button that says See Stats")
        XCTAssertEqual(result.spec.theme.accent, .green)
        XCTAssertEqual(result.spec.nodes.last?.kind, .button)
        XCTAssertEqual(result.spec.nodes.last?.text, "See Stats")
    }

    func testRefineAddsListWithItems() throws {
        let spec = DemoTemplates.todo("Tasks")
        let result = try DemoEngine.refine(spec, instruction: "add a list of milk, eggs and bread")
        XCTAssertEqual(result.spec.nodes.last?.items, ["Milk", "Eggs", "Bread"])
    }

    func testRefineRenamesAndRemoves() throws {
        let spec = DemoTemplates.restaurant("Bistro")
        let renamed = try DemoEngine.refine(spec, instruction: "Rename it to Olive Garden")
        XCTAssertEqual(renamed.spec.title, "Olive Garden")
        XCTAssertTrue(renamed.spec.nodes.contains { $0.text == "Olive Garden" })

        let removed = try DemoEngine.refine(spec, instruction: "remove the buttons")
        XCTAssertFalse(removed.spec.allNodes.contains { $0.kind == .button })
    }

    func testUnknownRequestFailsHonestly() {
        let spec = DemoTemplates.habitTracker("Habits")
        XCTAssertThrowsError(try DemoEngine.refine(spec, instruction: "connect it to my bank")) { error in
            guard case AIError.notUnderstood = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testEverySuggestionWorksInDemoMode() throws {
        for template in DemoTemplates.all {
            let spec = template.make("Test")
            for idea in DemoEngine.suggestions(for: spec) {
                XCTAssertNoThrow(try DemoEngine.refine(spec, instruction: idea), "“\(idea)” failed on \(template.title)")
            }
        }
    }

    func testClauseSplitting() {
        XCTAssertEqual(DemoEngine.clauses(of: "make it green and add a button"), ["make it green", "add a button"])
        XCTAssertEqual(DemoEngine.clauses(of: "add a list of salt and pepper"), ["add a list of salt and pepper"])
    }

    func testDemoServiceRunsWithoutDelay() async throws {
        let service = DemoAIService(stepDelay: .zero)
        let result = try await service.generate(name: "Budget", prompt: "A simple expense tracker") { _ in }
        XCTAssertFalse(result.spec.nodes.isEmpty)
        XCTAssertTrue(service.isDemo)
    }
}

final class ProjectStoreTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    @MainActor func testFirstLaunchSeedsExamples() {
        let store = ProjectStore(directory: folder)
        XCTAssertFalse(store.projects.isEmpty)
        XCTAssertTrue(store.projects.allSatisfy { $0.versions.count >= 2 })
    }

    @MainActor func testProjectsSurviveRelaunch() throws {
        let store = ProjectStore(directory: folder, seedIfNew: false)
        var project = SampleData.makeProject(name: "Saved", prompt: "A personal habit tracker")
        let refined = try DemoEngine.refine(project.spec, instruction: "make it orange")
        project.commit(refined.spec, summary: refined.summary)
        store.add(project)

        let reopened = ProjectStore(directory: folder, seedIfNew: false)
        XCTAssertEqual(reopened.projects, store.projects)
        XCTAssertEqual(reopened.project(id: project.id)?.spec.theme.accent, .orange)
    }

    @MainActor func testRestoreAddsVersionAndKeepsHistory() throws {
        let store = ProjectStore(directory: folder, seedIfNew: false)
        var project = SampleData.makeProject(name: "History", prompt: "A simple expense tracker")
        let first = project.versions[0]
        let refined = try DemoEngine.refine(project.spec, instruction: "Use a dark background")
        project.commit(refined.spec, summary: refined.summary)
        store.add(project)

        store.update(project.id) { $0.restore(first.id) }
        let restored = try XCTUnwrap(ProjectStore(directory: folder, seedIfNew: false).project(id: project.id))
        XCTAssertEqual(restored.versions.count, 3)
        XCTAssertEqual(restored.spec, first.spec)
        XCTAssertEqual(restored.currentVersion?.number, 3)
    }

    @MainActor func testRenameDuplicateDelete() throws {
        let store = ProjectStore(directory: folder, seedIfNew: false)
        let project = SampleData.makeProject(name: "One", prompt: "A to-do list")
        store.add(project)

        store.rename(project.id, to: "  Two  ")
        XCTAssertEqual(store.project(id: project.id)?.name, "Two")
        store.rename(project.id, to: "   ")
        XCTAssertEqual(store.project(id: project.id)?.name, "Two")

        let copy = try XCTUnwrap(store.duplicate(project.id))
        XCTAssertEqual(copy.name, "Two Copy")
        XCTAssertNotEqual(copy.id, project.id)
        XCTAssertEqual(store.duplicate(project.id)?.name, "Two Copy 2")

        store.delete(project.id)
        XCTAssertNil(ProjectStore(directory: folder, seedIfNew: false).project(id: project.id))
        XCTAssertEqual(store.projects.count, 2)
    }

    @MainActor func testUnreadableFileIsKeptAndReported() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appendingPathComponent("projects.json"))
        let store = ProjectStore(directory: folder)
        XCTAssertNotNil(store.loadProblem)
        XCTAssertTrue(store.projects.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("projects-unreadable-") })
    }
}

final class LayoutTests: XCTestCase {
    func testLayoutFollowsAvailableWidth() {
        // Cover-display-sized and regular iPhone widths: one pane.
        XCTAssertEqual(WorkspaceLayout.resolve(width: 375, sizeClass: .compact), .single)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 430, sizeClass: .compact), .single)
        // Wide windows, like an open inner display or iPad: two panes.
        XCTAssertEqual(WorkspaceLayout.resolve(width: 744, sizeClass: .regular), .split)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 620, sizeClass: .regular), .split)
        XCTAssertEqual(WorkspaceLayout.resolve(width: 620, sizeClass: .compact), .single)
    }

    func testBuilderWidthStaysReadable() {
        XCTAssertEqual(WorkspaceLayout.builderWidth(total: 700), 320)
        XCTAssertEqual(WorkspaceLayout.builderWidth(total: 1366), 440)
    }

    func testBackendAddressMustBeSecure() {
        XCTAssertNotNil(AISettings.validURL("https://api.example.com/duobuild"))
        XCTAssertNotNil(AISettings.validURL("http://localhost:8787"))
        XCTAssertNil(AISettings.validURL("http://api.example.com"))
        XCTAssertNil(AISettings.validURL("not a url"))
    }
}
