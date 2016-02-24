type LogSoftmax <: Functor
end

function forward!(f::LogSoftmax, v::Variable)
  v.value = logsoftmax(v[1].value)
end

function backward!(f::LogSoftmax, v::Variable)
  gx = ∇logsoftmax(v[1].value, v[2].value, v.state, v.grad)
  addgrad!(v[1], gx)
end

function ∇logsoftmax{T}(x::Matrix{T}, y::Matrix{T}, gy::Matrix{T})
  # d(y_j) / d(x_i) = delta(i = j) - exp(y_i)
  gx = zeros(T, size(x))
  for d = 1:size(x,2)
    for i = 1:size(x,1)
      expy = exp(y[i, d])
      for j = 1:size(x,1)
        delta = i == j ? T(1.0) : T(0.0)
        gx[i, d] += gy[j, d] * (delta - expy)
      end
    end
  end
  gx
end
