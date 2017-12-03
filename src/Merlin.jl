module Merlin

using Base.LinAlg.BLAS
using JLD2

if is_windows()
    const libmerlin = Libdl.dlopen(joinpath(dirname(@__FILE__),"../deps/libmerlin.dll"))
elseif is_linux() || is_apple()
    const libmerlin = Libdl.dlopen(joinpath(dirname(@__FILE__),"../deps/libmerlin.so"))
else
    throw("Unsupported OS.")
end

#=
if haskey(ENV,"USE_CUDA") && ENV["USE_CUDA"]
    using CUJulia
    include("cuda/cudnn/CUDNN.jl")
    using .CUDNN
else
    type CuArray{T,N}; end
    CuVector{T} = CuArray{T,1}
    CuMatrix{T} = CuArray{T,2}
end
=#

struct SizeException <: Exception
    message::String
end

#include("hdf5.jl")
include("graph.jl")
include("var.jl")
#include("native.jl")
include("check.jl")

include("initializers/fill.jl")
include("initializers/normal.jl")
include("initializers/orthogonal.jl")
include("initializers/uniform.jl")
include("initializers/xavier.jl")

include("optimizers/adagrad.jl")
include("optimizers/adam.jl")
include("optimizers/sgd.jl")

for name in [
    "attention/add_attention",

    "conv/conv1d",
    "conv/gated_conv1d",

    "random/dropout",
    
    "pairwise",
    "split",
    "standardize"
    ]
    include("functions/$(name).jl")
    #isfile(joinpath(dirname(@__FILE__),cudafile)) && include(cudafile)
end
include("functions/activation.jl")
include("functions/argmax.jl")
include("functions/batchsort.jl")
include("functions/concat.jl")
include("functions/embeddings.jl")
include("functions/getindex.jl")
include("functions/linear.jl")
include("functions/loss.jl")
include("functions/math.jl")
include("functions/recurrent.jl")
include("functions/reduce.jl")
include("functions/reshape.jl")
include("functions/softmax.jl")

include("datasets/Datasets.jl")
#include("caffe/Caffe.jl")

#info("#Threads: $(Threads.nthreads())")

end
