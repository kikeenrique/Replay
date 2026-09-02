import Foundation

/// A lightweight HTTP stub used for in-memory playback without a HAR file.
public struct Stub: Sendable {

    /// A source location describing where a stub was constructed.
    ///
    /// Replay uses this information to improve diagnostics
    /// when a request does not match any available stubs.
    public struct SourceLocation: Sendable, Hashable, CustomStringConvertible {
        public let file: String
        public let line: Int

        public var description: String {
            "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        }
    }

    /// HTTP request method.
    public enum Method: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
        case get
        case post
        case put
        case delete
        case patch
        case head
        case options
        case trace
        case connect
        case custom(String)

        public init(rawValue: String) {
            switch rawValue.uppercased() {
            case "GET": self = .get
            case "POST": self = .post
            case "PUT": self = .put
            case "DELETE": self = .delete
            case "PATCH": self = .patch
            case "HEAD": self = .head
            case "OPTIONS": self = .options
            case "TRACE": self = .trace
            case "CONNECT": self = .connect
            default: self = .custom(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .get: return "GET"
            case .post: return "POST"
            case .put: return "PUT"
            case .delete: return "DELETE"
            case .patch: return "PATCH"
            case .head: return "HEAD"
            case .options: return "OPTIONS"
            case .trace: return "TRACE"
            case .connect: return "CONNECT"
            case .custom(let method): return method
            }
        }

        public var description: String {
            rawValue
        }

        public static func == (lhs: Method, rhs: Method) -> Bool {
            lhs.rawValue.caseInsensitiveCompare(rhs.rawValue) == .orderedSame
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue.uppercased())
        }
    }

    public var sourceLocation: SourceLocation?
    public var method: Method
    public var url: URL
    public var status: Int
    public var headers: [String: String]
    public var body: Data?

    /// Expected request headers,
    /// used by `Matcher.headers([...])` during stub-based playback.
    ///
    /// Unlike ``headers``,
    /// which becomes the *response* headers returned to the caller,
    /// these are compared against the incoming request's headers.
    /// A stub with no `requestHeaders` set (the default) is a no-op for `.headers` matching —
    /// the incoming request's header values must be `nil` to match,
    /// which is rarely useful.
    /// Set this via ``matchingRequestHeaders(_:)``
    /// when you need to assert that a specific request header
    /// (e.g. `Accept`, `Prefer`) was sent with a specific value.
    public var requestHeaders: [String: String] = [:]

    /// Initialize a stub with a specific method and URL.
    /// - Parameters:
    ///   - method: HTTP method (default: .get).
    ///   - url: Request URL.
    ///   - status: HTTP status code (default: 200).
    ///   - headers: HTTP headers.
    ///   - body: Response body data.
    ///   - file: Source file name (captured automatically).
    ///   - line: Source line number (captured automatically).
    public init(
        file: String = #file,
        line: Int = #line,
        _ method: Method = .get,
        _ url: URL,
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data? = nil,
    ) {
        self.sourceLocation = SourceLocation(file: file, line: line)
        self.method = method
        self.url = url
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// Initialize a stub with a specific method and URL string.
    /// - Parameters:
    ///   - method: HTTP method (default: .get).
    ///   - url: Request URL string.
    ///   - status: HTTP status code (default: 200).
    ///   - headers: HTTP headers.
    ///   - body: Response body data.
    ///   - file: Source file name (captured automatically).
    ///   - line: Source line number (captured automatically).
    public init(
        file: String = #file,
        line: Int = #line,
        _ method: Method = .get,
        _ url: String,
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data? = nil,
    ) {
        guard let u = URL(string: url) else {
            fatalError("Invalid URL string: \(url)")
        }
        self.init(file: file, line: line, method, u, status: status, headers: headers, body: body)
    }

    /// Initialize a stub with a String body (UTF-8).
    /// - Parameters:
    ///   - method: HTTP method (default: .get).
    ///   - url: Request URL.
    ///   - status: HTTP status code (default: 200).
    ///   - headers: HTTP headers.
    ///   - body: Response body string (encoded as UTF-8).
    ///   - file: Source file name (captured automatically).
    ///   - line: Source line number (captured automatically).
    public init(
        _ method: Method = .get,
        _ url: URL,
        status: Int = 200,
        headers: [String: String] = [:],
        body: String,
        file: String = #file,
        line: Int = #line
    ) {
        self.init(
            file: file,
            line: line,
            method,
            url,
            status: status,
            headers: headers,
            body: body.data(using: .utf8),
        )
    }

    /// Initialize a stub with a String body (UTF-8) and URL string.
    /// - Parameters:
    ///   - file: Source file name (captured automatically).
    ///   - line: Source line number (captured automatically).
    ///   - method: HTTP method (default: .get).
    ///   - url: Request URL string.
    ///   - status: HTTP status code (default: 200).
    ///   - headers: HTTP headers.
    ///   - body: Response body string (encoded as UTF-8).
    public init(
        file: String = #file,
        line: Int = #line,
        _ method: Method = .get,
        _ url: String,
        status: Int = 200,
        headers: [String: String] = [:],
        body: String
    ) {
        guard let u = URL(string: url) else {
            fatalError("Invalid URL string: \(url)")
        }
        self.init(
            file: file,
            line: line,
            method,
            u,
            status: status,
            headers: headers,
            body: body.data(using: .utf8)
        )
    }
}

// MARK: - Convenience Factory Methods

extension Stub {

    /// Create a GET stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    ///   - body: A closure that produces the response body as UTF-8 text.
    /// - Returns: A stub that matches `GET url`.
    public static func get(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String],
        _ body: () -> String
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .get,
            url,
            status: status,
            headers: headers,
            body: body().data(using: .utf8),
        )
    }

    /// Create a POST stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    ///   - body: A closure that produces the response body as UTF-8 text.
    /// - Returns: A stub that matches `POST url`.
    public static func post(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String],
        _ body: () -> String
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .post,
            url,
            status: status,
            headers: headers,
            body: body().data(using: .utf8),

        )
    }

    /// Create a PUT stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    ///   - body: A closure that produces the response body as UTF-8 text.
    /// - Returns: A stub that matches `PUT url`.
    public static func put(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String],
        _ body: () -> String
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .put,
            url,
            status: status,
            headers: headers,
            body: body().data(using: .utf8),

        )
    }

    /// Create a DELETE stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    ///   - body: A closure that produces the response body as UTF-8 text.
    /// - Returns: A stub that matches `DELETE url`.
    public static func delete(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String],
        _ body: () -> String
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .delete,
            url,
            status: status,
            headers: headers,
            body: body().data(using: .utf8),
        )
    }

    /// Create a PATCH stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    ///   - body: A closure that produces the response body as UTF-8 text.
    /// - Returns: A stub that matches `PATCH url`.
    public static func patch(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String],
        _ body: () -> String
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .patch,
            url,
            status: status,
            headers: headers,
            body: body().data(using: .utf8),
        )
    }

    /// Create a HEAD stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    /// - Returns: A stub that matches `HEAD url`.
    public static func head(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String]
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .head,
            url,
            status: status,
            headers: headers,
            body: nil,
        )
    }

    /// Create a OPTIONS stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    /// - Returns: A stub that matches `OPTIONS url`.
    public static func options(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String]
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .options,
            url,
            status: status,
            headers: headers,
            body: nil,
        )
    }

    /// Create a TRACE stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    /// - Returns: A stub that matches `TRACE url`.
    public static func trace(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String]
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .trace,
            url,
            status: status,
            headers: headers,
            body: nil,
        )
    }

    /// Create a CONNECT stub.
    ///
    /// - Parameters:
    ///   - file: The source file where the stub is defined.
    ///   - line: The source line where the stub is defined.
    ///   - url: The request URL string.
    ///   - status: The HTTP status code to return.
    ///   - headers: The HTTP headers to return.
    /// - Returns: A stub that matches `CONNECT url`.
    public static func connect(
        file: String = #file,
        line: Int = #line,
        _ url: String,
        _ status: Int,
        _ headers: [String: String]
    ) -> Stub {
        Stub(
            file: file,
            line: line,
            .connect,
            url,
            status: status,
            headers: headers,
            body: nil,
        )
    }
}

// MARK: - Request Header Matching

extension Stub {
    /// Returns a copy of this stub with expected request headers set,
    /// for use with `Matcher.headers([...])`.
    ///
    /// - Parameters:
    ///   - headers: The request header names and values to match against the incoming request.
    ///     Only the header names you pass to `Matcher.headers([...])` are actually compared,
    ///     so it's safe to include more headers here than you match on.
    /// - Returns: A copy of the stub with `requestHeaders` set.
    public func matchingRequestHeaders(_ headers: [String: String]) -> Stub {
        var copy = self
        copy.requestHeaders = headers
        return copy
    }
}
