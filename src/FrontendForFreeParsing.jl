module FrontendForFreeParsing

"""
    requirement(::Val{YourLangName}, ::Val{RequiredValueName}) = val
"""
function requirement end

const _MSG_NO_BIN = raw"""
Calling 'fff-pgen' failed.
The required binaries are available at:
    https://github.com/thautwarm/frontend-for-free/releases/

You might need to install or build the binaries (and add them to PATH)
"""

const _MSG_CMD_FAILED = raw"""
It seems that you have installed a wrong version of 'fff-pgen'.
Please check the documentations for compatibility issues, or send a bug report.
"""

function load_fff_impl(caller_module::Module, dirpath::String, sourcepath::String, line::Int, langName::Symbol)
    jl_path = string(langName) * ".fff_parser.jl" # generated julia source path
    abs_jl_path = joinpath(dirpath, jl_path)
    fff_path = joinpath(dirpath, string(langName) * ".fff")
    if !isfile(abs_jl_path)
        try
            cmd = ``
            push!(
                cmd.exec,
                "fff-pgen",
                "-in", fff_path,
                "-k", "1",
                "-out", abs_jl_path,
                "-be", "julia",
                "--trace",
                "--noinline"
            )
            run(cmd)
            !isfile(abs_jl_path) && throw(LoadError(sourcepath, line, ErrorException(_MSG_CMD_FAILED)))
        catch e
            e isa Base.IOError && throw(LoadError(sourcepath, line, ErrorException(_error_msg)))
            e isa Base.ProcessFailedException && throw(LoadError(sourcepath, line, ErrorException(_MSG_CMD_FAILED)))
            @warn e
            rethrow()
        end
    end
    :(include($jl_path))
end

"""
https://github.com/thautwarm/frontend-for-free
Load code generated by fff-pgen.
"""
macro load_fff!(langName::Symbol)
    sourcepath = string(__source__.file)
    dirpath = string(dirname(abspath(sourcepath)))
    esc(load_fff_impl(__module__, dirpath, sourcepath, __source__.line, langName))
end

abstract type AbstractUnionCase end
abstract type AbstractForwardRef end

function Base.show(io::IO, x::T) where T <: AbstractUnionCase
    names = fieldnames(T)
    if length(names) == 1 && (fr = getfield(x, names[1])) isa AbstractForwardRef
        names = propertynames(fr)
    end
    print(io, T)
    print(io, "(")
    print(io, join([repr(getproperty(x, n)) for n in names], ", "))
    print(io, ")")
end


module Runtime
    export Tokens
    mutable struct Tokens{Token}
        array :: Vector{Token}
        offset :: Int
    end

    export True, False
    const True = true
    const False = false

    export builtin_not_eq
    export builtin_eq

    builtin_not_eq(a, b) = a != b
    builtin_eq(a, b) = a == b

    export builtin_mv_forward

    function builtin_mv_forward(tokens::Tokens)
        new_off = tokens.offset + 1
        cur_token = tokens.array[new_off]
        tokens.offset = new_off
        return cur_token
    end

    export builtin_peek
    function builtin_peek(tokens::Tokens, i::Integer)
        return tokens.array[tokens.offset + i + 1]
    end

    export builtin_peekable
    function builtin_peekable(tokens::Tokens, i::Integer)
        tokens.offset + i < length(tokens.array)
    end

    export builtin_is_not_null, builtin_is_null
    """
    only to check token matching
    """
    function builtin_is_null(x)
        x === nothing
    end

    function builtin_is_not_null(x)
        x !== nothing
    end

    export builtin_match_tk

    function builtin_match_tk(tokens::Tokens, idint::Integer)
        offset??? = tokens.offset + 1
        if offset??? <= length(tokens.array)
            tk = tokens.array[offset???]
            if tk.idint == idint
                tokens.offset = offset???
                return tk
            else
                return nothing
            end
        else
            return nothing
        end
    end

    struct WrapErrorListNil end
    mutable struct WrapErrorListCons
        head :: Tuple{Int, String}
        tail :: Union{WrapErrorListCons, WrapErrorListNil}
    end

    const WrapErrorList = Union{WrapErrorListCons, WrapErrorListNil}

    struct WrapError
        errors::WrapErrorList
    end

    # struct MarkedValue{T}
    #     value::T
    # end

    export builtin_mk_either_left, builtin_mk_either_right, builtin_chk_is_err, builtin_chk_is_val
    builtin_mk_either_left(x) = x
    @noinline builtin_mk_either_right(x::WrapError) = x
    builtin_chk_is_err(x) = x isa WrapError
    builtin_chk_is_val(x) = !(x isa WrapError)

    export builtin_to_any, builtin_to_result
    """
    used for wrapping exceptions
    """
    @noinline function builtin_to_any(x::WrapErrorList)
        return WrapError(x)
    end

    @noinline function builtin_to_any(x)
        return error("wrap error list")
    end

    function builtin_to_result(x::WrapErrorList)
        error("fatal: invalid call to builtin_to_result")
    end

    function builtin_to_result(x) # ::MarkedValue)
        return x # .value
    end

    export builtin_nil, builtin_cons
    const builtin_nil = WrapErrorListNil()
    @noinline builtin_cons(a::Tuple{Int, String}, b::WrapErrorList) = WrapErrorListCons(a, b)

end

function collect_errors(x)
    Tuple{Int, String}[]
end

function collect_errors(wrap_error::Runtime.WrapError)
    xs = Tuple{Int, String}[]
    x = wrap_error.errors
    while x isa Runtime.WrapErrorListCons
        push!(x, x.head)
        x = x.tail
    end
    return xs
end

const WrapError = Runtime.WrapError

end