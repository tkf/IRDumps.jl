struct IRDump
    id::Int
    var"function"::Union{String,Nothing}
    pass::Union{String,Nothing}
    code::String
end

struct IRCollection <: AbstractVector{IRDump}
    var"function"::Union{String,Nothing}
    dumps::Vector{IRDump}
end

const FunctionCollectionDict = Dict{Union{String,Nothing},IRCollection}

struct FunctionCollection <: AbstractDict{String,IRCollection}
    dumps::FunctionCollectionDict
    nirs::typeof(Ref(0))
end

FunctionCollection() = FunctionCollection(FunctionCollectionDict(), Ref(0))

Base.getindex(irs::IRCollection, i::Int) = irs.dumps[i]
Base.size(irs::IRCollection) = size(irs.dumps)

Base.length(fns::FunctionCollection) = length(fns.dumps)
Base.keys(fns::FunctionCollection) = keys(fns.dumps)
Base.values(fns::FunctionCollection) = values(fns.dumps)
Base.getindex(fns::FunctionCollection, name::AbstractString) = fns.dumps[name]

function Base.getindex(fns::FunctionCollection, pattern::AbstractPattern)
    dumps = FunctionCollectionDict()
    nirs = 0
    for irs in values(fns)
        irs.function === nothing && continue
        if match(pattern, irs.function) !== nothing
            dumps[irs.function] = irs
            nirs += length(irs)
        end
    end
    return FunctionCollection(dumps, Ref(nirs))
end

function Base.push!(fns::FunctionCollection, ir::IRDump)
    irs = get!(fns.dumps, ir.function) do
        IRCollection(ir.function, IRDump[])
    end::IRCollection
    push!(irs.dumps, ir)
    fns.nirs[] += 1
    return fns
end

function Base.iterate(it::Union{FunctionCollection,IRCollection}, state = iterate(it.dumps))
    state === nothing && return nothing
    item, istate = state
    return (item, iterate(it.dumps, istate))
end

# function Base.summary(io::IO, irs::IRCollection)
#     print(io, "Collection of ", length(irs.dumps), " IRs")
# end

# function Base.show(io::IO, ::MIME"text/plain", irs::IRCollection)
#     summary(io, irs)
# end

# function Base.summary(io::IO, irs::FunctionCollection)
#     print(io, "Collection of ", length(irs.dumps), " functions and ", irs.nirs[], " IRs")
# end

# function Base.show(io::IO, ::MIME"text/plain", irs::FunctionCollection)
#     summary(io, irs)
# end

function Base.summary(io::IO, ir::IRDump)
    print(io, "*** IR Dump of ")
    printstyled(io, something(ir.function, "UNKNOWN FUNCTION"); color = :blue, bold = true)
    print(io, " After ")
    printstyled(io, something(ir.pass, "UNKNOWN PASS"); color = :blue, bold = true)
    print(io, " ***")
end

Base.print(ir::IRDump; options...) = print(stdout, ir; options...)
function Base.print(io::IO, ir::IRDump; raw::Bool = true, dump_module::Bool = true)
    summary(io, ir)
    println(io)
    code = stripoff_passname(ir.code)
    if !dump_module
        code = extract_function(code)
    end
    if !raw
        code = cleanup_ir(code)
    end
    print_llvm(io, code)
end

function Base.show(io::IO, ::MIME"text/plain", ir::IRDump)
    print(io, ir; raw = false, dump_module = false)
end
