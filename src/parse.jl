"""
    foreachdump(processdump, input::IO)

`processdump` is a function with the following signature

    processdump(processir)

where `processir` is a function with the following signature

    processir(processline) -> name::AbstractString

where `name` is the LLVM level name of the function and `processline` is a
function with the following signature

    processline(line::AbstractString)

which is called for each `line` of the IR.
"""
function foreachdump(processdump, input::IO)
    firstline = Ref{String}()
    while true
        line = readline(input; keep = true)
        if startswith(line, "*** ")
            firstline[] = line
            break
        end
        @warn "Ignoreing:" line
        eof(input) && return
    end
    while true
        processdump() do processline
            processline(firstline[])
            name = nothing
            while true
                line = readline(input; keep = true)
                if name === nothing
                    name = parsename(line)
                end
                if startswith(line, "*** ")
                    firstline[] = line
                    break
                end
                processline(line)
                eof(input) && break
            end
            return name
        end
        eof(input) && return
    end
end

function parsename(line)
    m = match(r"^define .*@([^(]+)", line)
    m === nothing && return nothing
    return m[1]
end

asfilename(::Nothing) = "UNKNOWN"
function asfilename(name::AbstractString)
    name = replace(name, r"^[^a-zA-Z0-9]+" => "")
    name = replace(name, r"[^a-zA-Z0-9]+$" => "")
    name = replace(name, r"[^a-zA-Z0-9]+" => "_")
    return name
end

function tryparse_passname_line(ln::AbstractString)
    m = match(r"^\*\*\* IR Dump After (.*) \*\*\*", ln)
    if m !== nothing
        return m[1]
    end
    return nothing
end

function passof(code::AbstractString)
    for line in eachline(IOBuffer(code))
        name = tryparse_passname_line(line)
        name === nothing || return name
    end
    return nothing
end

stripoff_passname(code::AbstractString) = stripoff_passname(IOBuffer(code))
function stripoff_passname(input::IO)
    output = IOBuffer()
    for line in eachline(input; keep = true)
        if tryparse_passname_line(line) === nothing
            print(output, line)
        end
    end
    return String(take!(output))
end

extract_function(code::AbstractString) = extract_function(IOBuffer(code))
function extract_function(input::IO)
    output = IOBuffer()
    while !eof(input)
        line = readline(input; keep = true)
        if parsename(line) !== nothing
            print(output, line)
            break
        end
    end
    while !eof(input)
        line = readline(input; keep = true)
        print(output, line)
        if match(r"^}\s*$", line) !== nothing
            break
        end
    end
    return String(take!(output))
end

cleanup_ir_line(line::AbstractString) = replace(line, r" *addrspace\([0-9]+\)" => "")

# TODO: Use `opt`
cleanup_ir(code::AbstractString) = cleanup_ir(IOBuffer(code))
function cleanup_ir(input::IO)
    output = IOBuffer()
    for line in eachline(input; keep = true)

        addrspacecast = match(r"^( *%[^ ]* += *)addrspacecast .*(%[^ ]*) +", line)
        if addrspacecast !== nothing
            print(output, addrspacecast[1], addrspacecast[2])
            print(output, " ; ", line)
            continue
        end

        print(output, cleanup_ir_line(line))
    end
    return String(take!(output))
end

IRDumps.parsefile(filepath) = open(IRDumps.parse, filepath)
function IRDumps.parse(io::IO)
    irs = FunctionCollection()
    counter = Ref(0)
    buffer = IOBuffer()
    foreachdump(io) do foreachline
        fnname = foreachline() do ln
            write(buffer, ln)
        end
        code = String(take!(buffer))
        id = counter[] += 1
        ir = IRDump(id, fnname, passof(code), code)
        push!(irs, ir)
    end
    return irs
end
