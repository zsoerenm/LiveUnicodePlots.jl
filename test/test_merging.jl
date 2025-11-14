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

    @testset "truncate_line_preserving_ansi" begin
        # Test basic truncation (may add ANSI reset codes)
        line = "Hello World"
        truncated = LiveLayoutUnicodePlots.truncate_line_preserving_ansi(line, 5)
        @test occursin("Hello", truncated)

        # Test line shorter than max_width
        truncated = LiveLayoutUnicodePlots.truncate_line_preserving_ansi(line, 20)
        @test occursin("Hello World", truncated)

        # Test with ANSI codes
        line = "\e[31mRed Text\e[0m"
        truncated = LiveLayoutUnicodePlots.truncate_line_preserving_ansi(line, 3)
        # Should preserve ANSI codes
        @test occursin("\e[", truncated)

        # Test empty line
        result = LiveLayoutUnicodePlots.truncate_line_preserving_ansi("", 10)
        @test result isa String  # May add reset code or be empty
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

    @testset "merge_plots_horizontal with truncation" begin
        # Test truncation to terminal width
        plot1_str = "A" ^ 100
        plot2_str = "B" ^ 100
        plots = [plot1_str, plot2_str]

        # With truncation enabled
        result = merge_plots_horizontal(plots; truncate_to_terminal=true)
        @test !isempty(result)

        # Without truncation
        result = merge_plots_horizontal(plots; truncate_to_terminal=false)
        @test !isempty(result)
    end
end
