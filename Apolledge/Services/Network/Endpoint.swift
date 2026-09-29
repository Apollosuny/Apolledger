//
//  Endpoint.swift
//  Apolledge
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describes one API call. `Response` is the decoded body type; use `EmptyResponse` for endpoints without a body.
struct Endpoint<Response: Decodable> {
    var method: HTTPMethod
    /// Relative to the environment base URL, e.g. `"auth/login"`.
    var path: String
    var query: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: (any Encodable)?
    /// When true the client attaches the Bearer token and transparently refreshes it once on a 401.
    var requiresAuth = true
}

/// Decoded result for `204 No Content` and other empty-bodied responses.
struct EmptyResponse: Decodable, Equatable {}
