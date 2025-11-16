using Test
using LiveLayoutUnicodePlots

@testset "Merging" begin
    @testset "merge_plots_vertical" begin
        # Test basic vertical merging
        rows = ["line1", "line2", "line3"]
        result = merge_plots_vertical(rows)
        @test result == "line1\nline2\nline3"

        # Test empty array
        @test merge_plots_vertical(String[]) == ""

        # Test single line
        @test merge_plots_vertical(["single"]) == "single"
    end

    @testset "merge_plots_horizontal" begin
        # Test basic horizontal merging with UnicodePlots
        using UnicodePlots
        x = [1, 2, 3]
        y = [1, 4, 9]

        plot1 = lineplot(x, y; width=20, height=5)
        plot2 = lineplot(x, y .* 2; width=20, height=5)

        result = merge_plots_horizontal([string(plot1), string(plot2)])

        # Should have content
        @test !isempty(result)
    end
end
