module Satisfactory

using JuMP, Cbc, DataFrames, CSV, LightGraphs, LayeredLayouts, Plots
using InteractiveUtils: subtypes

@enum Building Smelter Constructor Assembler Manufacturer Refinery Miner Foundry WaterExtractor OilExtractor

include("products.jl")
include("recipes.jl")

export maximize!, maximizeDiscrete!, recipes, dependantRecipes, allRecipes
for p in subtypes(Product)
    @eval export $(nameof(p))
end

function maximize!(::Type{T} ; resources::Dict,
    lockedRecipes = String[], allowMultiRecipes = true) where T <: Product
    
    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 100_000_000)
    @variable(m, 0 <= y[r in allRecipes] <= 100_000_000)

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 1e-6 * sum(r.duration * y[r] for r in allRecipes))

    # Limit on recipes for all base resources (-> recipes with empty input)
    @constraint(m, [r in filter(r -> isempty(r.in), allRecipes)], y[r] * only(r.out)[2] <= get(resources, only(r.out)[1], 0))

    # Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        if p in (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, SAMOre, Uranium, Water, CrudeOil)
            @constraint(m, x[p] <= sum(qty * y[r] for (r, qty) in recipes(p)))
        else
            @constraint(m, x[p] <= sum(qty * y[r] for (r, qty) in recipes(p)) + get(resources, p, 0))
        end
        if !allowMultiRecipes
            @constraint(m, [y[r] for (r, qty) in recipes(p)] in SOS1()) # only use 1 recipe to produce a specific product
        end
    end

    # For each Product, make sure we have enough of that product for all recipes depending on it
    @constraint(m, [p in subtypes(Product)], x[p] >= sum(qty * y[r] for (r, qty) in dependantRecipes(p)))

    # Disallow use of locked recipes
    @constraint(m, [r in allRecipes ; r.name in lockedRecipes], y[r] == 0)

    JuMP.set_silent(m)
    optimize!(m);

    print_results(m, 1.)
end

function maximizeDiscrete!(::Type{T}, frac = 1/4 ; resources::Dict,
    lockedRecipes = String[], allowMultiRecipes = true) where T <: Product
    
    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 10000)
    @variable(m, 0 <= y[r in allRecipes] <= 10000, Int)

    for r in filter(r -> isempty(r.in), allRecipes)
        unset_integer(y[r])
    end

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 1e-6 * sum(r.duration * y[r] for r in allRecipes))

    # Limit on recipes for all base resources (-> recipes with empty input)
    @constraint(m, [r in filter(r -> isempty(r.in), allRecipes)], frac * y[r] * only(r.out)[2] <= get(resources, only(r.out)[1], 0))

    # Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        if p in (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, SAMOre, Uranium, Water, CrudeOil)
            @constraint(m, x[p] <= sum(frac * qty * y[r] for (r, qty) in recipes(p)))
        else
            @constraint(m, x[p] <= sum(frac * qty * y[r] for (r, qty) in recipes(p)) + get(resources, p, 0))
        end
        if !allowMultiRecipes
            @constraint(m, [y[r] for (r, qty) in recipes(p)] in SOS1()) # only use 1 recipe to produce a specific product
        end
    end
    
    # For each Product, make sure we have enough of that product for all recipes depending on it
    @constraint(m, [p in subtypes(Product)], x[p] >= sum(frac * qty * y[r] for (r, qty) in dependantRecipes(p)))

    # Disallow use of locked recipes
    @constraint(m, [r in allRecipes ; r.name in lockedRecipes], y[r] == 0)

    JuMP.set_silent(m)
    optimize!(m);

    print_results(m, frac)
end

function print_results(m, frac)
    x, y = m[:x], m[:y]

    println(termination_status(m))
    println(round(objective_value(m), digits=3), "\n")

    returnedProducts = []
    returnedRecipes = []

    println("Products : ")
    for p in subtypes(Product)
        production = getvalue(x[p])
        if production > 0
            println(p, " : ", round(production, digits=3))
            push!(returnedProducts, (p, production))
        end
    end

    println("\nRecipes : ")
    for r in allRecipes
        used = getvalue(y[r]) * frac
        if (used > 1e-9)
            println(r)
            if !isempty(r.in)
                print("\tinput : ")
                for p in r.in
                    print(p[1], " : ", round(p[2] * used, digits=4), "/min ", )
                end
                println()
            end
            for p in r.out
                println("\t", p[1], " : ", round(p[2] * used, digits=4), "/min")
            end
            println("\t", round(used, digits=3), " ", r.building)
            push!(returnedRecipes, (r, used))
        end
    end

    buildGraph(returnedRecipes)
end

function buildGraph(returnedRecipes)
    isempty(returnedRecipes) && return
    g = SimpleDiGraph()
    add_vertices!(g, length(returnedRecipes))
    indices = Dict(r => i for (i, r) in enumerate(first.(returnedRecipes)))

    edgeLabels = Float64[]
    
    for (r1, _) in returnedRecipes, (r2, used) in returnedRecipes
        for p1 in first.(r1.out), (p2, qty) in r2.in
            if p1 == p2
                add_edge!(g, indices[r1], indices[r2])
                push!(edgeLabels, round(qty * used, digits=3))
            end
        end
    end

    labels = [r.name  * "(" * string(round(used, digits=3)) * ")" for (r, used) in returnedRecipes]
    xs, ys = LayeredLayouts.solve_positions(LayeredLayouts.Zarate(), g)

    p = plot(showaxis=false, ticks=false, xlims = (0.5, maximum(xs) + 0.5))
    
    for (ind, edge) in enumerate(edges(g))
        plot!(p, 
            [xs[edge.src], (xs[edge.src] + xs[edge.dst]) / 2, xs[edge.dst]],
            [ys[edge.src], (ys[edge.src] + ys[edge.dst]) / 2, ys[edge.dst]], 
            text = ["", text(edgeLabels[ind], pointsize=6, valign=:top), ""],
            arrow=Plots.arrow(:closed),
            label=nothing,
        )
    end

    scatter!(p, xs, ys, text=text.(labels, pointsize=6, valign=:bottom), label=nothing,)

    p
end

unlocked = [
    "Alternate: Wet Concrete", "Alternate: Polymer Resin", "Alternate: Recycled Rubber", "Alternate: Recycled Plastic", "Alternate: Pure Copper Ingot", # Refinery
    "Alternate: Steel Rod", "Alternate: Steel Screw", "Alternate: Iron Wire", # Constructor
    "Alternate: Encased Industrial Pipe", "Alternate: Bolted Frame", "Alternate: Coated Iron Plate", "Alternate: Copper Rotor",  #Assembler
    "Alternate: Quickwire Stator", "Alternate: Steel Rotor", "Alternate: Silicone Circuit Board", "Alternate: Cheap Silica", "Alternate: Compacted Coal", #Assembler
    "Alternate: Automated Speed Wiring" #Manufacturer
    ]
lockedRecipes = setdiff(map(r -> r.name, filter(r -> occursin("Alternate:", r.name), allRecipes)), unlocked)

# maximize!(ModularFrame ; resources = Dict(IronOre => 420), lockedRecipes = lockedRecipes)

end
