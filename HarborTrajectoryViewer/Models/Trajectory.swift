import Foundation

/// A lossless JSON value used for tool arguments and forward-compatible metadata.
enum JSONValue: Codable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var prettyPrinted: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: self)
        }
        return text
    }
}

struct AgentMetadata: Decodable, Hashable, Sendable {
    let name: String
    let version: String?
    let modelName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case modelName = "model_name"
    }
}

struct ImageSource: Decodable, Hashable, Sendable {
    let mediaType: String?
    let path: String

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case path
    }
}

struct ContentPart: Decodable, Hashable, Sendable {
    let type: String
    let text: String?
    let source: ImageSource?
}

enum RichContent: Decodable, Hashable, Sendable {
    case text(String)
    case parts([ContentPart])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .parts(try container.decode([ContentPart].self))
        }
    }

    var plainText: String {
        switch self {
        case .text(let text):
            return text
        case .parts(let parts):
            return parts.compactMap(\.text).joined(separator: "\n\n")
        }
    }

    var imageSources: [ImageSource] {
        switch self {
        case .text:
            return []
        case .parts(let parts):
            return parts.compactMap(\.source)
        }
    }

    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageSources.isEmpty
    }
}

struct ToolCall: Decodable, Hashable, Sendable, Identifiable {
    let toolCallID: String
    let functionName: String
    let arguments: JSONValue

    var id: String { toolCallID }

    enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case functionName = "function_name"
        case arguments
    }
}

struct ObservationResult: Decodable, Hashable, Sendable, Identifiable {
    let sourceCallID: String?
    let content: RichContent?
    let extra: JSONValue?

    var id: String {
        [sourceCallID ?? "unlinked", content?.plainText ?? "", extra?.prettyPrinted ?? ""]
            .joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case sourceCallID = "source_call_id"
        case content
        case extra
    }
}

struct Observation: Decodable, Hashable, Sendable {
    let results: [ObservationResult]
}

struct TrajectoryStep: Decodable, Hashable, Sendable, Identifiable {
    let stepID: Int
    let timestamp: String?
    let source: String
    let modelName: String?
    let reasoningEffort: JSONValue?
    let message: RichContent
    let reasoningContent: String?
    let toolCalls: [ToolCall]
    let observation: Observation?
    let isCopiedContext: Bool?
    let llmCallCount: Int?

    var id: Int { stepID }

    enum CodingKeys: String, CodingKey {
        case stepID = "step_id"
        case timestamp
        case source
        case modelName = "model_name"
        case reasoningEffort = "reasoning_effort"
        case message
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
        case observation
        case isCopiedContext = "is_copied_context"
        case llmCallCount = "llm_call_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stepID = try container.decode(Int.self, forKey: .stepID)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        source = try container.decode(String.self, forKey: .source)
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
        reasoningEffort = try container.decodeIfPresent(JSONValue.self, forKey: .reasoningEffort)
        message = try container.decode(RichContent.self, forKey: .message)
        reasoningContent = try container.decodeIfPresent(String.self, forKey: .reasoningContent)
        toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls) ?? []
        observation = try container.decodeIfPresent(Observation.self, forKey: .observation)
        isCopiedContext = try container.decodeIfPresent(Bool.self, forKey: .isCopiedContext)
        llmCallCount = try container.decodeIfPresent(Int.self, forKey: .llmCallCount)
    }

    func results(for toolCall: ToolCall) -> [ObservationResult] {
        observation?.results.filter { $0.sourceCallID == toolCall.toolCallID } ?? []
    }

    var unlinkedResults: [ObservationResult] {
        observation?.results.filter { result in
            guard let sourceCallID = result.sourceCallID else { return true }
            return !toolCalls.contains { $0.toolCallID == sourceCallID }
        } ?? []
    }

    var comparisonFingerprint: String {
        let tools = toolCalls.map {
            "\($0.functionName)|\($0.arguments.prettyPrinted)"
        }.joined(separator: "\n")
        let results = observation?.results.map {
            "\($0.sourceCallID ?? "")|\($0.content?.plainText ?? "")"
        }.joined(separator: "\n") ?? ""
        return [source, modelName ?? "", message.plainText, reasoningContent ?? "", tools, results]
            .joined(separator: "\n---\n")
    }
}

struct Trajectory: Decodable, Hashable, Sendable {
    let schemaVersion: String?
    let sessionID: String?
    let trajectoryID: String?
    let agent: AgentMetadata
    let steps: [TrajectoryStep]
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionID = "session_id"
        case trajectoryID = "trajectory_id"
        case agent
        case steps
        case notes
    }

    var toolCallCount: Int { steps.reduce(0) { $0 + $1.toolCalls.count } }
    var agentTurnCount: Int { steps.filter { $0.source == "agent" }.count }
    var models: [String] {
        var values = [agent.modelName].compactMap { $0 }
        values.append(contentsOf: steps.compactMap(\.modelName))
        return values.reduce(into: []) { result, model in
            if !result.contains(model) { result.append(model) }
        }
    }

    func effectiveModel(for step: TrajectoryStep) -> String? {
        guard step.source.lowercased() == "agent" else { return nil }
        return step.modelName ?? agent.modelName
    }
}
