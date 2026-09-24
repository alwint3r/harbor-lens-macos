import Foundation

enum TrajectoryLoadingError: LocalizedError {
    case unreadableFile(String)
    case invalidTrajectory(String)
    case noSteps

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let detail):
            return "The file could not be read. \(detail)"
        case .invalidTrajectory(let detail):
            return "This is not a supported Harbor trajectory. \(detail)"
        case .noSteps:
            return "The trajectory does not contain any steps."
        }
    }
}

enum TrajectoryLoader {
    /// Reads `url` and decodes it.
    ///
    /// Pass the identity of an already loaded trajectory to keep its `id`
    /// stable, which lets a reload replace content without resetting the view
    /// state that is bound to that identity.
    static func load(from url: URL, id: UUID = UUID()) throws -> LoadedTrajectory {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw TrajectoryLoadingError.unreadableFile(error.localizedDescription)
        }

        let trajectory: Trajectory
        do {
            trajectory = try JSONDecoder().decode(Trajectory.self, from: data)
        } catch {
            throw TrajectoryLoadingError.invalidTrajectory(decodingDetail(for: error))
        }

        guard !trajectory.steps.isEmpty else {
            throw TrajectoryLoadingError.noSteps
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.int64Value ?? Int64(data.count)
        let modifiedAt = attributes?[.modificationDate] as? Date

        return LoadedTrajectory(
            id: id,
            url: url,
            trajectory: trajectory,
            byteCount: byteCount,
            modifiedAt: modifiedAt
        )
    }

    private static func decodingDetail(for error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing “\(key.stringValue)” at \(path(from: context.codingPath))."
        case .typeMismatch(let type, let context):
            return "Expected \(type) at \(path(from: context.codingPath))."
        case .valueNotFound(let type, let context):
            return "Missing \(type) value at \(path(from: context.codingPath))."
        case .dataCorrupted(let context):
            return "Invalid JSON at \(path(from: context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func path(from codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "the document root" }
        return codingPath.reduce("") { partial, key in
            if let index = key.intValue {
                return partial + "[\(index)]"
            }
            return partial.isEmpty ? key.stringValue : partial + "." + key.stringValue
        }
    }
}
