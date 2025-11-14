using Test
using LiveLayoutUnicodePlots

@testset "Helpers" begin
    @testset "get_kwargs_from_expr" begin
        # Test extracting kwargs from expression
        expr = :(f(a, b; width=40, height=20))
        kwargs = LiveLayoutUnicodePlots.get_kwargs_from_expr(expr)
        @test length(kwargs) == 2

        # Test expression without kwargs
        expr = :(f(a, b))
        kwargs = LiveLayoutUnicodePlots.get_kwargs_from_expr(expr)
        @test isempty(kwargs)
    end

    @testset "extract_width" begin
        # Test extracting width
        expr = :(f(a, b; width=40, height=20))
        width = LiveLayoutUnicodePlots.extract_width(expr)
        @test width == 40

        # Test with QuoteNode :auto width
        expr = :(f(a, b; width=:auto))
        width = LiveLayoutUnicodePlots.extract_width(expr)
        @test width isa QuoteNode

        # Test without width
        expr = :(f(a, b; height=20))
        width = LiveLayoutUnicodePlots.extract_width(expr)
        @test isnothing(width)
    end

    @testset "extract_height" begin
        # Test extracting height
        expr = :(f(a, b; width=40, height=20))
        height = LiveLayoutUnicodePlots.extract_height(expr)
        @test height == 20

        # Test without height
        expr = :(f(a, b; width=40))
        height = LiveLayoutUnicodePlots.extract_height(expr)
        @test isnothing(height)
    end

    @testset "extract_title" begin
        # Test extracting title
        expr = :(f(a, b; title="Test"))
        title = LiveLayoutUnicodePlots.extract_title(expr)
        @test title == "Test"

        # Test without title
        expr = :(f(a, b; width=40))
        title = LiveLayoutUnicodePlots.extract_title(expr)
        @test isnothing(title)
    end
end
