using Test
using LiveLayoutUnicodePlots

@testset "TextPlot Types" begin
    @testset "textplot() creates Plot with TextGraphics" begin
        using UnicodePlots: Plot
        tp = textplot("Hello World")

        @test tp isa Plot
        @test tp.graphics isa LiveLayoutUnicodePlots.TextGraphics
        @test hasfield(typeof(tp.graphics), :char_width)
        @test hasfield(typeof(tp.graphics), :char_height)
    end
end

@testset "Text Processing" begin
    @testset "wrap=true wraps long lines at word boundaries" begin
        tp = textplot("This is a very long line that should wrap"; width=15, wrap=true)
        lines = LiveLayoutUnicodePlots._process_text("This is a very long line that should wrap", 15, nothing, true)

        @test length(lines) > 1
        @test all(length(line) <= 15 for line in lines)
    end

    @testset "wrap=false truncates long lines" begin
        lines = LiveLayoutUnicodePlots._process_text("This is a very long line", 10, nothing, false)

        @test length(lines) == 1
        @test endswith(lines[1], "...")
        @test length(lines[1]) == 10
    end

    @testset "multiline content is split correctly" begin
        content = "Line 1\nLine 2\nLine 3"
        lines = LiveLayoutUnicodePlots._process_text(content, 20, nothing, false)

        @test length(lines) == 3
        @test lines[1] == "Line 1"
        @test lines[2] == "Line 2"
        @test lines[3] == "Line 3"
    end

    @testset "height parameter limits line count" begin
        content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        lines = LiveLayoutUnicodePlots._process_text(content, 20, 3, false)

        @test length(lines) == 3
    end
end

@testset "TextPlot Rendering" begin
    @testset "show() renders textplot correctly" begin
        tp = textplot("Hello\nWorld"; width=10, height=5, title="Test")

        io = IOBuffer()
        show(io, MIME("text/plain"), tp)
        output = String(take!(io))

        @test occursin("Test", output)
        @test occursin("Hello", output)
        @test occursin("World", output)
        @test occursin("┌", output) || occursin("+", output)
    end

    @testset "textplot with auto width calculates from content" begin
        tp = textplot("Short\nMedium line\nLong line here"; width=:auto)

        # Width should be determined by longest line
        @test tp.graphics.char_width >= 14  # "Long line here"
    end

    @testset "textplot with auto height calculates from line count" begin
        tp = textplot("Line 1\nLine 2\nLine 3"; height=:auto)

        # Height should match line count
        @test tp.graphics.char_height == 3
    end
end
