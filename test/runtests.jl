using Touchstone
using Base.Test

using Touchstone: nlines, expectednum

@testset "Data line unit tests" begin
    # S1P
    @test nlines(1) == 1
    @test expectednum(1,1) == 3
    @test_throws AssertionError expectednum(1,2)

    # S2P
    @test nlines(2) == 1
    @test expectednum(2,1) == 9
    @test_throws AssertionError expectednum(2,2)

    # S3P
    @test nlines(3) == 3
    @test expectednum(3,1) == 7
    @test expectednum(3,2) == 6
    @test expectednum(3,3) == 6
    @test_throws AssertionError expectednum(3,4)

    # S4P
    @test nlines(4) == 4
    @test expectednum(4,1) == 9
    @test expectednum(4,2) == 8
    @test expectednum(4,3) == 8
    @test expectednum(4,4) == 8
    @test_throws AssertionError expectednum(4,5)

    # S5P
    @test nlines(5) == 10
    @test expectednum(5,1)  == 9
    @test expectednum(5,2)  == 2
    @test expectednum(5,3)  == 8
    @test expectednum(5,4)  == 2
    @test expectednum(5,5)  == 8
    @test expectednum(5,6)  == 2
    @test expectednum(5,7)  == 8
    @test expectednum(5,8)  == 2
    @test expectednum(5,9)  == 8
    @test expectednum(5,10) == 2
    @test_throws AssertionError expectednum(5,11)

    # S10P
    @test nlines(10) == 30
    @test expectednum(10,1) == 9
    @test expectednum(10,2) == 8
    @test expectednum(10,3) == 4
    @test expectednum(10,4) == 8
    @test expectednum(10,5) == 8
    @test expectednum(10,6) == 4
    @test_throws AssertionError expectednum(10,31)
end
