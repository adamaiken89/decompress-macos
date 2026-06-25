import Foundation
import OSLog

extension DecompressionService {
  func runProcess(
    _ process: Process,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let cmd =
      (process.executableURL?.lastPathComponent ?? "?")
      + " " + (process.arguments?.joined(separator: " ") ?? "")
    Self.logger.debug("Running: \(cmd, privacy: .public)")

    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { proc in
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if proc.terminationStatus == 0 {
          let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
          if !stdout.isEmpty {
            Self.logger.debug("stdout: \(stdout, privacy: .public)")
          }
          continuation.resume()
        } else {
          let stderr = String(data: stderrData, encoding: .utf8) ?? ""
          let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
          Self.logger.error(
            "Process failed (exit=\(proc.terminationStatus)): \(cmd, privacy: .public)")
          if !stderr.isEmpty {
            Self.logger.error("stderr: \(stderr, privacy: .public)")
          }
          if !stdout.isEmpty {
            Self.logger.error("stdout: \(stdout, privacy: .public)")
          }
          let toolName = process.executableURL?.lastPathComponent ?? "unknown"
          continuation.resume(
            throwing: ServiceError.processExit(toolName, proc.terminationStatus)
          )
        }
      }

      do {
        try process.run()
      } catch {
        Self.logger.error(
          "Failed to launch process: \(cmd, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
      }
    }
  }

  func runProcess(forOutput process: Process) async throws -> String {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let cmd =
      (process.executableURL?.lastPathComponent ?? "?")
      + " " + (process.arguments?.joined(separator: " ") ?? "")
    Self.logger.debug("Running: \(cmd, privacy: .public)")

    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { proc in
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if proc.terminationStatus == 0 {
          let output = String(data: stdoutData, encoding: .utf8) ?? ""
          continuation.resume(returning: output)
        } else {
          let stderr = String(data: stderrData, encoding: .utf8) ?? ""
          Self.logger.error(
            "Process failed (exit=\(proc.terminationStatus)): \(cmd, privacy: .public)")
          if !stderr.isEmpty {
            Self.logger.error("stderr: \(stderr, privacy: .public)")
          }
          let toolName = process.executableURL?.lastPathComponent ?? "unknown"
          continuation.resume(
            throwing: ServiceError.processExit(toolName, proc.terminationStatus)
          )
        }
      }

      do {
        try process.run()
      } catch {
        Self.logger.error(
          "Failed to launch process: \(cmd, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
      }
    }
  }
}
