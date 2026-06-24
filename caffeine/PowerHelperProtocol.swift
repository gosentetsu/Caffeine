import Foundation

/// XPC 常量，app 和 helper 共享。
enum PowerHelperConstants {
    static let appBundleID = "com.caffeine.Caffeine"
    static let helperBundleID = "com.caffeine.Caffeine.PowerHelper"
    static let machServiceName = "com.caffeine.Caffeine.PowerHelper"

    static var appCodeSigningRequirement: String {
        codeSigningRequirement(for: appBundleID)
    }

    static var helperCodeSigningRequirement: String {
        codeSigningRequirement(for: helperBundleID)
    }

    private static func codeSigningRequirement(for bundleID: String) -> String {
        var req = #"identifier "\#(bundleID)""#
        if let teamID = teamIdentifier() {
            req += #" and anchor apple generic and certificate leaf[subject.OU] = "\#(teamID)""#
        }
        return req
    }

    private static func teamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamID.isEmpty else { return nil }
        return teamID
    }
}

/// XPC 协议：app 调用 helper 设置/查询 disablesleep。
/// 显式指定 ObjC 名,避免主 app 与独立编译的 helper 因模块名不同导致
/// 协议运行时名字不一致(Caffeine.* vs main.*),从而 XPC 接口握手失败。
@objc(PowerHelperProtocol) protocol PowerHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool, String?) -> Void)
    func getSleepDisabled(withReply reply: @escaping (Bool, String?) -> Void)
}
