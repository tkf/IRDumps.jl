"""
    IRDumps.tofiles(outputdir, dumpfile; clean = true)

Split `dumpfile` that contains the stderr of `JULIA_LLVM_ARGS='-print-after-all'
julia`) into multiple files in a directory `outputdir`.  It empties `outputdir`
first if `clean = true` (default).
"""
function IRDumps.tofiles(outputdir, dumpfile; clean = true)
    @argcheck isfile(dumpfile)
    if clean
        @argcheck !isfile(outputdir)
        if isdir(outputdir)
            rm(outputdir, recursive = true)
        end
    end
    mkpath(outputdir)
    open(dumpfile) do input
        counter = Ref(0)
        foreachdump(input) do foreachline
            tmppath = joinpath(outputdir, "_tmp.ll")
            name = open(tmppath, write = true) do output
                foreachline() do ln
                    print(output, ln)
                end
            end
            filename = string(counter[]; pad = 5) * "-" * asfilename(name) * ".ll"
            mv(tmppath, joinpath(outputdir, filename))
            counter[] += 1
        end
    end
end
