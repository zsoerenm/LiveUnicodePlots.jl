# Smart Cache Invalidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make LivePlot cache aware of plot type and decoration changes, automatically recalculating widths when plot characteristics affecting overhead change.

**Architecture:** Extend LivePlot with signature-based cache validation. Compute hash signatures from plot type and decorations (title, labels, limits), compare on each iteration, and invalidate cache when signatures differ.

**Tech Stack:** Julia, UnicodePlots, LiveLayoutUnicodePlots

---

## Task 1: Add cached_signatures field to LivePlot

**Files:**
- Modify: `src/types.jl:48-54`
- Test: `test/test_cache_invalidation.jl` (new file)

**Step 1: Write the failing test**

Create new test file `test/test_cache_invalidation.jl`:

```julia
using Test
using LiveLayoutUnicodePlots

@testset "LivePlot cache signatures" begin
    @testset "LivePlot initialization includes cached_signatures" begin
        lp = LivePlot()
        @test hasfield(LivePlot, :cached_signatures)
        @test lp.cached_signatures isa Vector{Vector{UInt64}}
        @test isempty(lp.cached_signatures)
    end
end
```

**Step 2: Run test to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: FAIL with "type LivePlot has no field cached_signatures"

**Step 3: Modify LivePlot struct**

In `src/types.jl`, update the LivePlot struct (lines 48-54):

```julia
mutable struct LivePlot
    num_lines::Int
    first_iteration::Bool
    cached_widths::Vector{Int}
    cached_signatures::Vector{Vector{UInt64}}

    LivePlot() = new(0, true, Int[], Vector{UInt64}[])
end
```

Update the docstring (lines 18-30) to document the new field:

```julia
"""
    LivePlot

A mutable struct for managing in-place plot updates in the terminal with automatic
width caching for performance.

# Fields
- `num_lines::Int`: Number of lines in the last rendered plot (tracked automatically)
- `first_iteration::Bool`: Whether this is the first render (tracked automatically)
- `cached_widths::Vector{Int}`: Cached width calculations per row for performance (tracked automatically)
- `cached_signatures::Vector{Vector{UInt64}}`: Cached plot signatures for cache invalidation (tracked automatically)

For horizontal layouts, only the first element is used.
For grid layouts, each row has its own cached width and signatures at the corresponding index.
Each signature vector contains one hash per plot in that row.

# Example
```julia
# Create a LivePlot instance
live_plot = LivePlot()

# Animate using @live_layout macro (recommended - clean syntax)
for x in range(0, 2π, length=20)
    push!(x_vals, x)
    push!(y_vals, sin(x))

    @live_layout live_plot [
        lineplot(x_vals, y_vals; title = "sin(x)", width = :auto)
    ]
    sleep(0.05)
end
```
"""
```

**Step 4: Run test to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (1 new test, 80 existing tests = 81 total)

**Step 5: Commit**

```bash
git add src/types.jl test/test_cache_invalidation.jl
git commit -m "feat: add cached_signatures field to LivePlot"
```

---

## Task 2: Implement compute_plot_signature function

**Files:**
- Modify: `src/helpers.jl` (add at end)
- Test: `test/test_cache_invalidation.jl`

**Step 1: Write the failing tests**

Add to `test/test_cache_invalidation.jl`:

```julia
using UnicodePlots

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
```

**Step 2: Run tests to verify they fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: FAIL with "UndefVarError: `compute_plot_signature` not defined"

**Step 3: Implement compute_plot_signature function**

Add to end of `src/helpers.jl`:

```julia
"""
    compute_plot_signature(plot)::UInt64

Compute a hash signature for a plot based on characteristics that affect overhead:
- Plot type (graphics type)
- Decorations (axis limits, corner labels)
- Title presence and content
- X/Y axis labels

Used for cache invalidation in LivePlot to detect when overhead may have changed.

# Examples
```julia
p1 = lineplot(1:5, 1:5; title="Test")
p2 = lineplot(1:5, 1:5; title="Test")
sig1 = compute_plot_signature(p1)
sig2 = compute_plot_signature(p2)
@assert sig1 == sig2  # Same characteristics = same signature

p3 = lineplot(1:5, 1:5; title="Different")
sig3 = compute_plot_signature(p3)
@assert sig1 != sig3  # Different title = different signature
```
"""
function compute_plot_signature(plot)::UInt64
    # Start with graphics type (BrailleCanvas vs TextGraphics vs BarplotGraphics, etc.)
    h = hash(typeof(plot.graphics))

    # Include decoration information (axis limits stored as corner labels)
    if hasfield(typeof(plot), :decorations)
        h = hash(plot.decorations, h)
    end

    # For UnicodePlots: title, xlabel, ylabel are stored as RefValue{String}
    if hasfield(typeof(plot), :title)
        h = hash(plot.title[], h)  # Extract value from RefValue
    end
    if hasfield(typeof(plot), :xlabel)
        h = hash(plot.xlabel[], h)
    end
    if hasfield(typeof(plot), :ylabel)
        h = hash(plot.ylabel[], h)
    end

    return h
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (6 new tests + 81 existing = 87 total)

**Step 5: Commit**

```bash
git add src/helpers.jl test/test_cache_invalidation.jl
git commit -m "feat: implement compute_plot_signature for cache invalidation"
```

---

## Task 3: Update horizontal layout cache validation

**Files:**
- Modify: `src/layout_generation.jl:159-167`
- Test: `test/test_cache_invalidation.jl`

**Step 1: Write the failing test**

Add to `test/test_cache_invalidation.jl`:

```julia
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
```

**Step 2: Run tests to verify they fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: FAIL - signatures not being stored/checked

**Step 3: Update horizontal layout cache logic**

In `src/layout_generation.jl`, replace lines 159-167 with:

```julia
_w = if length(lp.cached_widths) < 1
    # First time - calculate, cache width AND signatures
    temp_plots = [$(temp_exprs...)]
    signatures = [LiveLayoutUnicodePlots.compute_plot_signature(p) for p in temp_plots]
    calculated_w = $width_calc_expr

    push!(lp.cached_widths, calculated_w)
    push!(lp.cached_signatures, signatures)
    calculated_w
else
    # Check if plot signatures have changed
    temp_plots = [$(temp_exprs...)]
    current_signatures = [LiveLayoutUnicodePlots.compute_plot_signature(p) for p in temp_plots]

    if current_signatures != lp.cached_signatures[1]
        # Signatures changed - recalculate
        calculated_w = $width_calc_expr
        lp.cached_widths[1] = calculated_w
        lp.cached_signatures[1] = current_signatures
        calculated_w
    else
        # Cache still valid
        lp.cached_widths[1]
    end
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (4 new tests + 87 existing = 91 total)

**Step 5: Commit**

```bash
git add src/layout_generation.jl test/test_cache_invalidation.jl
git commit -m "feat: add signature validation to horizontal layout caching"
```

---

## Task 4: Update grid layout cache validation

**Files:**
- Modify: `src/layout_generation.jl:317-330`
- Test: `test/test_cache_invalidation.jl`

**Step 1: Write the failing test**

Add to `test/test_cache_invalidation.jl`:

```julia
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
```

**Step 2: Run tests to verify they fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: FAIL - grid layout not storing/checking signatures per row

**Step 3: Update grid layout cache logic**

In `src/layout_generation.jl`, replace lines 317-330 with:

```julia
$(Symbol("_w_row_$(row_idx)")) = if length(lp.cached_widths) < $row_idx
    # First time for this row - calculate and cache
    temp_plots = [$(temp_exprs...)]
    signatures = [LiveLayoutUnicodePlots.compute_plot_signature(p) for p in temp_plots]
    calculated_w = $width_calc_expr

    push!(lp.cached_widths, calculated_w)
    push!(lp.cached_signatures, signatures)
    calculated_w
else
    # Check signatures for this row
    temp_plots = [$(temp_exprs...)]
    current_signatures = [LiveLayoutUnicodePlots.compute_plot_signature(p) for p in temp_plots]

    if current_signatures != lp.cached_signatures[$row_idx]
        # Recalculate
        calculated_w = $width_calc_expr
        lp.cached_widths[$row_idx] = calculated_w
        lp.cached_signatures[$row_idx] = current_signatures
        calculated_w
    else
        lp.cached_widths[$row_idx]
    end
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (3 new tests + 91 existing = 94 total)

**Step 5: Commit**

```bash
git add src/layout_generation.jl test/test_cache_invalidation.jl
git commit -m "feat: add signature validation to grid layout caching"
```

---

## Task 5: Add integration test for dynamic plot switching

**Files:**
- Modify: `test/test_integration.jl`

**Step 1: Write the failing test**

Add to end of `test/test_integration.jl`:

```julia
@testset "Dynamic plot switching" begin
    @testset "horizontal layout with plot type switching" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]
        y = [1, 4, 9, 16, 25]

        # Start with lineplot
        for i in 1:3
            @live_layout lp [
                lineplot(x, y; width=:auto),
                lineplot(x, y .* 2; width=:auto)
            ]
        end

        sig_lineplot = copy(lp.cached_signatures[1])

        # Switch to textplot in first position
        for i in 1:3
            @live_layout lp [
                textplot("Status: Running"; width=:auto),
                lineplot(x, y .* 2; width=:auto)
            ]
        end

        sig_textplot = lp.cached_signatures[1]

        @test sig_lineplot != sig_textplot
        @test length(lp.cached_widths) == 1
        @test length(lp.cached_signatures) == 1
    end

    @testset "title toggling invalidates cache" begin
        lp = LivePlot()
        x = [1, 2, 3, 4, 5]

        # Iteration 1: with title
        @live_layout lp [lineplot(x, x; width=:auto, title="Titled")]
        sig_with_title = lp.cached_signatures[1][1]

        # Iteration 2: without title
        @live_layout lp [lineplot(x, x; width=:auto, title="")]
        sig_without_title = lp.cached_signatures[1][1]

        @test sig_with_title != sig_without_title
    end

    @testset "conditional plot rendering with cache" begin
        lp = LivePlot()
        x = Float64[]
        y = Float64[]

        for i in 1:10
            push!(x, i * 0.1)
            push!(y, sin(i * 0.1))

            # Conditionally show lineplot or textplot
            plot1 = if i > 5
                lineplot(x, y; width=:auto, title="Signal")
            else
                textplot("Warming up..."; width=:auto, title="Status")
            end

            @live_layout lp [
                plot1,
                lineplot(x, cos.(x); width=:auto, title="Reference")
            ]
        end

        # Cache should have been invalidated at i=6
        @test length(lp.cached_signatures) == 1
        @test length(lp.cached_signatures[1]) == 2
    end
end
```

**Step 2: Run test to verify it fails**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: Should fail if cache invalidation is not working, or pass if it is

**Step 3: No implementation needed**

This is a pure integration test to verify the feature works end-to-end. It should pass after the previous tasks.

**Step 4: Run test to verify it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (3 new tests + 94 existing = 97 total)

**Step 5: Commit**

```bash
git add test/test_integration.jl
git commit -m "test: add integration tests for dynamic plot switching"
```

---

## Task 6: Update test runner to include new test file

**Files:**
- Modify: `test/runtests.jl`

**Step 1: Check current test includes**

Read `test/runtests.jl` to see existing includes.

**Step 2: Add new test file include**

Add after existing test includes in `test/runtests.jl`:

```julia
include("test_cache_invalidation.jl")
```

**Step 3: Run full test suite**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (all 97 tests)

**Step 4: Commit**

```bash
git add test/runtests.jl
git commit -m "test: include cache invalidation tests in test suite"
```

---

## Task 7: Update README with dynamic plot switching example

**Files:**
- Modify: `README.md`

**Step 1: Add dynamic plot switching section**

Add new section after "Text Elements" section in `README.md`:

```markdown
### Dynamic Plot Switching

LivePlot automatically detects when plot characteristics change and recalculates layouts:

```julia
using LiveLayoutUnicodePlots
using UnicodePlots

live_plot = LivePlot()
x = Float64[]
y = Float64[]

for i in 1:100
    push!(x, i * 0.1)
    push!(y, sin(i * 0.1))

    # Dynamically choose plot type based on condition
    plot1 = if length(y) > 50 && maximum(y) > 0.5
        lineplot(x, y; title="Signal")
    else
        textplot("Waiting for signal..."; width=30, title="Status")
    end

    @live_layout live_plot [
        plot1,
        lineplot(x, cos.(x); title="Reference")
    ]

    sleep(0.05)
end
```

The cache automatically invalidates when:
- Plot type changes (lineplot ↔ textplot ↔ barplot)
- Title changes
- Labels change (xlabel, ylabel)
- Axis limits change (xlim, ylim)
```

**Step 2: Verify documentation builds/renders**

Read through the updated README to ensure formatting is correct.

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add dynamic plot switching example to README"
```

---

## Task 8: Final verification and cleanup

**Files:**
- All modified files

**Step 1: Run complete test suite**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`

Expected: PASS (97 tests, 0 failures)

**Step 2: Check for any warnings or deprecations**

Review test output for any warnings that should be addressed.

**Step 3: Verify design document is committed**

Run: `git status`

Expected: `docs/plans/2025-11-15-smart-cache-invalidation-design.md` should be committed

If not:
```bash
git add docs/plans/2025-11-15-smart-cache-invalidation-design.md
git commit -m "docs: add smart cache invalidation design document"
```

**Step 4: Review commit history**

Run: `git log --oneline`

Expected commits:
1. feat: add cached_signatures field to LivePlot
2. feat: implement compute_plot_signature for cache invalidation
3. feat: add signature validation to horizontal layout caching
4. feat: add signature validation to grid layout caching
5. test: add integration tests for dynamic plot switching
6. test: include cache invalidation tests in test suite
7. docs: add dynamic plot switching example to README
8. docs: add smart cache invalidation design document (if needed)

**Step 5: No commit needed**

This is verification only.

---

## Summary

**Implementation complete when:**
- All 97 tests pass (13 new tests for cache invalidation + 3 integration tests + 81 existing)
- `LivePlot` has `cached_signatures` field
- `compute_plot_signature()` function works for all plot types
- Horizontal and grid layouts use signature-based cache validation
- Integration tests verify dynamic plot switching works
- README documents the feature
- Design document is committed

**Performance characteristics:**
- Cache hit: ~microseconds (signature comparison)
- Cache miss: Same cost as before (overhead calculation required)
- Common case: 99%+ cache hits in animations

**Backward compatibility:**
- Fully backward compatible
- Existing code works unchanged
- Only adds functionality for dynamic scenarios
