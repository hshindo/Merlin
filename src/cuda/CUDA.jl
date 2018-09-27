module CUDA

using Libdl
using Base.Threads
import LinearAlgebra.BLAS: scal!, axpy!, gemv, gemv!, gemm, gemm!

if Sys.iswindows()
    const libcuda = Libdl.find_library("nvcuda")
else
    const libcuda = Libdl.find_library("libcuda")
end
const AVAILABLE = !isempty(libcuda)
AVAILABLE || @warn "CUDA cannot be found."
const API_VERSION = Ref{Int}()

function checkstatus(status)
    if status != 0
        ref = Ref{Cstring}()
        ccall((:cuGetErrorString,libcuda), Cint, (Cint,Ptr{Cstring}), status, ref)
        throw(unsafe_string(ref[]))
    end
end

if AVAILABLE
    status = ccall((:cuInit,libcuda), Cint, (Cint,), 0)
    checkstatus(status)

    ref = Ref{Cint}()
    status = ccall((:cuDriverGetVersion,libcuda), Cint, (Ptr{Cint},), ref)
    checkstatus(status)

    API_VERSION[] = Int(ref[])
    @info "CUDA API $(API_VERSION[])"
end

include("define.jl")

macro apicall(f, args...)
    f = get(DEFINE, f.value, f.value)
    quote
        status = ccall(($(QuoteNode(f)),libcuda), Cint, $(map(esc,args)...))
        checkstatus(status)
    end
end

macro unsafe_apicall(f, args...)
    f = get(DEFINE, f.value, f.value)
    quote
        ccall(($(QuoteNode(f)),libcuda), Cint, $(map(esc,args)...))
    end
end

export cstring
cstring(::Type{Int32}) = "int"
cstring(::Type{Float32}) = "float"

include("driver/device.jl")
include("driver/context.jl")
include("driver/stream.jl")
include("driver/pointer.jl")
include("driver/module.jl")
include("driver/function.jl")

include("allocators/atomic_malloc.jl")
include("allocators/cuda_malloc.jl")
include("allocators/malloc.jl")

if AVAILABLE
    const CONTEXTS = Array{CuContext}(undef, ndevices())
    # This must be loaded before kernel.jl and kernels.jl
    include("nvml/NVML.jl")
    include("nvrtc/NVRTC.jl")
    using .NVML
end

include("array.jl")
include("subarray.jl")
include("kernel.jl")
include("arraymath.jl")
include("broadcast.jl")
include("cat.jl")
include("reduce.jl")
include("devicearray.jl")

if AVAILABLE
    include("nccl/NCCL.jl")
    include("cublas/CUBLAS.jl")
    include("cudnn/CUDNN.jl")

    using .CUBLAS, .CUDNN
    export CUBLAS, CUDNN
end

end
