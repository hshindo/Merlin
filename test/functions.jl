const T = Float32

@testset "functions" for i = 1:5

# activation
x = zerograd(randn(T,10,5))
for i = 1:length(x)
    abs(x.data[i]) < 0.1 && (x.data[i] += 1)
end
for f in (relu,sigmoid,tanh)
    @test_grad f x
    @test_cuda f x
end

# blas
A = zerograd(randn(T,10,5))
B = zerograd(randn(T,10,5))
@test_grad BLAS.gemm 'N' 'T' 1 A B
@test_cuda BLAS.gemm 'N' 'T' 1 A B

A = zerograd(randn(T,10,5))
B = zerograd(randn(T,10))
@test_grad BLAS.gemv 'T' 1 A B
@test_cuda BLAS.gemv 'T' 1 A B

A = zerograd(randn(T,10,5,7))
B = zerograd(randn(T,10,5,7))
#test_gradient(gemm_batch, 'N', 'T', 1, A, B)
#test_cuda(gemm_batch, 'N', 'T', 1, A, B)

# reduction
x = zerograd(randn(T,10,5))
for i = 1:length(x)
    x.data[i] *= 10
end
for dim = 1:2
    @test_grad max dim x
    @test_cuda max dim x
end
@test_grad max_batch x [3,2]
@test_cuda max_batch x [3,2]



# concat
x1 = zerograd(randn(T,10,5,2))
x2 = zerograd(randn(T,10,5,2))
x3 = zerograd(randn(T,10,5,2))
for dim = 1:3
    @test_grad concat dim x1 x2 x3
    @test_cuda concat dim x1 x2 x3
end

end

#=



@testset "conv" for i = 1:5
    #x = zerograd(curandn(T,10,10,5,4))
    #conv = Conv(T, 1, 1, 5, 3)
    #conv = cuda(conv)
    #y = conv(x)
    #gradient!(y)
end

@testset "dropout" for i = 1:5
    x = zerograd(randn(T,10,5))
    y = dropout(x, 0.5)
    gradient!(y)

    if LibCUDA.AVAILABLE
        setcuda() do
            y = dropout(x, 0.5)
            gradient!(y)
        end
    end
end

@testset "getindex" for i = 1:5
    x = zerograd(randn(T,10,5,4))
    test_gradient!(getindex, x, 2:7, :, 1:3)
    test_cuda!(getindex, x, 2:7, :, 1:3)
end

@testset "linear" for i = 1:5
    x = zerograd(randn(T,10,5))
    f = Linear(T, 10, 7, init_b=Uniform(-0.01,0.01))
    test_gradient!(linear, x, f.w, f.b)
    test_cuda!(linear, x, f.w, f.b)
end

@testset "lookup" for i = 1:5
    w = zerograd(randn(T,10,15))
    x = Var(Array{Cint}(rand(1:15,10)))
    test_gradient!(lookup, w, x)
    test_cuda!(lookup, w, x)
end

@testset "loss" for i = 1:5
    # crossentropy
    #p = Var(rand(1:10,5))
    #q = zerograd(softmax(rand(T,10,5)))
    #test_gradient(crossentropy, p, q, tol=2e-3)
    #p = Var(softmax(randn(T,10)))
    #q = zerograd(softmax(randn(T,10)))
    # test_gradient(crossentropy, p, q, tol=2e-3)

    # l2
    #x = Var(rand(T,10,5))
    #@testgrad l2(x,0.01) x

    # mse
    #x1 = zerograd(rand(T,10,5))
    #x2 = zerograd(rand(T,10,5))
    #test_gradient(mse, x1, x2)

    # softmax_crossentropy
    p = Var(Array{Int32}(rand(1:10,5)))
    q = zerograd(rand(T,10,5))
    test_gradient!(softmax_crossentropy, p, q)
    test_cuda!(softmax_crossentropy, p, q)
    p = Var(softmax(rand(T,10,5)))
    test_gradient!(softmax_crossentropy, p, q)
    test_cuda!(softmax_crossentropy, p, q)
end

@testset "math" for i = 1:5
    # x = zerograd(rand(T,10,5) + T(1))
    # test_gradient(exp, x)
    # test_gradient(log, x)

    x1 = zerograd(randn(T,10,5))
    x2 = zerograd(randn(T,10,5))
    test_gradient!(+, x1, x2)
    test_cuda!(+, x1, x2)
    test_gradient!(-, x1, x2)
    test_cuda!(-, x1, x2)
    test_gradient!(-, x1)
    test_cuda!(-, x1)

    x1 = zerograd(randn(T,10,5))
    x2 = zerograd(randn(T,10))
    test_gradient!(broadcast, +, x1, x2)
    test_gradient!(broadcast, -, x1, x2)
    test_gradient!(broadcast, *, x1, x2)

    A = zerograd(randn(T,10,5))
    B = zerograd(randn(T,5,7))
    test_gradient!(*, A, B)
    test_cuda!(*, A, B)
end


=#


#=
@testset "reshape" for i = 1:5
    x = zerograd(randn(T,10,5))
    test_gradient(reshape, x, 5, 10)
    test_cuda(reshape, x, 5, 10)
end

@testset "rnn" for i = 1:5
    x = zerograd(randn(T,20,10))
    batchdims = [5,3,2]
    for nlayers = 1:2
        lstm = LSTM(T, 20, 15, nlayers, 0.0, true)
        test_gradient(lstm, x, batchdims)
        test_cuda(lstm, x, batchdims)
    end
end

@testset "softmax" for i = 1:5
    x = zerograd(rand(T,10,5))
    test_gradient(softmax, x)
    test_cuda(softmax, x)
    x = zerograd(rand(T,10))
    test_gradient(softmax, x)
    test_cuda(softmax, x)
end

@testset "standardize" for i = 1:5
    x = zerograd(randn(T,1,5)*3+2)
    #f = Standardize(T,size(x.data))
    #@testgrad f(x,true) x f.scale f.bias
end

@testset "transpose_batch" for i = 1:5
    x = zerograd(randn(T,10,5))

    #f = Standardize(T,size(x.data))
    #@testgrad f(x,true) x f.scale f.bias
end

@testset "window1d" for i = 1:5
    x = zerograd(randn(T,10,10))
    test_gradient(window1d, x, 2, [5,3,2])
end
=#
