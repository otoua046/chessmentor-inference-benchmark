import Darwin
import Foundation
import UIKit

enum BenchmarkFlowType: String {
    case photo
    case live
}

struct BenchmarkRecord {
    let timestamp: Date
    let sessionID: String
    let device: String
    let pipelineMode: String
    let flowType: String
    let inputID: String
    let boardBackend: String
    let pieceBackend: String
    let boardMS: Double?
    let pieceMS: Double?
    let totalMS: Double?
    let detectionCount: Int?
    let fenValid: Bool?
    let success: Bool
    let errorMessage: String?

    static let headerColumns = [
        "timestamp",
        "session_id",
        "device",
        "pipeline_mode",
        "flow_type",
        "input_id",
        "board_backend",
        "piece_backend",
        "board_ms",
        "piece_ms",
        "total_ms",
        "detection_count",
        "fen_valid",
        "success",
        "error_message",
    ]

    static var headerLine: String {
        headerColumns.joined(separator: ",")
    }

    static var currentDeviceDescription: String {
        "\(hardwareIdentifier())|iOS \(UIDevice.current.systemVersion)"
    }

    var csvLine: String {
        [
            Self.iso8601Formatter.string(from: timestamp),
            sessionID,
            device,
            pipelineMode,
            flowType,
            inputID,
            boardBackend,
            pieceBackend,
            Self.format(milliseconds: boardMS),
            Self.format(milliseconds: pieceMS),
            Self.format(milliseconds: totalMS),
            detectionCount.map(String.init) ?? "",
            fenValid.map(String.init) ?? "",
            String(success),
            errorMessage ?? "",
        ]
        .map(Self.escapeCSV)
        .joined(separator: ",")
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func format(milliseconds: Double?) -> String {
        guard let milliseconds else { return "" }
        return String(format: "%.3f", milliseconds)
    }

    private static func escapeCSV(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard normalized.contains(",")
            || normalized.contains("\"")
            || normalized.contains("\n")
        else {
            return normalized
        }

        let escaped = normalized.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func hardwareIdentifier() -> String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }

        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
