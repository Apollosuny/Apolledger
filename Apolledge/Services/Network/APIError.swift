//
//  APIError.swift
//  Apolledge
//

import Foundation

/// Single error type surfaced by `APIClient`. Task cancellation is rethrown as `CancellationError`, never wrapped.
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case offline
    case timeout
    case transport(URLError.Code)
    /// Missing or rejected credentials that could not be recovered by a token refresh.
    case unauthorized
    case server(status: Int, code: String?, message: String?)
    case decoding(String)

    var isConnectivityIssue: Bool {
        switch self {
        case .offline, .timeout, .transport: true
        default: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .offline:
            "Không có kết nối mạng. Kiểm tra mạng rồi thử lại."
        case .timeout, .transport:
            "Không kết nối được máy chủ. Vui lòng thử lại."
        case .unauthorized:
            "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .server(_, _, let message?):
            message
        case .invalidURL, .server, .decoding:
            "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }

    init(_ urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .timedOut:
            self = .timeout
        default:
            self = .transport(urlError.code)
        }
    }
}

/// Error body shape expected from the backend: `{ "code": "...", "message": "..." }`. Both fields optional.
struct ServerErrorBody: Decodable {
    let code: String?
    let message: String?
}
