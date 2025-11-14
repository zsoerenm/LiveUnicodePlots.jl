using Test
using LiveLayoutUnicodePlots
using UnicodePlots

@testset "Types" begin
    @testset "LayoutResult" begin
        # Test LayoutResult construction
        content = "test content"
        lr = LiveLayoutUnicodePlots.LayoutResult(content)
        @test lr.content == content

        # Test show method includes content
        io = IOBuffer()
        show(io, MIME("text/plain"), lr)
        output = String(take!(io))
        @test occursin(content, output)
    end

    @testset "LivePlot" begin
        # Test LivePlot construction
        lp = LivePlot()
        @test lp.num_lines == 0
        @test lp.first_iteration == true
        @test lp.cached_widths == Int[]

        # Test that LivePlot is mutable
        lp.num_lines = 5
        @test lp.num_lines == 5

        lp.first_iteration = false
        @test lp.first_iteration == false

        push!(lp.cached_widths, 40)
        @test lp.cached_widths == [40]
    end

    @testset "LivePlot callable" begin
        # Test that LivePlot can be called with a string
        lp = LivePlot()

        # Redirect output to test without printing
        redirect_stdout(devnull) do
            lp("test output")
        end

        # After first call, first_iteration should be false
        @test lp.first_iteration == false

        # Test with LayoutResult
        redirect_stdout(devnull) do
            lp(LiveLayoutUnicodePlots.LayoutResult("layout content"))
        end

        @test lp.first_iteration == false
    end
end
