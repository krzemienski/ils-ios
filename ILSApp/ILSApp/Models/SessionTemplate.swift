import Foundation
import ILSShared

// MARK: - iOS Extensions

extension SessionTemplate {
    /// Convenience string representation of the optional max budget in USD.
    var maxBudgetString: String {
        maxBudgetUSD.map { String($0) } ?? ""
    }
}
