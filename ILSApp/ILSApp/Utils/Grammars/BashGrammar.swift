import Foundation
import Splash

/// Splash Grammar for Bash / shell scripts.
///
/// Delegates to ``DataDrivenGrammar`` configured with ``GrammarConfig.bash``.
struct BashGrammar: Grammar {
    private let inner = DataDrivenGrammar(config: .bash)

    var delimiters: CharacterSet { inner.delimiters }
    var syntaxRules: [SyntaxRule] { inner.syntaxRules }
}
