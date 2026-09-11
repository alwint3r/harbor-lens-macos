import Foundation
import XCTest
@testable import HarborTrajectoryViewer

final class TrajectoryDecodingTests: XCTestCase {
    func testDecodesATIFTrajectoryAndPairsToolResult() throws {
        let json = #"""
        {
          "schema_version": "ATIF-v1.7",
          "session_id": "run-123",
          "agent": {
            "name": "claude-code",
            "version": "1.0",
            "model_name": "claude-sonnet"
          },
          "steps": [
            {
              "step_id": 1,
              "source": "user",
              "message": "# Fix the test\n\nPlease inspect `README.md`."
            },
            {
              "step_id": 2,
              "source": "agent",
              "model_name": "claude-opus",
              "reasoning_content": "I should **inspect** the file first.",
              "message": "I’ll inspect the repository.",
              "tool_calls": [
                {
                  "tool_call_id": "call-1",
                  "function_name": "read",
                  "arguments": {"path": "README.md"}
                }
              ],
              "observation": {
                "results": [
                  {"source_call_id": "call-1", "content": "# Project\nHello"}
                ]
              }
            }
          ]
        }
        """#

        let trajectory = try JSONDecoder().decode(Trajectory.self, from: Data(json.utf8))

        XCTAssertEqual(trajectory.schemaVersion, "ATIF-v1.7")
        XCTAssertEqual(trajectory.steps.count, 2)
        XCTAssertEqual(trajectory.toolCallCount, 1)
        XCTAssertEqual(trajectory.effectiveModel(for: trajectory.steps[1]), "claude-opus")
        XCTAssertEqual(
            trajectory.steps[1].results(for: trajectory.steps[1].toolCalls[0]).first?.content?.plainText,
            "# Project\nHello"
        )
    }

    func testDecodesMultimodalMessage() throws {
        let json = #"""
        {
          "agent": {"name": "agent", "version": "1", "model_name": "model"},
          "steps": [
            {
              "step_id": 1,
              "source": "user",
              "message": [
                {"type": "text", "text": "Describe this image."},
                {"type": "image", "source": {"media_type": "image/png", "path": "screen.png"}}
              ]
            }
          ]
        }
        """#

        let trajectory = try JSONDecoder().decode(Trajectory.self, from: Data(json.utf8))

        XCTAssertEqual(trajectory.steps[0].message.plainText, "Describe this image.")
        XCTAssertEqual(trajectory.steps[0].message.imageSources.first?.path, "screen.png")
    }

    func testIdentifiesBashToolCalls() throws {
        let json = #"""
        {
          "agent": {"name": "agent", "version": "1"},
          "steps": [
            {
              "step_id": 1,
              "source": "agent",
              "message": "Run the checks.",
              "tool_calls": [
                {"tool_call_id": "c1", "function_name": "bash", "arguments": {"command": "cat README.md"}},
                {"tool_call_id": "c2", "function_name": "Bash", "arguments": {"command": "ls"}},
                {"tool_call_id": "c3", "function_name": "execute_bash", "arguments": {"command": "pwd"}},
                {"tool_call_id": "c4", "function_name": "read", "arguments": {"path": "README.md"}}
              ]
            }
          ]
        }
        """#

        let trajectory = try JSONDecoder().decode(Trajectory.self, from: Data(json.utf8))
        let calls = trajectory.steps[0].toolCalls

        XCTAssertEqual(calls.map(\.isBashCommand), [true, true, true, false])
    }

    func testLoaderRejectsTrajectoryWithoutSteps() throws {
        let json = #"{"agent":{"name":"agent","version":"1"},"steps":[]}"#
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try TrajectoryLoader.load(from: url)) { error in
            XCTAssertEqual(error.localizedDescription, "The trajectory does not contain any steps.")
        }
    }
}
