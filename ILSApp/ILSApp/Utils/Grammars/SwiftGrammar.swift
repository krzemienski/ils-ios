import Foundation
import Splash

/// Splash Grammar for Swift source code.
///
/// Wraps Splash's built-in ``Splash/SwiftGrammar`` so that Swift files
/// integrate uniformly with the ``GrammarRegistry`` dispatch path.
struct SwiftGrammarWrapper: Grammar {
    private let inner = Splash.SwiftGrammar()

    var delimiters: CharacterSet { inner.delimiters }
    var syntaxRules: [SyntaxRule] { inner.syntaxRules }
}
