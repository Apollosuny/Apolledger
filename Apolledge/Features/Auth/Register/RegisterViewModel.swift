//
//  RegisterViewModel.swift
//  Apolledge
//
//  Created by Trung Trần on 12/10/26.
//

import Foundation
import Observation

@Observable
final class RegisterViewModel {
    /// Backend limits from `RegisterRequest`. 72 is BCrypt's input limit.
    private static let usernameLength = 3...50
    private static let passwordLength = 8...72

    var username = "" {
        didSet { errorMessage = nil }
    }

    var email = "" {
        didSet { errorMessage = nil }
    }

    var password = "" {
        didSet { errorMessage = nil }
    }

    var acceptedTerms = false

    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmailValid: Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        return trimmedEmail.range(
            of: pattern,
            options: .regularExpression
        ) != nil
    }

    var isFormValid: Bool {
        Self.usernameLength.contains(trimmedUsername.count)
            && isEmailValid
            && Self.passwordLength.contains(password.utf8.count)
            && acceptedTerms
    }

    func submit(
        register: (_ username: String, _ email: String, _ password: String) async throws -> Void
    ) async {
        guard isFormValid, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await register(trimmedUsername, trimmedEmail, password)
        } catch is CancellationError {
            return
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }
}
