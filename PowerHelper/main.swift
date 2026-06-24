import Foundation

/// XPC Helper：以 root 权限运行，执行 pmset disablesleep 命令。
final class PowerHelper: NSObject, PowerHelperProtocol {

    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool, String?) -> Void) {
        let value = disabled ? "1" : "0"
        do {
            _ = try runProcess(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", value])
            reply(true, nil)
            NSLog("[PowerHelper] ✓ pmset disablesleep \(value)")
        } catch {
            reply(false, error.localizedDescription)
            NSLog("[PowerHelper] ✗ pmset disablesleep \(value): \(error.localizedDescription)")
        }
    }

    func getSleepDisabled(withReply reply: @escaping (Bool, String?) -> Void) {
        do {
            let output = try runProcess(executable: "/usr/bin/pmset", arguments: ["-g", "live"])
            let disabled = output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
            reply(disabled, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    private func runProcess(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "PowerHelper", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "pmset failed" : output])
        }

        return output
    }
}

// MARK: - XPC Listener

private final class PowerHelperDelegate: NSObject, NSXPCListenerDelegate {
    private let helper = PowerHelper()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: PowerHelperProtocol.self)
        connection.exportedObject = helper
        connection.resume()
        return true
    }
}

@main
struct PowerHelperMain {
    static func main() {
        let listener = NSXPCListener(machServiceName: PowerHelperConstants.machServiceName)
        let delegate = PowerHelperDelegate()
#if !DEBUG
        listener.setConnectionCodeSigningRequirement(PowerHelperConstants.appCodeSigningRequirement)
#endif
        listener.delegate = delegate
        listener.resume()

        withExtendedLifetime((listener, delegate)) {
            RunLoop.main.run()
        }
    }
}
