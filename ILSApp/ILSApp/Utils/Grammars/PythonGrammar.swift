import Foundation
import Splash

/// Splash Grammar for Python source code.
///
/// Delegates to ``DataDrivenGrammar`` configured with ``GrammarConfig.python``.
struct PythonGrammar: Grammar {
    private let inner = DataDrivenGrammar(config: .python)

    var delimiters: CharacterSet { inner.delimiters }
    var syntaxRules: [SyntaxRule] { inner.syntaxRules }
}
