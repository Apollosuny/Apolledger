//
//  LoginViewModel.swift
//  Apolledge
//

import Foundation
import Observation

@Observable
final class LoginViewModel {
    var username = "" {
        didSet { errorMessage = nil }
    }

    var password = "" {
        didSet { errorMessage = nil }
    }

    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isFormFilled: Bool {
        !trimmedUsername.isEmpty && !password.isEmpty
    }

    func submit(signIn: (_ username: String, _ password: String) async throws -> Void) async {
        guard isFormFilled, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await signIn(trimmedUsername, password)
        } catch is CancellationError {
            return
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Đã có lỗi xảy ra. Vui lòng thử lại."
        }
    }
}
