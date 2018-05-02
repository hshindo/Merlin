export Var, param, zerograd!, isvoid, isparam, gradient!, topsort

doc"""
    Var

Variable struct.

`Var` contains the following members:
* data
* args
* grad

# Example
```julia
T = Float32
x = Var(rand(T,10,5)) # x.grad is set to `nothing`
x = zerograd(rand(T,10,5)) # x.grad is initialized as zero.
```
"""
mutable struct Var
    data
    args
    grad
end

Var(data=nothing, args=()) = Var(data, args, nothing)
param(data) = Var(data, (), zeros(data))

function zerograd!(x::Var)
    isvoid(x.grad) && throw("")
    fill!(x.grad, 0)
    x
end

Base.size(x::Var) = size(x.data)
Base.size(x::Var, i::Int) = size(x.data, i)
Base.length(x::Var) = length(x.data)
Base.ndims(x::Var) = ndims(x.data)
Base.eltype(x::Var) = eltype(x.data)
Base.strides(x::Var) = strides(x.data)
Base.stride(x::Var, i::Int) = stride(x.data, i)
Base.getindex(x::Var, i::Int) = x.args[i]
isvoid(x) = x == nothing
iscpu(x::Var) = isa(x.data,Array)
iscuda(x::Var) = isa(x.data,CuAray)

doc"""
    isparam(x::Var)

Returns whether `x` is a parameter or not
"""
isparam(x::Var) = !isvoid(x.grad) && isempty(x.args)
isparam(x) = false

doc"""
    topsort(tops::T...)

Topological sort.
"""
function topsort(tops::T...) where T
    sorted = T[]
    dict = ObjectIdDict()
    function visit(v::T)
        haskey(dict,v) && return
        dict[v] = v
        for arg in v.args
            if isa(arg, T)
                visit(arg)
            elseif isa(arg, Vector{T})
                foreach(visit, arg)
            end
        end
        push!(sorted, v)
    end
    foreach(visit, tops)
    sorted
end

doc"""
    gradient!(top::Var)

Compute gradients.
"""
function gradient!(tops::Var...)
    sorted = topsort(tops...)
    for top in tops
        isvoid(top.grad) && (top.grad = ones(top.data))
    end
    for v in sorted
        if !isempty(v.args) && isvoid(v.grad)
            v.grad = zeros(v.data)
        end
    end
    for i = length(sorted):-1:1
        y = sorted[i]
        isvoid(y.grad) && continue
        isempty(y.args) && continue
        addgrad!(y, y.args...)
    end
    collect(Iterators.filter(isparam,sorted))
end

function configure!(xs::Var...)
    if iscpu()
        for x in xs
            x.data = Array(x.data)
            isvoid(x.grad) || (x.grad = Array(x.grad))
        end
    elseif iscuda()
        for x in xs
            x.data = CuArray(x.data)
            isvoid(x.grad) || (x.grad = CuArray(x.grad))
        end
    end
end

function create_batch(batchsize::Int, data::Vector...; shuffle=false)
    perm = randperm(length(data[1]))
    map(data) do v
        batches = []
        v = v[perm]
        for i = 1:batchsize:length(v)
            range = i:min(i+batchsize-1,length(v))
            x = cat(ndims(v[1]), v[range]...)
            push!(batches, x)
        end
        batches
    end
end
