# cudnnRNNMode_t
const CUDNN_RNN_RELU = Cint(0)
const CUDNN_RNN_TANH = Cint(1)
const CUDNN_LSTM = Cint(2)
const CUDNN_GRU = Cint(3)

# cudnnDirectionMode_t
const CUDNN_UNIDIRECTIONAL = Cint(0)
const CUDNN_BIDIRECTIONAL = Cint(1)

# cudnnRNNInputMode_t
const CUDNN_LINEAR_INPUT = Cint(0)
const CUDNN_SKIP_INPUT = Cint(1)

# cudnnRNNAlgo_t
const CUDNN_RNN_ALGO_STANDARD = Cint(0)
const CUDNN_RNN_ALGO_PERSIST_STATIC = Cint(1)
const CUDNN_RNN_ALGO_PERSIST_DYNAMIC = Cint(2)

# cudnnRNNClipMode_t
const CUDNN_RNN_CLIP_NONE = 0
const CUDNN_RNN_CLIP_MINMAX = 1

# cudnnRNNPaddingMode_t
const CUDNN_RNN_PADDED_IO_DISABLED = 0
const CUDNN_RNN_PADDED_IO_ENABLED = 1

mutable struct RNNDesc
    ptr::Cptr
    direction

    function RNNDesc(::Type{T}, hsize::Int, nlayers::Int, droprate::Float64, direction::Cint, mode::Cint) where T
        ref = Ref{Cptr}()
        @cudnn :cudnnCreateRNNDescriptor (Ptr{Cptr},) ref
        desc = new(ref[], direction)

        h = gethandle()
        dropdesc = DropoutDesc(droprate)
        algo = CUDNN_RNN_ALGO_STANDARD
        @cudnn(:cudnnSetRNNDescriptor,
            (Cptr,Cptr,Cint,Cint,Cptr,Cint,Cint,Cint,Cint,Cint),
            h, desc, hsize, nlayers, dropdesc, CUDNN_LINEAR_INPUT, direction, mode, algo, datatype(T))

        finalizer(desc) do x
            @cudnn :cudnnDestroyRNNDescriptor (Cptr,) x.ptr
        end
        desc
    end
end

Base.cconvert(::Type{Cptr}, desc::RNNDesc) = desc.ptr

function getworkspace(rnndesc, seqlength, xdesc)
    h = gethandle()
    ref = Ref{Csize_t}()
    @cudnn(:cudnnGetRNNWorkspaceSize,
        (Cptr,Cptr,Cint,Ptr{Cptr},Ptr{Csize_t}),
        h, rnndesc, seqlength, xdesc, ref)
    CuArray{UInt8}(Int(ref[]))
end

const DICT_RNNDesc = Dict()

function rnn(insize::Int, hsize::Int, nlayers::Int, droprate::Float64, direction::Cint, mode::Cint,
    x::CuArray{T}, batchdims::Vector{Int}, hx::CuArray{T}, cx::CuArray{T}, w::CuArray{T}, train::Bool) where T

    h = gethandle()
    @assert insize == size(x,1)
    rnndesc = get!(DICT_RNNDesc, (h,T,hsize,nlayers,droprate,direction,mode)) do
        RNNDesc(T, hsize, nlayers, droprate, direction, mode)
    end
    seqlength = length(batchdims)
    wdesc = FilterDesc(T, 1, 1, length(w))

    # x: (1,X,B,T) where X = inputSize, B = miniBatch, T = seqLength
    # xdesc: Array of T (1,X,B) descriptors
    xdesc = map(batchdims) do d
        TensorDesc(T, 1, insize, d)
    end

    # hx,cx,hy,cy: (H,B,L) where H = hidden size, L = numLayers * (bidirectional ? 2 : 1)
    coef = direction == CUDNN_UNIDIRECTIONAL ? 1 : 2
    hxdesc = TensorDesc(T, hsize, batchdims[1], nlayers*coef)
    cxdesc = TensorDesc(T, hsize, batchdims[1], nlayers*coef)
    hy = similar(hx)
    cy = C_NULL

    # y: (1,Y,B,T) where Y = hiddenSize * (bidirectional ? 2 : 1)
    # ydesc: Array of T (1,Y,B) descriptors
    y = CuArray{T}(hsize*coef, sum(batchdims))
    ydesc = map(batchdims) do d
        TensorDesc(T, 1, hsize*coef, d)
    end

    workspace = getworkspace(rnndesc, seqlength, xdesc)
    if train
        ref = Ref{Csize_t}()
        @cudnn(:cudnnGetRNNTrainingReserveSize,
            (Cptr,Cptr,Cint,Ptr{Cptr},Ptr{Csize_t}),
            h, rnndesc, seqlength, xdesc, ref)
        reserve_space = CuArray{UInt8}(Int(ref[]))

        @cudnn(:cudnnRNNForwardTraining,
            (Cptr,Cptr,Cint,
            Ptr{Cptr},Cptr,     # x
            Cptr,Cptr,          # hx
            Cptr,Cptr,          # cx
            Cptr,Cptr,          # w
            Ptr{Cptr},Cptr,     # y
            Cptr,Cptr,          # hy
            Cptr,Cptr,          # cy
            Cptr,Csize_t,       # workspace
            Cptr,Csize_t),      # reserve_space
            h, rnndesc, seqlength,
            xdesc, x,
            hxdesc, hx,
            cxdesc, cx,
            wdesc, w,
            ydesc, y,
            hxdesc, hy,
            cxdesc, cy,
            workspace, length(workspace),
            reserve_space, length(reserve_space))
        work = rnndesc,x,hx,cx,w,y,seqlength,xdesc,hxdesc,cxdesc,wdesc,ydesc,reserve_space
        y, hy, work
    else
        @cudnn(:cudnnRNNForwardInference,
            (Cptr,Cptr,Cint,
            Ptr{Cptr},Cptr,     # x
            Cptr,Cptr,          # hx
            Cptr,Cptr,          # cx
            Cptr,Cptr,          # w
            Ptr{Cptr},Cptr,     # y
            Cptr,Cptr,          # hy
            Cptr,Cptr,          # cy
            Cptr,Csize_t),      # workspace
            h, rnndesc, seqlength,
            xdesc, x,
            hxdesc, hx,
            cxdesc, cx,
            wdesc, w,
            ydesc, y,
            hxdesc, hy,
            cxdesc, cy,
            workspace, length(workspace))
        y, hy, nothing
    end
end

function ∇rnn_data(dy::CuArray, dhy, work::Tuple)
    rnndesc,x,hx,cx,w,y,seqlength,xdesc,hxdesc,cxdesc,wdesc,ydesc,reserve_space = work
    coef = rnndesc.direction == CUDNN_UNIDIRECTIONAL ? 1 : 2

    h = gethandle()
    dx = similar(x)
    dhx = similar(hx)
    dcx = dcy = C_NULL
    workspace = getworkspace(rnndesc, seqlength, xdesc)
    @cudnn(:cudnnRNNBackwardData,
        (Cptr,Cptr,Cint,
        Ptr{Cptr},Cptr,     # y
        Ptr{Cptr},Cptr,     # dy
        Cptr,Cptr,  # dhy
        Cptr,Cptr,  # dcy
        Cptr,Cptr,  # w
        Cptr,Cptr,  # hx
        Cptr,Cptr,  # cx
        Ptr{Cptr},Cptr,  # dx
        Cptr,Cptr,  # dhx
        Cptr,Cptr,  # dcx
        Cptr,Csize_t,   # workspace
        Cptr,Csize_t),  # reserve_space
        h, rnndesc, seqlength,
        ydesc, y,
        ydesc, dy,
        hxdesc, dhy,
        cxdesc, dcy,
        wdesc, w,
        hxdesc, hx,
        cxdesc, cx,
        xdesc, dx,
        hxdesc, dhx,
        cxdesc, dcx,
        workspace, length(workspace),
        reserve_space, length(reserve_space))
    dx, dhx
end

function ∇rnn_weights!(dw::CuArray, work::Tuple)
    rnndesc,x,hx,cx,w,y,seqlength,xdesc,hxdesc,cxdesc,wdesc,ydesc,reserve_space = work

    h = gethandle()
    workspace = getworkspace(rnndesc, seqlength, xdesc)
    @cudnn(:cudnnRNNBackwardWeights,
        (Cptr,Cptr,Cint,
        Ptr{Cptr},Cptr,     # x
        Cptr,Cptr,          # hx
        Ptr{Cptr},Cptr,     # y
        Cptr,Csize_t,       # workspace
        Cptr,Cptr,          # dw
        Cptr,Csize_t),      # reserve_space
        h, rnndesc, seqlength,
        xdesc, x,
        hxdesc, hx,
        ydesc, y,
        workspace, length(workspace),
        wdesc, dw,
        reserve_space, length(reserve_space))
end

### Size chart (Julia sizes for CUDNN calls)
# Note: For Julia calls, x and y do not need the initial 1 dimension and B,T are optional.
#
# x: (1,X,B,T) where X = inputSize, B = miniBatch, T = seqLength
# xDesc: Array of T (1,X,B) descriptors
# y: (1,Y,B,T) where Y = hiddenSize * (bidirectional ? 2 : 1)
# yDesc: Array of T (1,Y,B) descriptors
# w: (1,1,W) where W = cudnnGetRNNParamsSize()
# hx,cx,hy,cy: (H,B,L) where H = hidden size, L = numLayers * (bidirectional ? 2 : 1)
#
# Note: cudnn docs say min tensor dims 4 but RNN_example.cu uses 3D tensors

function getRNNParamSize(::Type{T}, desc, xdesc) where T
    h = gethandle()
    ref = Ref{Csize_t}()
    @cudnn(:cudnnGetRNNParamsSize,
        (Cptr,Cptr,Cptr,Ptr{Csize_t},Cint),
        h, desc, xdesc, ref, datatype(T))
    println(Int(ref[]) ÷ sizeof(T))
end
