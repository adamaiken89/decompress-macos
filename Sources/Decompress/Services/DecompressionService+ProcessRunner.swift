import Foundation
import OSLog

final class RunningProcessTracker: @unchecked Sendable {
  static let shared = RunningProcessTracker()

  private let lock = NSLock()
  private var processes: [ObjectIdentifier: Process] = [:]

  func add(_ process: Process) {
    lock.lock()
    processes[ObjectIdentifier(process)] = process
    lock.unlock()
  }

  func remove(_ process: Process) {
    lock.lock()
    processes[ObjectIdentifier(process)] = nil
    lock.unlock()
  }

  func terminateAll() -> Int {
    lock.lock()
    let running = processes.values.filter { $0.isRunning }
    lock.unlock()
    for process in running {
      process.terminate()
    }
    return running.count
  }
}

private final class LineAccumulator: @unchecked Sendable {
  private let lock = NSLock()
  private var pending = Data()
  private var allData = Data()

  func append(_ chunk: Data) -> [String] {
    lock.lock()
    allData.append(chunk)
    pending.append(chunk)
    var lines: [String] = []
    while let newlineIndex = pending.firstIndex(of: 0x0A) {
      let lineData = pending[pending.startIndex..<newlineIndex]
      pending.removeSubrange(pending.startIndex...newlineIndex)
      if let line = Self.decode(lineData), let cleaned = ProcessOutputParser.cleanLine(line) {
        lines.append(cleaned)
      }
    }
    lock.unlock()
    return lines
  }

  func remainderLine() -> String? {
    lock.lock()
    defer { lock.unlock() }
    guard !pending.isEmpty else { return nil }
    let line = Self.decode(pending).flatMap(ProcessOutputParser.cleanLine)
    return line
  }

  var text: String {
    lock.lock()
    defer { lock.unlock() }
    return Self.decode(allData) ?? ""
  }

  private static func decode(_ data: Data) -> String? {
    String(data: data, encoding: .utf8)
  }
}

private final class StderrBox: @unchecked Sendable {
  private let lock = NSLock()
  private var data = Data()

  func append(_ chunk: Data) {
    lock.lock()
    data.append(chunk)
    lock.unlock()
  }

  var text: String {
    lock.lock()
    defer { lock.unlock() }
    return String(data: data, encoding: .utf8) ?? ""
  }
}

private final class EntryCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  private let totalUnits: Int?

  init(totalUnits: Int?) {
    self.totalUnits = totalUnits
  }

  func increment(name: String, progress: @Sendable (Double, String) -> Void) {
    lock.lock()
    count += 1
    let current = count
    lock.unlock()

    let fraction: Double
    if let totalUnits, totalUnits > 0 {
      fraction = min(Double(current) / Double(totalUnits) * 0.95, 0.95)
    } else {
      fraction = min(0.9, 0.2 + 0.7 * (1 - exp(-Double(current) / 20.0)))
    }
    progress(fraction, name)
  }
}

final class PTYChannel: @unchecked Sendable {
  private(set) var masterFD: Int32
  private(set) var slaveFD: Int32
  let slaveHandle: FileHandle

  init() throws {
    var master: Int32 = 0
    var slave: Int32 = 0
    guard openpty(&master, &slave, nil, nil, nil) == 0 else {
      throw ServiceError.processError(loc("Could not create secure password channel"))
    }
    masterFD = master
    slaveFD = slave
    slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
  }

  func write(_ text: String) {
    guard let data = text.data(using: .utf8), masterFD >= 0 else { return }
    try? FileHandle(fileDescriptor: masterFD, closeOnDealloc: false).write(contentsOf: data)
  }

  func closeMaster() {
    guard masterFD >= 0 else { return }
    close(masterFD)
    masterFD = -1
  }

  func cleanup() {
    try? slaveHandle.close()
    if masterFD >= 0 { close(masterFD) }
    masterFD = -1
    if slaveFD >= 0 { close(slaveFD) }
    slaveFD = -1
  }
}

extension DecompressionService {
  func runProcess(
    _ process: Process,
    sourceURL: URL? = nil,
    totalUnits: Int? = nil,
    progress: @Sendable @escaping (Double, String) -> Void,
    afterLaunch: (() -> Void)? = nil
  ) async throws {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let cmd =
      (process.executableURL?.lastPathComponent ?? "?")
      + " " + (process.arguments?.joined(separator: " ") ?? "")
    Self.logger.debug("Running: \(cmd, privacy: .public)")

    let stdoutAccumulator = LineAccumulator()
    let stderrAccumulator = LineAccumulator()
    let stderrBox = StderrBox()
    let counter = EntryCounter(totalUnits: totalUnits)

    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      for line in stdoutAccumulator.append(data) {
        if let name = ProcessOutputParser.entryName(from: line) {
          counter.increment(name: name, progress: progress)
        }
      }
    }
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      stderrBox.append(data)
      for line in stderrAccumulator.append(data) {
        if let name = ProcessOutputParser.entryName(from: line) {
          counter.increment(name: name, progress: progress)
        }
      }
    }

    RunningProcessTracker.shared.add(process)

    return try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { proc in
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        RunningProcessTracker.shared.remove(process)

        let stdoutText = stdoutAccumulator.text
        let stderrText = stderrBox.text

        if proc.terminationStatus == 0
          || Self.isWarningOnlyStatus(proc.terminationStatus, tool: cmd)
        {
          if let line = stdoutAccumulator.remainderLine(),
            let name = ProcessOutputParser.entryName(from: line)
          {
            counter.increment(name: name, progress: progress)
          }
          continuation.resume()
        } else {
          Self.logger.error(
            "Process failed (exit=\(proc.terminationStatus)): \(cmd, privacy: .public)")
          if !stderrText.isEmpty {
            Self.logger.error("stderr: \(stderrText, privacy: .public)")
          }
          if !stdoutText.isEmpty {
            Self.logger.error("stdout: \(stdoutText, privacy: .public)")
          }
          let toolName = process.executableURL?.lastPathComponent ?? "unknown"
          continuation.resume(
            throwing: ServiceError.classify(
              tool: toolName,
              status: proc.terminationStatus,
              stderr: stderrText,
              stdout: stdoutText,
              sourceURL: sourceURL ?? URL(fileURLWithPath: "")
            ))
        }
      }

      do {
        try process.run()
        afterLaunch?()
      } catch {
        RunningProcessTracker.shared.remove(process)
        Self.logger.error(
          "Failed to launch process: \(cmd, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
      }
    }
  }

  func runProcess(forOutput process: Process, sourceURL: URL? = nil) async throws -> String {
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let cmd =
      (process.executableURL?.lastPathComponent ?? "?")
      + " " + (process.arguments?.joined(separator: " ") ?? "")
    Self.logger.debug("Running: \(cmd, privacy: .public)")

    RunningProcessTracker.shared.add(process)

    return try await withCheckedThrowingContinuation { continuation in
      let stdoutBox = StderrBox()
      let stderrBox = StderrBox()

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
          return
        }
        stdoutBox.append(data)
      }
      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
          return
        }
        stderrBox.append(data)
      }

      process.terminationHandler = { proc in
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        RunningProcessTracker.shared.remove(process)

        if proc.terminationStatus == 0 {
          continuation.resume(returning: stdoutBox.text)
        } else {
          Self.logger.error(
            "Process failed (exit=\(proc.terminationStatus)): \(cmd, privacy: .public)")
          let stderrText = stderrBox.text
          if !stderrText.isEmpty {
            Self.logger.error("stderr: \(stderrText, privacy: .public)")
          }
          let toolName = process.executableURL?.lastPathComponent ?? "unknown"
          continuation.resume(
            throwing: ServiceError.classify(
              tool: toolName,
              status: proc.terminationStatus,
              stderr: stderrText,
              stdout: stdoutBox.text,
              sourceURL: sourceURL ?? URL(fileURLWithPath: "")
            ))
        }
      }

      do {
        try process.run()
      } catch {
        RunningProcessTracker.shared.remove(process)
        Self.logger.error(
          "Failed to launch process: \(cmd, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
      }
    }
  }

  func runProcessWithPassword(
    toolURL: URL,
    arguments: [String],
    password: String?,
    sourceURL: URL?,
    totalUnits: Int?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    let pty = try PTYChannel()
    defer { pty.cleanup() }

    let process = Process()
    process.executableURL = toolURL
    process.arguments = arguments
    process.standardInput = pty.slaveHandle

    try await runProcess(
      process,
      sourceURL: sourceURL,
      totalUnits: totalUnits,
      progress: progress,
      afterLaunch: {
        if let password, !password.isEmpty {
          pty.write(password + "\n")
        } else {
          pty.closeMaster()
        }
      })
  }

  private static func isWarningOnlyStatus(_ status: Int32, tool cmd: String) -> Bool {
    cmd.hasPrefix("tar ") && status == 1
  }
}
