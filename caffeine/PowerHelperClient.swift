import Foundation
import ServiceManagement

/// XPC 客户端：主 app 通过它调用特权 Helper 执行 pmset。
final class PowerHelperClient {
    static let shared = PowerHelperClient()

    private static let timeoutNanoseconds: UInt64 = 8_000_000_000

    private let service = SMAppService.daemon(plistName: "com.caffeine.Caffeine.PowerHelper.plist")
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    private init() {}

    // MARK: - 公开接口

    func setSleepDisabled(_ disabled: Bool) async throws {
        try await perform { connection in
            try await self.sendSetSleepDisabled(disabled, connection: connection)
        }
    }

    func isSleepDisabled() async throws -> Bool {
        try await perform { connection in
            try await self.sendGetSleepDisabled(connection: connection)
        }
    }

    func openHelperApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - XPC 连接管理

    private func perform<T>(_ operation: (NSXPCConnection) async throws -> T) async throws -> T {
        try registerIfNeeded()
        do {
            return try await operation(makeConnection())
        } catch {
            guard shouldRefresh(after: error) else { throw error }
            try refreshRegistration(after: error)
            return try await operation(makeConnection())
        }
    }

    private func registerIfNeeded() throws {
        switch service.status {
        case .enabled: return
        case .notRegistered, .notFound:
            do { try service.register() }
            catch {
                if service.status == .requiresApproval {
                    throw PowerHelperError.requiresApproval
                }
                throw error
            }
        case .requiresApproval:
            throw PowerHelperError.requiresApproval
        @unknown default:
            throw PowerHelperError.unavailable
        }
    }

    private func shouldRefresh(after error: Error) -> Bool {
        guard let e = error as? PowerHelperError else { return false }
        switch e {
        case .timedOut, .unavailable: return true
        case .commandFailed, .requiresApproval: return false
        }
    }

    private func refreshRegistration(after error: Error) throws {
        resetConnection()
        do {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            try registerIfNeeded()
        } catch {
            throw error
        }
    }

    private func makeConnection() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }

        if let connection { return connection }

        let conn = NSXPCConnection(machServiceName: PowerHelperConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: PowerHelperProtocol.self)
#if !DEBUG
        conn.setCodeSigningRequirement(PowerHelperConstants.helperCodeSigningRequirement)
#endif
        conn.invalidationHandler = { [weak self, weak conn] in
            if let conn { self?.clearConnection(conn) }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func resetConnection() {
        lock.lock()
        let conn = connection
        connection = nil
        lock.unlock()
        conn?.invalidate()
    }

    private func clearConnection(_ conn: NSXPCConnection) {
        lock.lock()
        defer { lock.unlock() }
        if connection === conn { connection = nil }
    }

    // MARK: - XPC 调用

    private func sendSetSleepDisabled(_ disabled: Bool, connection: NSXPCConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let gate = ContinuationGate(continuation)
            let timeout = scheduleTimeout(for: gate, connection: connection)

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self, weak connection] error in
                timeout.cancel()
                if let connection { self?.clearConnection(connection) }
                gate.resume(throwing: error)
            }) as? PowerHelperProtocol else {
                timeout.cancel()
                gate.resume(throwing: PowerHelperError.unavailable)
                return
            }

            proxy.setSleepDisabled(disabled) { success, message in
                timeout.cancel()
                if success { gate.resume() }
                else { gate.resume(throwing: PowerHelperError.commandFailed(message)) }
            }
        }
    }

    private func sendGetSleepDisabled(connection: NSXPCConnection) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, any Error>) in
            let gate = ContinuationGate(continuation)
            let timeout = scheduleTimeout(for: gate, connection: connection)

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self, weak connection] error in
                timeout.cancel()
                if let connection { self?.clearConnection(connection) }
                gate.resume(throwing: error)
            }) as? PowerHelperProtocol else {
                timeout.cancel()
                gate.resume(throwing: PowerHelperError.unavailable)
                return
            }

            proxy.getSleepDisabled { disabled, message in
                timeout.cancel()
                if let message { gate.resume(throwing: PowerHelperError.commandFailed(message)) }
                else { gate.resume(returning: disabled) }
            }
        }
    }

    private func scheduleTimeout<Value>(for gate: ContinuationGate<Value>, connection: NSXPCConnection) -> Task<Void, Never> {
        Task { [weak self, weak connection] in
            try? await Task.sleep(nanoseconds: Self.timeoutNanoseconds)
            guard !Task.isCancelled else { return }
            if let connection { self?.clearConnection(connection) }
            gate.resume(throwing: PowerHelperError.timedOut)
        }
    }
}

// MARK: - 辅助类型

private final class ContinuationGate<Value> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) { self.continuation = continuation }

    func resume(returning value: Value) { take()?.resume(returning: value) }
    func resume(throwing error: any Error) { take()?.resume(throwing: error) }
    func resume() where Value == Void { take()?.resume() }

    private func take() -> CheckedContinuation<Value, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let c = continuation
        continuation = nil
        return c
    }
}

enum PowerHelperError: LocalizedError {
    case commandFailed(String?)
    case requiresApproval
    case timedOut
    case unavailable

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg):
            return msg ?? "pmset failed"
        case .requiresApproval:
            return "请在「系统设置 → 通用 → 登录项与扩展」中允许 Caffeine Helper，然后重试。"
        case .timedOut:
            return "Caffeine Helper 无响应。请在系统设置中批准或重新打开 Caffeine 后重试。"
        case .unavailable:
            return "Caffeine Helper 不可用。"
        }
    }
}
