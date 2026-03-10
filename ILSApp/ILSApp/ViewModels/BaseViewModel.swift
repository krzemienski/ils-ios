import Foundation
import Observation
import ILSShared

// TODO: SUIA-002 — Consider protocol-based approach instead of class inheritance
@MainActor
@Observable
class BaseViewModel {
    var isLoading = false
    var error: Error?
    var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }
}
