import Foundation
import Splash

/// Splash Grammar for JavaScript source code.
///
/// Delegates to ``DataDrivenGrammar`` configured with ``GrammarConfig.javascript``.
struct JavaScriptGrammar: Grammar {
    private let inner = DataDrivenGrammar(config: .javascript)

    var delimiters: CharacterSet { inner.delimiters }
    var syntaxRules: [SyntaxRule] { inner.syntaxRules }
}
