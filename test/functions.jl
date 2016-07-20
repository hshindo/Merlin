const T = Float64

macro cuda_test(f, args)
    quote
        haskey(ENV, "USE_CUDA") || return true

        local f() = $(esc(f))
        local args = $(esc(args))
        eps = 1e-3
        y1 = f().value
        for v in args
            v.value = CuArray(v.value)
        end
        y2 = Array(f().value)
        b = all(d -> abs(d) < 2eps, y1 - y2)

        for v in args
            v.value = Array(v.value)
        end
        b
    end
end

@testset "functions" for i = 1:5

x = Data(rand(T,5,4))
for f in [sigmoid, tanh]
    @test @checkgrad f(x) [x]
    #@test @cuda_test f(x) (x,)
end

x1 = Data(rand(T,10,5,3))
x2 = Data(rand(T,5,10,3))
x3 = Data(rand(T,10,5,3))
@test @checkgrad gemm('N','N',0.2,x1,x2) [x1,x2]
@test @checkgrad gemm('N','T',0.3,x1,x3) [x1,x3]
@test @checkgrad gemm('T','N',0.4,x1,x3) [x1,x3]
@test @checkgrad gemm('T','T',0.5,x1,x2) [x1,x2]

x1 = Data(rand(T,10,5,2))
x2 = Data(rand(T,10,5,2))
x3 = Data(rand(T,10,5,2))
for dim = 1:3
    @test @checkgrad concat(dim,x1,x2,x3) [x1,x2,x3]
end

x = Data(rand(Float32,5,4,3,2))
c = Conv(rand(Float32,2,2,3,4), stride=(1,1), paddims=(0,0))
@test @checkgrad c(x) [c[1],x]

x = Data(rand(T,10,5))
l = Linear(T, 10, 7)
l[3] = Param(rand(T,size(l[3].data)))
@test @checkgrad l(x) [l[1],x,l[3]]

w = Embed(Float32,10000,100)
x = Data(rand(1:1000,5,3))
y = w(x)
gradient!(y)

x1 = Data(rand(T,10,5))
x2 = Data(rand(T,10,5))
x3 = Data(rand(T,10,1))
for op in [+,-,.*]
    @test @checkgrad op(x1,x2) [x1,x2]
    @test @checkgrad op(x1,x3) [x1,x3]
    @test @checkgrad op(x3,x1) [x3,x1]
end
x4 = Data(rand(T,5,7))
@test @checkgrad *(x1,x4) [x1,x4]

x = Data(rand(T,10,5))
@test @checkgrad reshape(x,2,5,5) [x]

x = Data(rand(T,10,5,3,4))
for dim = 1:ndims(x.data)
    @test @checkgrad softmax(x,dim) [x]
    @test @checkgrad logsoftmax(x,dim) [x]
end

p = Data([1:5;])
x = Data(rand(Float32,10,5))
for dim = 1:1
    @test @checkgrad crossentropy(p,x,dim) [x]
end

x = Data(rand(T,10,5,4,3))
for dim = 1:ndims(x.data)
    @test @checkgrad sum(x,dim) [x]
end

x = Data(rand(T,10,5))
@test @checkgrad x.' [x]
end
