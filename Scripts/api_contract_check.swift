import Foundation

@main
struct APIContractCheck {
    static func main() async {
        let api = MyfxbookAPI()
        do {
            _ = try await api.accounts(sessionID: "invalid-session-for-contract-test")
            fputs("Expected Myfxbook to reject the invalid session.\n", stderr)
            exit(1)
        } catch MyfxbookError.authenticationRequired {
            print("Myfxbook API contract check passed.")
        } catch {
            fputs("Unexpected Myfxbook response: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
