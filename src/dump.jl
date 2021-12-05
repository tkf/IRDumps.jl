"""
    IRDumps.dump(code::AbstractString; options = ``) -> irs
    IRDumps.dump(cmd::AbstractCmd) -> irs
    IRDumps.parsefile(filepath) -> irs
    IRDumps.parse(io::IO) -> irs

`irs` is an `AbstractDict{String,<:AbstractVector{IRDump}}` where each `IRDump`
is an object with the following fields:

* `function::Union{String,Nothing}`: LLVM-level name of the function
* `pass::Union{String,Nothing}`: LLVM pass name
* `code::String`: LLVM IR
"""
(IRDumps.dump, IRDumps.parse, IRDumps.parsefile)

function IRDumps.dump(code::AbstractString; options = ``)
    cmd = Base.julia_cmd()
    cmd = `$cmd -e 'include_string(Main, read(stdin, String))' $options`
    input = IOBuffer(code)
    return _dump(cmd, input)
end

function IRDumps.dump(cmd::Base.AbstractCmd)
    return _dump(cmd, devnull)
end

_dump(cmd, input) = _dumpwith(IRDumps.parse, cmd, input)

function _dumpwith(f, cmd, input, stdout′ = stderr)
    ipipe = Pipe()
    epipe = Pipe()
    cmd = addenv(cmd, "JULIA_LLVM_ARGS" => "-print-after-all")
    cmd = pipeline(cmd; stdout = stdout′, stderr = epipe, stdin = ipipe)
    proc = run(cmd; wait = false)
    close(epipe.in)
    @sync begin
        @async try
            write(ipipe, input)
        catch
            close(epipe)
        finally
            close(ipipe)
        end
        ans = try
            f(epipe)
        finally
            close(ipipe)
            close(epipe)
        end
        wait(proc)
        return ans
    end
end
