# CλaSH - A functional hardware description language

[![Build Status](https://travis-ci.org/clash-lang/clash-prelude.svg?branch=0.10)](https://travis-ci.org/clash-lang/clash-prelude?branch=0.10)
[![Hackage](https://img.shields.io/hackage/v/clash-prelude.svg)](https://hackage.haskell.org/package/clash-prelude)
[![Hackage Dependencies](https://img.shields.io/hackage-deps/v/clash-prelude.svg?style=flat)](http://packdeps.haskellers.com/feed?needle=exact%3Aclash-prelude)

__WARNING__
Only works with GHC-7.10.* (http://www.haskell.org/ghc/download_ghc_7_10_3)!

CλaSH (pronounced ‘clash’) is a functional hardware description language that
borrows both its syntax and semantics from the functional programming language
Haskell. The CλaSH compiler transforms these high-level descriptions to
low-level synthesizable VHDL, Verilog, or SystemVerilog.

Features of CλaSH:

  * Strongly typed (like VHDL), yet with a very high degree of type inference,
    enabling both safe and fast prototying using consise descriptions (like
    Verilog).

  * Interactive REPL: load your designs in an interpreter and easily test all
    your component without needing to setup a test bench.

  * Higher-order functions, with type inference, result in designs that are
    fully parametric by default.

  * Synchronous sequential circuit design based on streams of values, called
    `Signal`s, lead to natural descriptions of feedback loops.

  * Support for multiple clock domains, with type safe clock domain crossing.

# Support
For updates and questions join the mailing list
clash-language+subscribe@googlegroups.com or read the
[forum](https://groups.google.com/d/forum/clash-language)
