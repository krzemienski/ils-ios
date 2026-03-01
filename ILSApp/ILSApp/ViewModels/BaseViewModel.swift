import Foundation
import Observation
import ILSShared

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
