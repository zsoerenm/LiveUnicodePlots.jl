using Test
using LiveLayoutUnicodePlots
using UnicodePlots

@testset "Integration Tests" begin
    @testset "@layout macro - horizontal layout" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        result = @layout [
            lineplot(x, y; width=20, height=10),
            lineplot(x, y .* 2; width=20, height=10)
        ]

        @test result isa LiveLayoutUnicodePlots.LayoutResult
        @test !isempty(result.content)
    end

    @testset "@layout macro - grid layout" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        result = @layout [
            [lineplot(x, y; width=20, height=8),
             lineplot(x, y .* 2; width=20, height=8)],
            [lineplot(x, y .+ 1; width=40, height=8)]
        ]

        @test result isa LiveLayoutUnicodePlots.LayoutResult
        @test !isempty(result.content)
        @test occursin("\n", result.content)
    end

    @testset "@layout with auto width/height" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        result = @layout [
            lineplot(x, y; width=:auto, height=:auto),
            lineplot(x, y .* 2; width=:auto, height=:auto)
        ]

        @test result isa LiveLayoutUnicodePlots.LayoutResult
        @test !isempty(result.content)
    end

    @testset "@live_layout macro" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        lp = LivePlot()

        redirect_stdout(devnull) do
            @live_layout lp [
                lineplot(x, y; width=:auto, height=10),
                lineplot(x, y .* 2; width=:auto, height=10)
            ]
        end

        # After first call, cached_widths should be populated
        @test !isempty(lp.cached_widths)
        @test lp.first_iteration == false
    end

    @testset "@live_layout with multiple iterations" begin
        lp = LivePlot()

        redirect_stdout(devnull) do
            for i in 1:3
                x = collect(1:i+2)
                y = x .^ 2

                @live_layout lp [
                    lineplot(x, y; width=:auto, height=10),
                    lineplot(x, y .* 2; width=:auto, height=10)
                ]
            end
        end

        # Should have cached widths after iterations
        @test !isempty(lp.cached_widths)
        @test lp.cached_widths[1] > 0
    end

    @testset "TextPlot in layouts" begin
        @testset "textplot in horizontal layout with plots" begin
            x = [1, 2, 3, 4, 5]
            y = [1, 4, 9, 16, 25]

            result = @layout [
                lineplot(x, y; width=30, height=10),
                textplot("Status: OK\nCount: 1234"; width=20, height=10, title="Metrics")
            ]

            @test result isa LiveLayoutUnicodePlots.LayoutResult
            @test occursin("Status: OK", result.content)
            @test occursin("Count: 1234", result.content)
        end

        @testset "textplot with auto width in layout" begin
            x = [1, 2, 3, 4, 5]

            result = @layout [
                lineplot(x, x.^2; width=40),
                textplot("Info\nData"; width=:auto, title="Status")
            ]

            @test result isa LiveLayoutUnicodePlots.LayoutResult
            @test occursin("Info", result.content)
        end

        @testset "textplot in grid layout" begin
            x = [1, 2, 3, 4, 5]

            result = @layout [
                [lineplot(x, x.^2; width=:auto, height=8),
                 textplot("Row 1 Info"; width=:auto, height=8)],
                [textplot("Row 2 Status"; width=:auto, height=:auto)]
            ]

            @test result isa LiveLayoutUnicodePlots.LayoutResult
            @test occursin("Row 1 Info", result.content)
            @test occursin("Row 2 Status", result.content)
        end

        @testset "textplot in live layout" begin
            lp = LivePlot()

            redirect_stdout(devnull) do
                for i in 1:3
                    x = collect(1:i+2)
                    y = x .^ 2

                    @live_layout lp [
                        lineplot(x, y; width=30, height=10),
                        textplot("Iteration: $i\nCount: $(length(x))";
                                width=20, height=10, title="Status")
                    ]
                end
            end

            # Should have cached widths
            @test !isempty(lp.cached_widths)
        end
    end
end
