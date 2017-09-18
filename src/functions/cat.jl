import Base.cat

"""
    concat(dim::Int, xs::Var...)
    concat(dim::Int, xs::Vector{Var})

Concatenate arrays over the given dimension.

```julia
x1 = Var(rand(Float32,4,3))
x2 = Var(rand(Float32,4,5))
y = concat(2, x1, x2)
```
"""
function cat(dim::Int, xs::Var...)
    N = ndims(xs[1])
    if dim == N
        batchdims = Int[]
        foreach(x -> append!(batchdims,x.batchdims), xs)
    else
        all(x -> x.batchdims == xs[1].batchdims, xs) || throw("Invalid batchdims.")
        batchdims = xs[1].batchdims
    end
    y = cat(dim, map(x -> x.data, xs)...)
    Var(y, batchdims, cat, (dim,xs...))
end

cat(dim::Int, xs::Node...; name="cat") = Node(cat, dim, xs..., name=name)

function addgrad!(y::Var, ::typeof(cat), dim::Int, xs::Var...)
    T, N = eltype(y.data), ndims(y.data)
    offset = 1
    for x in xs
        s = size(x.data, dim)
        if !isvoid(x.grad)
            range = ntuple(N) do i
                i == dim ? (offset:(offset+s-1)) : Colon()
            end
            BLAS.axpy!(T(1), y.grad[range...], x.grad)
        end
        offset += s
    end
end
