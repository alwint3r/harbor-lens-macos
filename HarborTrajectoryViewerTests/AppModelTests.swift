import XCTest
@testable import HarborTrajectoryViewer

@MainActor
final class AppModelTests: XCTestCase {
    func testClosePrimaryClearsComparisonAndAllowsOpeningAnotherFile() async throws {
        let model = makeModel()
        let first = try makeTrajectoryFile()
        let second = try makeTrajectoryFile()

        model.load(first, into: .primary)
        model.load(second, into: .comparison)
        await waitForLoads(model)
        XCTAssertNotNil(model.primary)
        XCTAssertNotNil(model.comparison)

        model.close(.primary)

        XCTAssertNil(model.primary)
        XCTAssertNil(model.comparison)
        XCTAssertTrue(model.loadingSlots.isEmpty)

        model.load(second, into: .primary)
        await waitForLoads(model)
        XCTAssertEqual(model.primary?.url, second)
    }

    func testCloseComparisonKeepsPrimary() async throws {
        let model = makeModel()
        let file = try makeTrajectoryFile()

        model.load(file, into: .primary)
        model.load(file, into: .comparison)
        await waitForLoads(model)

        model.removeComparison()

        XCTAssertNotNil(model.primary)
        XCTAssertNil(model.comparison)
    }

    func testClosingWhileLoadingFreesTheSlotForAnotherFile() async throws {
        let model = makeModel()
        let file = try makeTrajectoryFile()

        model.load(file, into: .primary)
        model.close(.primary)

        XCTAssertTrue(model.loadingSlots.isEmpty)

        // The closed load must not block opening another trajectory.
        model.load(file, into: .primary)
        await waitForLoads(model)
        XCTAssertEqual(model.primary?.url, file)
    }

    func testSuccessfulLoadsAreRecordedInRecents() async throws {
        let model = makeModel()
        let first = try makeTrajectoryFile()
        let second = try makeTrajectoryFile()

        model.load(first, into: .primary)
        await waitForLoads(model)
        model.load(second, into: .comparison)
        await waitForLoads(model)

        XCTAssertEqual(model.recentTrajectories.map(\.url), [second, first])
    }

    func testReloadingATrajectoryMovesItToTheFrontWithoutDuplicating() async throws {
        let model = makeModel()
        let first = try makeTrajectoryFile()
        let second = try makeTrajectoryFile()

        for url in [first, second, first] {
            model.load(url, into: .primary)
            await waitForLoads(model)
        }

        XCTAssertEqual(model.recentTrajectories.map(\.url), [first, second])
    }

    func testRecentsKeepOnlyTheMostRecentTen() async throws {
        let model = makeModel()
        var urls: [URL] = []

        for _ in 0..<12 {
            let url = try makeTrajectoryFile()
            urls.append(url)
            model.load(url, into: .primary)
            await waitForLoads(model)
        }

        XCTAssertEqual(model.recentTrajectories.map(\.url), Array(urls.suffix(10).reversed()))
    }

    func testRecentsPersistAcrossModelsAndCanBeCleared() async throws {
        let defaults = makeEphemeralDefaults()
        let url = try makeTrajectoryFile()

        let model = AppModel(defaults: defaults)
        model.load(url, into: .primary)
        await waitForLoads(model)

        let relaunched = AppModel(defaults: defaults)
        XCTAssertEqual(relaunched.recentTrajectories.map(\.url), [url])

        relaunched.clearRecents()
        XCTAssertTrue(relaunched.recentTrajectories.isEmpty)
        XCTAssertTrue(AppModel(defaults: defaults).recentTrajectories.isEmpty)
    }

    func testRecentTrajectoryLabelsJobTrials() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let trajectory = root
            .appendingPathComponent("2026-09-12__10-33-16")
            .appendingPathComponent("patch-diff__ZhaRoRW")
            .appendingPathComponent("agent")
            .appendingPathComponent("trajectory.json")
        try FileManager.default.createDirectory(
            at: trajectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let recent = RecentTrajectory(url: trajectory)
        XCTAssertEqual(recent.displayName, "patch-diff__ZhaRoRW")
        XCTAssertEqual(recent.jobName, "2026-09-12__10-33-16")
        XCTAssertEqual(recent.menuTitle, "patch-diff__ZhaRoRW — 2026-09-12__10-33-16")
    }

    private func makeModel() -> AppModel {
        AppModel(defaults: makeEphemeralDefaults())
    }

    private func makeEphemeralDefaults() -> UserDefaults {
        let suiteName = "AppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    /// Writes a minimal decodable trajectory to a temporary file.
    private func makeTrajectoryFile() throws -> URL {
        let json = #"{"agent":{"name":"test","version":"1.0"},"steps":[{"step_id":1,"source":"user","message":"hello"}]}"#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try Data(json.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func waitForLoads(_ model: AppModel, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !model.loadingSlots.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(model.loadingSlots.isEmpty, "Timed out waiting for trajectory loads to finish")
    }
}
