# Soapex

[![Travis build](https://api.travis-ci.org/zdeneksejcek/soapex.svg?branch=master
"Build Status")](https://api.travis-ci.org/zdeneksejcek/soapex.svg?branch=master)

## Introduction
This library offers implementation of SOAP1.1 and SOAP1.2 client. It downloads WSDL ang generates proxy module.

## Progress
- [x] WSDL parser
- [x] XSD parser
- [x] proxy generator
- [ ] data validation
- [ ] tests

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `soapex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:soapex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/soapex](https://hexdocs.pm/soapex).

