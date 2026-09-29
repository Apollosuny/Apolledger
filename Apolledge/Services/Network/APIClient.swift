//
//  APIClient.swift
//  Apolledge
//

import Foundation
import OSLog

protocol APIClient {
    func send<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response
}

/// Supplies and renews the Bearer token for authenticated endpoints.
protocol AccessTokenProvider: AnyObject {
    var accessToken: String? { get }
    /// Returns a token newer than `rejectedToken`, refreshing if needed. Throws `APIError.unauthorized` when the session is gone.
    func refreshAccessToken(rejecting rejectedToken: String) async throws -> String
}

/// Seam over `URLSession` so tests can stub responses without global `URLProtocol` state.
protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let transport: HTTPTransport
    private let tokenProvider: AccessTokenProvider?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let timeout: TimeInterval
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Apolledge", category: "network")

    init(
        baseURL: URL,
        transport: HTTPTransport = URLSession.shared,
        tokenProvider: AccessTokenProvider? = nil,
        encoder: JSONEncoder = .api,
        decoder: JSONDecoder = .api,
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.encoder = encoder
        self.decoder = decoder
        self.timeout = timeout
    }

    func send<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let data = try await perform(endpoint, allowsTokenRefresh: true)
        return try decode(Response.self, from: data)
    }

    private func perform<Response>(_ endpoint: Endpoint<Response>, allowsTokenRefresh: Bool) async throws -> Data {
        try Task.checkCancellation()

        var request = try makeRequest(for: endpoint)
        var sentToken: String?
        if endpoint.requiresAuth {
            guard let token = tokenProvider?.accessToken else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            sentToken = token
        }

        let (data, response) = try await execute(request)

        switch response.statusCode {
        case 200..<300:
            return data
        case 401:
            guard allowsTokenRefresh, let sentToken, let tokenProvider else { throw APIError.unauthorized }
            _ = try await tokenProvider.refreshAccessToken(rejecting: sentToken)
            return try await perform(endpoint, allowsTokenRefresh: false)
        default:
            let body = try? decoder.decode(ServerErrorBody.self, from: data)
            throw APIError.server(status: response.statusCode, code: body?.code, message: body?.message)
        }
    }

    private func makeRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        var url = baseURL.appending(path: endpoint.path)
        if !endpoint.query.isEmpty {
            url.append(queryItems: endpoint.query)
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let startedAt = ContinuousClock.now
        let method = request.httpMethod ?? "?"
        let path = request.url?.path() ?? "?"

        do {
            let (data, response) = try await transport.send(request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.transport(.badServerResponse)
            }
            logger.debug("\(method, privacy: .public) \(path) → \(httpResponse.statusCode, privacy: .public) in \(startedAt.duration(to: .now), privacy: .public)")
            return (data, httpResponse)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            logger.error("\(method, privacy: .public) \(path) failed: \(error.code.rawValue, privacy: .public)")
            throw APIError(error)
        }
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error("Decoding \(String(describing: type), privacy: .public) failed: \(error)")
            throw APIError.decoding(String(describing: error))
        }
    }
}

extension JSONEncoder {
    /// Assumes a camelCase JSON contract with ISO-8601 dates; adjust here if the backend differs.
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
