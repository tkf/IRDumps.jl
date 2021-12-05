baremodule IRDumps

function tofiles end
function dump end
function parse end
function parsefile end

module Internal

using ..IRDumps: IRDumps

import InteractiveUtils
using ArgCheck: @argcheck

const HAS_PRINT_LLVM = try
    InteractiveUtils.print_llvm(devnull, "")
    true
catch
    false
end

if HAS_PRINT_LLVM
    using InteractiveUtils: print_llvm
else
    const print_llvm = print
end

include("collection.jl")
include("parse.jl")
include("split.jl")
include("dump.jl")

end  # module Internal

end  # baremodule IRDumps
