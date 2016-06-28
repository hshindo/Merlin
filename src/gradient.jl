export checkgrad, @checkgrad, @gradcheck

function topsort(var::Var)
  sorted = Var[]
  dict = ObjectIdDict()
  function visit(v::Var)
    haskey(dict, v) && return
    dict[v] = v
    for a in v.args
      visit(a)
    end
    push!(sorted, v)
  end
  visit(var)
  sorted
end

const gradeps = 1e-3

"""
Compute numerical gradient.
"""
function approx_grad(f, args::Vector{Var})
  map(args) do v
    x = v.value
    gx = similar(x)
    for k = 1:length(x)
      xk = x[k]
      x[k] = xk + gradeps
      y1 = f().value
      x[k] = xk - gradeps
      y2 = f().value
      x[k] = xk
      gx[k] = sum(y1 - y2) * (1/2gradeps)
    end
    gx
  end
end

macro gradcheck(f, args)
  quote
    local f() = $(esc(f))
    local args = $(esc(args))
    for x in args
      x.grad = zeros(x.value)
    end
    y = f()
    gradient!(y)
    approx_gxs = approx_grad(f, args)
    for i = 1:length(args)
      gx1 = args[i].grad
      gx2 = approx_gxs[i]
      all(d -> abs(d) < 1e-3, gx1 - gx2) && continue
      println(gx1 - gx2)
      return false
    end
    true
  end
end
