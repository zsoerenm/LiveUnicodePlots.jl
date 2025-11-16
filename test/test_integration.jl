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

    @testset "LivePlot with @layout" begin
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        lp = LivePlot()

        redirect_stdout(devnull) do
            lp(@layout [
                lineplot(x, y; width=:auto, height=10),
                lineplot(x, y .* 2; width=:auto, height=10)
            ])
        end

        # After first call, first_iteration should be false
        @test lp.first_iteration == false
    end

    @testset "LivePlot with multiple iterations" begin
        lp = LivePlot()

        redirect_stdout(devnull) do
            for i in 1:3
                x = collect(1:i+2)
                y = x .^ 2

                lp(@layout [
                    lineplot(x, y; width=:auto, height=10),
                    lineplot(x, y .* 2; width=:auto, height=10)
                ])
            end
        end

        # First iteration flag should be false after iterations
        @test lp.first_iteration == false
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

                    lp(@layout [
                        lineplot(x, y; width=30, height=10),
                        textplot("Iteration: $i\nCount: $(length(x))";
                                width=20, height=10, title="Status")
                    ])
                end
            end

            # First iteration flag should be false after iterations
            @test lp.first_iteration == false
        end
    end

    @testset "Dynamic plot switching" begin
        @testset "horizontal layout with plot type switching" begin
            lp = LivePlot()
            x = [1, 2, 3, 4, 5]
            y = [1, 4, 9, 16, 25]

            # Start with lineplot
            redirect_stdout(devnull) do
                for i in 1:3
                    lp(@layout [
                        lineplot(x, y; width=:auto),
                        lineplot(x, y .* 2; width=:auto)
                    ])
                end
            end

            @test lp.first_iteration == false

            # Switch to textplot in first position
            redirect_stdout(devnull) do
                for i in 1:3
                    lp(@layout [
                        textplot("Status: Running"; width=:auto),
                        lineplot(x, y .* 2; width=:auto)
                    ])
                end
            end

            @test lp.first_iteration == false
        end

        @testset "title toggling" begin
            lp = LivePlot()
            x = [1, 2, 3, 4, 5]

            # Iteration 1: with title
            redirect_stdout(devnull) do
                lp(@layout [lineplot(x, x; width=:auto, title="Titled")])
            end
            @test lp.first_iteration == false

            # Iteration 2: without title
            redirect_stdout(devnull) do
                lp(@layout [lineplot(x, x; width=:auto, title="")])
            end
            @test lp.first_iteration == false
        end

        @testset "conditional plot rendering" begin
            lp = LivePlot()
            x = Float64[]
            y = Float64[]

            redirect_stdout(devnull) do
                for i in 1:10
                    push!(x, i * 0.1)
                    push!(y, sin(i * 0.1))

                    # Conditionally show lineplot or textplot
                    plot1 = if i > 5
                        lineplot(x, y; width=:auto, title="Signal")
                    else
                        textplot("Warming up..."; width=:auto, title="Status")
                    end

                    lp(@layout [
                        plot1,
                        lineplot(x, cos.(x); width=:auto, title="Reference")
                    ])
                end
            end

            # Should complete without errors
            @test lp.first_iteration == false
        end
    end
end
