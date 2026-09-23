import XCTest

@testable import MiMiNavigator

// MARK: - Diagnostic Report Builder Tests
final class DiagnosticReportBuilderTests: XCTestCase {
    // MARK: - Personal Identifiers
    func testSanitizeRemovesHomeUserHostAndEmail() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let user = NSUserName()
        let source = "path=\(home)/Documents user=\(user) remote=sftp://\(user)@192.168.1.42/home email=person@example.com"
        let result = DiagnosticReportBuilder.sanitize(source)
        XCTAssertFalse(result.contains(home))
        XCTAssertFalse(result.contains("192.168.1.42"))
        XCTAssertFalse(result.contains("person@example.com"))
        XCTAssertTrue(result.contains("[HOME]"))
        XCTAssertTrue(result.contains("[REMOTE]"))
    }

    // MARK: - Secrets
    func testSanitizeRemovesCommonSecrets() {
        let source = "token=abc123 password: hunter2 api_key=private authorization=Bearer-secret"
        let result = DiagnosticReportBuilder.sanitize(source)
        XCTAssertFalse(result.contains("abc123"))
        XCTAssertFalse(result.contains("hunter2"))
        XCTAssertFalse(result.contains("private"))
        XCTAssertFalse(result.contains("Bearer-secret"))
        XCTAssertEqual(result.components(separatedBy: "[REDACTED]").count - 1, 4)
    }
}
