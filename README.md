# FrontendForFreeParsing

[![Build Status](https://github.com/thautwarm/FrontendForFreeParsing.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/thautwarm/FrontendForFreeParsing.jl/actions/workflows/CI.yml?query=branch%3Amain)


Runtime, and binary invocation wrapper for [frontend-for-free](https://github.com/thautwarm/frontend-for-free)'s Julia backend.

```julia
result = <parsed by FFF parser>
if result isa FrontendForFreeParsing.WrapError
    println(FrontendForFreeParsing.collect_errors(result))
end
```