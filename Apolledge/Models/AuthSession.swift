//
//  AuthSession.swift
//  Apolledge
//

import Foundation

struct AuthSession: Codable, Equatable {
    let userID: String
    let username: String
    let accessToken: String
}
