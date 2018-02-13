export window1d

function window1d(x::Var, batchdims::Vector{Int}, width::Int)
    idx = window1d(batchdims, width)
    y = lookup(x.data, idx)
    Var(y, (window1d,x,idx))
end
window1d(x::Node, batchdims, width::Int) = Node(window1d, x, batchdims, width)

function window1d(batchdims::Vector{Int}, width::Int)
    cumdim = 0
    idx = Array{Int32}(2width+1, sum(batchdims))
    for dim in batchdims
        for i = 1:dim
            for offset = -width:width
                xi = (0 < i+offset <= dim) ? i+cumdim+offset : 0
                idx[offset+width+1,i+cumdim] = xi
            end
        end
        cumdim += dim
    end
    idx
end

function addgrad!(y::Var, ::typeof(window1d), x::Var, idx)
    isvoid(x.grad) || ∇lookup!(y.grad, x.grad, idx)
end
