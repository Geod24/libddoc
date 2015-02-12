/**
 * Perform highlighting on code section.
 *
 * DDOC string can contains embedded code. Those code can be highlighted by
 * means of macros (keywork will be surrounded by $(DOLLAR)(D_KEYWORD),
 * comments by $(DOLLAR)(D_COMMENT), etc...
 * This module performs the highlighting.
 *
 * Copyright: © 2014 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott, Mathias 'Geod24' Lang
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module ddoc.highlight;

/**
 * Parses a string and replace embedded code (code between at least 3 '-') with
 * the relevant macros.
 *
 * Params:
 * str = A string that might contain embedded code. Only code will be modified.
 *	 If the string doesn't contain any embedded code, it will be returned as is.
 *
 * Returns:
 * A (possibly new) string containing the embedded code put in the proper macros.
 */
string highlight(string str) {
	// Note: I don't think DMD is conformant w.r.t ddoc.
	// The following file:
	// Ddoc
	// ----
	// int main(string[] args) { return 0;}
	// void test(int hello, string other);
	// ----
	//
	// Produce the following document ($(DDOC) boilerplate excluded:
	//
	// <pre class="d_code"><font color=blue>int</font> main(string[] args) { <font color=blue>return</font> 0;}
	// <font color=blue>void</font> test(<font color=blue>int</font> hello, string other);
	// </pre>

	import ddoc.lexer;
	import ddoc.macros : tokOffset;
	import std.array : appender;
	import std.string : representation;
	static import dlex = std.d.lexer;

	enum fName = "<embedded-code-in-documentation>";
	auto cache = dlex.StringCache(dlex.StringCache.defaultBucketCount);
	auto lex = Lexer(str, true);
	auto output = appender!string;
	size_t start;
	// We need this because there's no way to tell how many dashes precede
	// an embedded.
	size_t end;
	while (!lex.empty) {
		if (lex.front.type == Type.embedded) {
			output.put(lex.text[start .. end]);
			output.put("$(D_CODE ");
			auto toks = dlex.byToken(lex.front.text.representation.dup,
						 dlex.LexerConfig(fName, dlex.StringBehavior.source,
								  dlex.WhitespaceBehavior.include), &cache);
			while (!toks.empty) {
				if (dlex.isStringLiteral(toks.front.type)) {
					output.put("$(D_STRING ");
					output.put(toks.front.text);
					output.put(")");
				} else if (toks.front == dlex.tok!"comment") {
					output.put("$(D_COMMENT ");
					output.put(toks.front.text);
					output.put(")");
				} else if (dlex.isKeyword(toks.front.type) || dlex.isBasicType(toks.front.type)) {
					output.put("$(D_KEYWORD ");
					output.put(dlex.str(toks.front.type));
					output.put(")");
				} else if (toks.front.text.length) {
					output.put(toks.front.text);
				} else {
					output.put(dlex.str(toks.front.type));
				}
				toks.popFront();
			}
			output.put(")");
			start = lex.offset;
			lex.popFront();
		}
		end = lex.offset;
		lex.popFront();
	}
	if (start)
		output.put(lex.text[start .. end]);
	return start ? output.data : str;
}

///
unittest {
	import ddoc.lexer;
	
	auto s1 = `Here is some embedded D code I'd like to show you:
$(MY_D_CODE
------
// Entry point...
void main() {
  import std.stdio : writeln;
  writeln("Hello,", " ", "world", "!");
}
------
)
Isn't it pretty ?`;
	// Embedded code is surrounded by D_CODE macro, and tokens have their own
	// macros (see: D_KEYWORD for example).
	auto r1 = highlight(s1);
	auto e1 = `Here is some embedded D code I'd like to show you:
$(MY_D_CODE
$(D_CODE $(D_COMMENT // Entry point...)
$(D_KEYWORD void) main() {
  $(D_KEYWORD import) std.stdio : writeln;
  writeln($(D_STRING "Hello,"), $(D_STRING " "), $(D_STRING "world"), $(D_STRING "!"));
})
)
Isn't it pretty ?`;
	assert(r1 == e1, r1);

	// No allocation is performed if the string doesn't contain inline code.
	auto s2 = `This is some simple string
--
It doesn't do much
--
Hope you won't allocate`;
	auto r2 = highlight(s2);
	assert(r2 is s2, r2);
}

// Test multiple embedded code.
unittest {
	auto s1 = `----
void main() {}
----
----
int a = 42;
----
---
unittest {
    assert(42, "Life, universe, stuff");
}
---`;
	auto e1 = `$(D_CODE $(D_KEYWORD void) main() {})
$(D_CODE $(D_KEYWORD int) a = 42;)
$(D_CODE $(D_KEYWORD unittest) {
    $(D_KEYWORD assert)(42, $(D_STRING "Life, universe, stuff"));
})`;
	auto r1 = highlight(s1);
	assert(r1 == e1, r1);
}
