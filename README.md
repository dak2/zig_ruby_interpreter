# Zig Ruby Interpreter

A minimal Ruby interpreter written in Zig that can parse and execute basic Ruby code (work in progress).

## Overview

This project implements a simple Ruby language interpreter in the Zig programming language. It includes a lexer, parser, and evaluator to process and run Ruby code.

⚠️ **Note: This is an incomplete, experimental project under active development.**

Features:
- Basic Ruby syntax parsing
- Support for numeric calculations and expressions
- Variable assignment and retrieval
- Function definitions and calls
- REPL (Read-Eval-Print Loop) interface
- WebAssembly build option for browser execution (in development)

## Components

- **Lexer** (`lexer.zig`): Tokenizes the Ruby source code into a stream of tokens
- **Parser** (`parser.zig`): Converts tokens into an Abstract Syntax Tree (AST)
- **AST** (`ast.zig`): Defines the structure for representing Ruby code
- **Evaluator** (`evaluator.zig`): Executes the AST to produce results
- **REPL** (`main.zig`): Interactive command-line interface

## Current Status

This interpreter is currently a work in progress. Here's what's working:
- Basic arithmetic operations
- Variable assignments
- Simple function definitions and calls
- REPL interface

What's being worked on:
- Improving function call handling
- WebAssembly compilation support
- Better error reporting
- More language features

## Getting Started

### Prerequisites

- Zig compiler (tested with version 0.13.0)

### Building

```bash
# Build the CLI REPL
zig build-exe src/main.zig

# Run the interpreter
./main
```

## Usage

### CLI REPL

Run the interpreter and enter Ruby code:

```
ruby> def add(x, y)
ruby:1> x + y
ruby:2> end
=> <function: add>
ruby> add(3, 4)
=> 7
```

## License

This repo is available as open source under the terms of the [MIT License](https://opensource.org/license/MIT).

