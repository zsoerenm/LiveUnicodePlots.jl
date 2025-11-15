using Test
using LiveLayoutUnicodePlots
using UnicodePlots

@testset "LivePlot cache signatures" begin
    @testset "LivePlot initialization includes cached_signatures" begin
        lp = LivePlot()
        @test hasfield(LivePlot, :cached_signatures)
        @test lp.cached_signatures isa Vector{Vector{UInt64}}
        @test isempty(lp.cached_signatures)
    end
end

@testset "compute_plot_signature" begin
    @testset "same plot produces same signature" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        p1 = lineplot(x, y; title="Test")
        p2 = lineplot(x, y; title="Test")

        sig1 = LiveLayoutUnicodePlots.compute_plot_signature(p1)
        sig2 = LiveLayoutUnicodePlots.compute_plot_signature(p2)

        @test sig1 == sig2
        @test sig1 isa UInt64
    end

    @testset "different plot types produce different signatures" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        p1 = lineplot(x, y)
        p2 = textplot("Hello"; width=10)

        sig1 = LiveLayoutUnicodePlots.compute_plot_signature(p1)
        sig2 = LiveLayoutUnicodePlots.compute_plot_signature(p2)

        @test sig1 != sig2
    end

    @testset "title changes affect signature" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        p1 = lineplot(x, y; title="Title 1")
        p2 = lineplot(x, y; title="Title 2")
        p3 = lineplot(x, y; title="")

        sig1 = LiveLayoutUnicodePlots.compute_plot_signature(p1)
        sig2 = LiveLayoutUnicodePlots.compute_plot_signature(p2)
        sig3 = LiveLayoutUnicodePlots.compute_plot_signature(p3)

        @test sig1 != sig2
        @test sig1 != sig3
        @test sig2 != sig3
    end

    @testset "label changes affect signature" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        p1 = lineplot(x, y; xlabel="X")
        p2 = lineplot(x, y; xlabel="X", ylabel="Y")
        p3 = lineplot(x, y)

        sig1 = LiveLayoutUnicodePlots.compute_plot_signature(p1)
        sig2 = LiveLayoutUnicodePlots.compute_plot_signature(p2)
        sig3 = LiveLayoutUnicodePlots.compute_plot_signature(p3)

        @test sig1 != sig2
        @test sig1 != sig3
        @test sig2 != sig3
    end

    @testset "limit changes affect signature" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        p1 = lineplot(x, y; xlim=(0, 10))
        p2 = lineplot(x, y; xlim=(0, 100))
        p3 = lineplot(x, y)

        sig1 = LiveLayoutUnicodePlots.compute_plot_signature(p1)
        sig2 = LiveLayoutUnicodePlots.compute_plot_signature(p2)
        sig3 = LiveLayoutUnicodePlots.compute_plot_signature(p3)

        @test sig1 != sig2
        @test sig1 != sig3
    end
end

@testset "Horizontal layout cache invalidation" begin
    @testset "cache stores signatures on first iteration" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        # First iteration
        result = @layout lp [lineplot(x, y; width=:auto)]

        @test length(lp.cached_widths) == 1
        @test length(lp.cached_signatures) == 1
        @test length(lp.cached_signatures[1]) == 1
        @test lp.cached_signatures[1][1] isa UInt64
    end

    @testset "cache reuses width when signatures match" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration
        result1 = @layout lp [lineplot(x, x; width=:auto)]
        cached_width = lp.cached_widths[1]

        # Second iteration with same plot characteristics
        result2 = @layout lp [lineplot(x, x .+ 1; width=:auto)]

        @test lp.cached_widths[1] == cached_width
        @test length(lp.cached_signatures) == 1  # Not recalculated
    end

    @testset "cache invalidates when plot type changes" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration with lineplot
        result1 = @layout lp [lineplot(x, x; width=:auto)]
        sig1 = lp.cached_signatures[1][1]

        # Second iteration with textplot
        result2 = @layout lp [textplot("Hello"; width=:auto)]
        sig2 = lp.cached_signatures[1][1]

        @test sig1 != sig2  # Signature changed
    end

    @testset "cache invalidates when title changes" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration
        result1 = @layout lp [lineplot(x, x; width=:auto, title="Title 1")]
        sig1 = lp.cached_signatures[1][1]

        # Second iteration with different title
        result2 = @layout lp [lineplot(x, x; width=:auto, title="Title 2")]
        sig2 = lp.cached_signatures[1][1]

        @test sig1 != sig2
    end
end

@testset "Grid layout cache invalidation" begin
    @testset "cache stores signatures per row" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration with 2 rows
        result = @layout lp [
            [lineplot(x, x; width=:auto, height=8), lineplot(x, x.^2; width=:auto, height=8)],
            [lineplot(x, x.^3; width=:auto, height=:auto)]
        ]

        @test length(lp.cached_widths) == 2
        @test length(lp.cached_signatures) == 2
        @test length(lp.cached_signatures[1]) == 2  # Row 1 has 2 plots
        @test length(lp.cached_signatures[2]) == 1  # Row 2 has 1 plot
    end

    @testset "cache reuses widths when signatures match per row" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration
        result1 = @layout lp [
            [lineplot(x, x; width=:auto, height=8)],
            [lineplot(x, x.^2; width=:auto, height=:auto)]
        ]
        cached_width_row1 = lp.cached_widths[1]
        cached_width_row2 = lp.cached_widths[2]

        # Second iteration with same characteristics
        result2 = @layout lp [
            [lineplot(x, x .+ 1; width=:auto, height=8)],
            [lineplot(x, (x .+ 1).^2; width=:auto, height=:auto)]
        ]

        @test lp.cached_widths[1] == cached_width_row1
        @test lp.cached_widths[2] == cached_width_row2
    end

    @testset "cache invalidates row when signature changes in that row" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # First iteration
        result1 = @layout lp [
            [lineplot(x, x; width=:auto, height=8)],
            [lineplot(x, x.^2; width=:auto, height=:auto)]
        ]
        sig_row1_before = copy(lp.cached_signatures[1])
        sig_row2_before = copy(lp.cached_signatures[2])

        # Second iteration - change plot type in row 1 only
        result2 = @layout lp [
            [textplot("Hello"; width=:auto, height=8)],
            [lineplot(x, x.^2; width=:auto, height=:auto)]
        ]

        @test lp.cached_signatures[1] != sig_row1_before  # Row 1 changed
        @test lp.cached_signatures[2] == sig_row2_before  # Row 2 unchanged
    end
end
