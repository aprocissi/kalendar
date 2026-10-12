// Request building and response parsing for Google sign-in. Every sign-in and every token refresh
// runs through this code, and a mistake here fails only against Google's live servers.
import XCTest
@testable import KalendarCore

final class GoogleOAuthTests: XCTestCase {
    /// RFC 7636 Appendix B.
    func testPKCEChallengeMatchesRFCVector() {
        let pkce = GoogleOAuth.PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        XCTAssertEqual(pkce.challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testGeneratedVerifierIsURLSafeAndLongEnough() {
        let verifier = GoogleOAuth.PKCE.generate().verifier
        XCTAssertEqual(verifier.count, 43)
        XCTAssertNil(verifier.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        XCTAssertNotEqual(verifier, GoogleOAuth.PKCE.generate().verifier)
    }

    func testAuthorizationURLCarriesEveryParameter() throws {
        let pkce = GoogleOAuth.PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        let url = GoogleOAuth.authorizationURL(pkce: pkce, state: "s1", loginHint: "a@example.com")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let q = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "accounts.google.com")
        XCTAssertEqual(q["client_id"], GoogleOAuth.clientID)
        XCTAssertEqual(q["redirect_uri"], "\(GoogleOAuth.redirectScheme):/oauth2redirect")
        XCTAssertEqual(q["response_type"], "code")
        XCTAssertEqual(q["code_challenge"], "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertEqual(q["code_challenge_method"], "S256")
        XCTAssertEqual(q["state"], "s1")
        XCTAssertEqual(q["login_hint"], "a@example.com")
        let scopes = Set((q["scope"] ?? "").split(separator: " ").map(String.init))
        XCTAssertEqual(scopes.count, 7)
        XCTAssertTrue(scopes.isSuperset(of: GoogleOAuth.requiredScopes))
        XCTAssertTrue(scopes.isSuperset(of: GoogleOAuth.optionalScopes))
    }

    /// The redirect scheme must be the reversed client ID, or Google rejects the redirect URI.
    func testRedirectSchemeIsReversedClientID() {
        let id = GoogleOAuth.clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        XCTAssertEqual(GoogleOAuth.redirectScheme, "com.googleusercontent.apps.\(id)")
    }

    func testCallbackParsing() throws {
        let ok = URL(string: "\(GoogleOAuth.redirectScheme):/oauth2redirect?state=s1&code=4/abc&scope=x")!
        XCTAssertEqual(try GoogleOAuth.code(fromCallback: ok, expectedState: "s1"), "4/abc")
        XCTAssertThrowsError(try GoogleOAuth.code(fromCallback: ok, expectedState: "other")) {
            XCTAssertEqual($0 as? GoogleOAuth.Error, .stateMismatch)
        }
        let denied = URL(string: "\(GoogleOAuth.redirectScheme):/oauth2redirect?error=access_denied&state=s1")!
        XCTAssertThrowsError(try GoogleOAuth.code(fromCallback: denied, expectedState: "s1")) {
            XCTAssertEqual($0 as? GoogleOAuth.Error, .accessDenied)
        }
    }

    func testTokenRequestIsFormEncoded() throws {
        let request = GoogleOAuth.tokenRequest(code: "4/a b+c", pkce: .init(verifier: "v"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://oauth2.googleapis.com/token")
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains("code=4%2Fa%20b%2Bc"))
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertTrue(body.contains("code_verifier=v"))
        XCTAssertFalse(body.contains("client_secret"))
    }

    func testTokenResponseParsing() throws {
        let json = """
        {"access_token":"at","expires_in":3599,"refresh_token":"rt","id_token":"x.y.z",
         "scope":"openid https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks"}
        """
        let r = try GoogleOAuth.parseTokenResponse(data: Data(json.utf8), status: 200)
        XCTAssertEqual(r.accessToken, "at")
        XCTAssertEqual(r.refreshToken, "rt")
        XCTAssertEqual(r.expiresIn, 3599)
        XCTAssertEqual(GoogleOAuth.missingRequiredScopes(r.grantedScopes), [])
    }

    /// Google's consent screen lets the user untick a scope and still "succeed".
    func testMissingScopesAreReported() {
        let granted: Set = ["openid", "https://www.googleapis.com/auth/tasks"]
        XCTAssertEqual(GoogleOAuth.missingRequiredScopes(granted), ["https://www.googleapis.com/auth/calendar"])
    }

    func testInvalidGrantIsDistinguishedFromOtherErrors() {
        XCTAssertThrowsError(try GoogleOAuth.parseTokenResponse(
            data: Data(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#.utf8),
            status: 400)) { XCTAssertEqual($0 as? GoogleOAuth.Error, .invalidGrant) }
        XCTAssertThrowsError(try GoogleOAuth.parseTokenResponse(
            data: Data(#"{"error":"invalid_client"}"#.utf8), status: 401)) {
            XCTAssertEqual($0 as? GoogleOAuth.Error, .server("invalid_client"))
        }
        XCTAssertThrowsError(try GoogleOAuth.parseTokenResponse(data: Data("<html>".utf8), status: 503)) {
            XCTAssertEqual($0 as? GoogleOAuth.Error, .server("HTTP 503"))
        }
    }

    func testEmailFromIDToken() {
        XCTAssertEqual(GoogleOAuth.email(fromIDToken: Self.idToken(email: "a@example.com")), "a@example.com")
        XCTAssertNil(GoogleOAuth.email(fromIDToken: "not-a-jwt"))
    }

    static func idToken(email: String) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: ["email": email, "sub": "1"])
        return "eyJhbGciOiJSUzI1NiJ9.\(payload.base64URLEncoded).sig"
    }
}
