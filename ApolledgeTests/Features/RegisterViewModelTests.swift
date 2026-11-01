//
//  RegisterViewModelTests.swift
//  ApolledgeTests
//

import Testing
@testable import Apolledge

@MainActor
struct RegisterViewModelTests {
    private func filledForm() -> RegisterViewModel {
        let viewModel = RegisterViewModel()
        viewModel.username = " minh "
        viewModel.email = "m@x.vn"
        viewModel.password = "secret12"
        viewModel.acceptedTerms = true
        return viewModel
    }

    @Test func requiresTermsAndBackendLengths() {
        let viewModel = filledForm()
        #expect(viewModel.isFormValid)

        viewModel.acceptedTerms = false
        #expect(!viewModel.isFormValid)

        viewModel.acceptedTerms = true
        viewModel.password = "short"
        #expect(!viewModel.isFormValid)

        viewModel.password = String(repeating: "a", count: 73)
        #expect(!viewModel.isFormValid)
    }

    @Test func submitTrimsAndShowsTakenUsername() async {
        let viewModel = filledForm()
        var submitted: String?

        await viewModel.submit { username, _, _ in
            submitted = username
            throw AuthError.usernameTaken
        }

        #expect(submitted == "minh")
        #expect(viewModel.errorMessage == AuthError.usernameTaken.errorDescription)
    }
}
