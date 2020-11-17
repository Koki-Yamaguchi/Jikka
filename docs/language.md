# Language Specification

## Lexical Analysis

This is the almost same to Python.


## Syntax

```bnf
<program> ::= <toplevel-decl>+

# types
<type> ::= "int"
         | "nat"
         | "bool"
         | "Interval" "[" <expr>, <expr> "]"
         | "List" "[" <type> "]"
         | "Array" "[" <type> "," <expr> "]"

# literals
<int-literal> ::= ...
<bool-literal> ::= "True" | "False"
<none-literal> ::= "None"
<list-literal> ::= "[" "]"
                 | "[" <expr> "for" <var> "in" <expr> "]"
                 | "[" <expr> "for" <var> "in" <expr> "if" <expr> "]"
<literal> ::= <int-literal>
            | <bool-literal>
            | <none-literal>
            | <list-literal>

# exprs
<var> ::= ...
<atom> ::= <var>
         | <literal>
         | "(" <expr> ")"
<expr> ::= <atom>
         | <unary-op> <atom>
         | <atom> <binary-op> <atom>
         | <atom> "[" <expr> "]"
         | <var> "(" <actual-args> ")"
         | <expr> "if" <expr> "else" <expr>
<unary-op> ::= ...
<binary-op> ::= ...
<actual-args> ::= EMPTY
                | <expr> ("," <expr>)*

# simple statements
<simple-stmt> ::= <var> ":" <type> "=" <expr>
                | <var> "=" <expr>
                | "assert" <expr>
                | "return" <expr>

# compound statements
<compound-stmt> ::= <if-stmt>
<if-stmt> ::= "if" <expr> ":" <suite>
              ("elif" <expr> ":" <suite>)*
              "else" <expr> ":" <suite>
<for-stmt> ::= "for" <expr> "in" <expr> ":" <suite>

# statements
<suite> ::= NEWLINE INDENT <statement>+ DEDENT
<statement> ::= <simple-statement>
              | <compound-statement>

# toplevel declarations
<compat-import> ::= "from" "jikka" "." "compat" "import" "*"
                  | "from" "math" "import" "*"
<function-decl> ::= "def" <var> "(" <formal-args> ")" ":" <suite>
<toplevel-decl> ::= <compat-import> NEWLINE
                  | <assignment-stmt> NEWLINE
                  | <function-decl>
```

## Semantics

### Python compatibility

This language is compatible with Python.
This means that, if the execution successfully stops on both interpreter of this language and Python, the result is the same.

### types

-   `int` type represents the set of integers.
-   `nat` type represents the set of natural numbers.
    -   `nat` is not a standard type of Python.
    -   `nat` is a subclass of `int`.
    -   `0` is a natural number.
-   `bool` type represents the set of truth values. It has two values `True` and `False`.
-   For integers `l` and `r` which `l <= r` holds, `Interval[l, r]` type represents the closed interval `[l, r]`.
    -   `Interval[l, r]` is a subclass of `int`.
    -   `Interval[l, r]` is a subclass of `nat` when `l >= 0`.
    -   `r` is included.
-   For any type `T`, `List[T]` type represents the set of finite sequences of values in `T`. They are immutable.
-   For any type `T` and an integer `n`, `Array[T, n]` type represents the set of sequences of values in `T` with the length `n`. They are immutable.
    -   `Array[T, n]` is not a standard type of Python.
    -   `Array[T, n]` is a subclass of `List[T]`.

### single assignment

The keyword `None` is just a placeholder.
It's not a value.

The behavior is undefined when a variable without value (i.e. in `None`) is used as an argument of a function call or an operation. However, if possible, the compiler should detect it and stop as a compiler error.


## Standard Library

### builtin operators

unary op on `int`:

-   `-` negation
-   `~` bitwise-not

binary ops on `int`:

-   `+` addition
-   `-` subtraction
-   `*` multiplication
-   `//` division (floor, consistent to `%`)
    -   It means `(x // y) * y + (x % y) == x` always holds.
-   `%` modulo (always positive)
-   `**` power
-   `&` bitwise-and
-   `|` bitwise-or
-   `^` bitwise-xor
-   `<<` left shift
-   `>>` right shift

binary relation on `int`:

-   `<` less-than
    -   Please note that combinational notations like `a < b < c` are not supported.
-   `>` greater-than
-   `<=` less-or-equal
-   `>=` greater-or-equal

unary op on `bool`:

-   `not` not

binary ops on `bool`:

-   `and` and
-   `or` or

ternary ops on arbitrary types (`forall a. Bool -> a -> a -> a`):

-   `... if ... else ...`

binary relation on arbitrary types (`forall a. a -> a -> Bool`):

-   `==` equal
    -   Please note that combinational notations like `a == b == c` are not supported.
-   `!=` not-equal


### additional builtin operators

WARNING: these ops breaks compatibility with Python. `from jikka.compat import *` disables them.

binary ops on `int`:

-   `/^` division (ceil)
    -   same to `(x + y - 1) // y`
    -   TODO: is this definition appropriate for negative numbers?
-   `<?` min
    -   comes from [old GCC](https://gcc.gnu.org/onlinedocs/gcc-3.3.2/gcc/Min-and-Max.html)
-   `>?` max
    -   comes from [old GCC](https://gcc.gnu.org/onlinedocs/gcc-3.3.2/gcc/Min-and-Max.html)


### builtin small functions

From the default Python:

-   `abs(x: int) -> nat`
-   `min(x: int, y: int) -> int`
-   `max(x: int, y: int) -> int`
-   `pow(x: int, y: int) -> int`
-   `pow(x: int, y: int, mod: nat) -> nat`
    -   WARNING: negative exp is allowed from Python 3.8
    -   `mod` must be positive
-   `len(xs: List[T]) -> nat`

Not from the default Python:

-   `gcd(x: int, y: int) -> int`
    -   If you want, you can write `from math import *` before using this.
-   `lcm(x: int, y: int) -> int`
    -   If you want, you can write `from math import *` before using this.
    -   WARNING: this is defined from Python 3.9
-   `floordiv(x: int, y: int) -> int`
    -   same to `x // y`
-   `ceildiv(x: int, y: int) -> int`
    -   same to `(x + y - 1) // y`
    -   TODO: is this definition appropriate for negative numbers?
-   `fact(x: nat) -> nat`
-   `choose(n: nat, r: nat): nat`
    -   `n >= r` must be holds
-   `permute(n: nat, r: nat) -> nat`
    -   `n >= r` must be holds
-   `multichoose(n: nat, r: nat) -> nat`
    -   `n >= r` must be holds
-   `inv(x: int, mod: nat) -> nat`
    -   `x` must not be a multiple of `mod`
    -   `mod` must be positive


### builtin big functions

From the default Python:

-   `sum(xs: List[int]) -> int`
-   `min(xs: List[int]) -> int`
    -   `xs` must be non empty
-   `max(xs: List[int]) -> int`
    -   `xs` must be non empty
-   `all(xs: List[bool]) -> bool`
-   `any(xs: List[bool]) -> bool`
-   `sorted(xs: List[int]) -> List[int]`

Not from the default Python:

-   `product(xs: List[int]) -> int`
-   `argmin(xs: List[int]) -> nat`
    -   `xs` must be non empty
-   `argmax(xs: List[int]) -> nat`
    -   `xs` must be non empty