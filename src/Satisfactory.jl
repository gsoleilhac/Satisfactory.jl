module Satisfactory

using JuMP, Cbc, DataFrames, CSV, LightGraphs, LayeredLayouts, Plots
using InteractiveUtils: subtypes

@enum Building Smelter Constructor Assembler Manufacturer Refinery Miner Foundry WaterExtractor OilExtractor

include("products.jl")
for p in subtypes(Product)
    @eval export $(nameof(p))
end

export recipes, dependantRecipes, allRecipes
include("recipes.jl")

export baseRecipes, baseResources
export maximize!, maximizeDiscrete!

const baseRecipes = filter(x -> !occursin("Alternate", x.name), allRecipes)
const baseResources = (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, Uranium, Water, CrudeOil)

function maximize!(::Type{T} ; resources::Dict, alternates = String[], 
    allowMultiRecipes = true, nodeLabelSize = 4, edgeLabelSize = 4) where T <: Product
    
    allowedRecipes = union(baseRecipes, filter(r -> any(alt -> occursin(alt, r.name), alternates), allRecipes))

    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 100_000_000)
    @variable(m, 0 <= y[r in allRecipes] <= 100_000_000)

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) 
        - 1e-6 * sum(y[r] for r in allowedRecipes)
        - 1e-6 * sum(y[r] for r in allRecipes if occursin("Alternate", r.name)))

    # Limit on recipes for all base resources (-> recipes with empty input)
    @constraint(m, [r in filter(r -> isempty(r.in), allRecipes)], y[r] * only(r.out)[2] <= get(resources, only(r.out)[1], 0))

    # Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        if p in baseResources
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

    @constraint(m, [r in allRecipes ; !(r in allowedRecipes)], y[r] == 0)

    JuMP.set_silent(m)
    optimize!(m);

    print_results(m, 1., nodeLabelSize, edgeLabelSize, T)
end

function maximizeDiscrete!(::Type{T}, frac = 1/4 ; resources::Dict, alternates = String[], 
    allowMultiRecipes = true, nodeLabelSize = 4, edgeLabelSize = 4) where T <: Product
    
    allowedRecipes = union(baseRecipes, filter(r -> any(alt -> occursin(alt, r.name), alternates), allRecipes))

    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 10000)
    @variable(m, 0 <= y[r in allRecipes] <= 10000, Int)

    for r in filter(r -> isempty(r.in), allowedRecipes)
        unset_integer(y[r])
    end

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 1e-6 * sum(r.duration * y[r] for r in allowedRecipes))

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

    @constraint(m, [r in allRecipes ; !(r in allowedRecipes)], y[r] == 0)

    JuMP.set_silent(m)
    optimize!(m);

    print_results(m, frac, nodeLabelSize, edgeLabelSize, T)
end

function print_results(m, frac, nodeLabelSize, edgeLabelSize, T)
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

    buildGraph(returnedRecipes, nodeLabelSize, edgeLabelSize, T, objective_value(m))
end

intOrRound(x, d = 2) = isinteger(round(x, digits=3)) ? string(round(Int, x)) : string(round(x, digits = d))

function buildGraph(returnedRecipes, nodeLabelSize, edgeLabelSize, T, objValue)
    isempty(returnedRecipes) && return
    g = SimpleDiGraph()
    add_vertices!(g, length(returnedRecipes))
    indices = Dict(r => i for (i, r) in enumerate(first.(returnedRecipes)))

    # sinks = filter(rec -> any(x -> x[1] == T, rec[1].out), returnedRecipes)

    edgeLabels = Dict{Tuple{Int, Int}, Float64}()
    removedEdges = Tuple{Int, Int}[]
    
    for (r1, _) in returnedRecipes, (r2, used) in returnedRecipes
        for p1 in first.(r1.out), (p2, qty) in r2.in
            if p1 == p2
                add_edge!(g, indices[r1], indices[r2])
                push!(edgeLabels, (indices[r1], indices[r2]) => qty * used)
                if LightGraphs.is_cyclic(g)
                    rem_edge!(g, indices[r1], indices[r2])
                    println("removed acyclic edge ", r1, " => ", r2, " : ", intOrRound(qty * used))
                    push!(removedEdges, (indices[r1], indices[r2]))
                end
            end
        end
    end

    labels = [r.name  * "(" * intOrRound(used) * ")" for (r, used) in returnedRecipes]
    xs, ys, edge2path = LayeredLayouts.solve_positions(LayeredLayouts.Zarate(time_limit=LayeredLayouts.Dates.Second(10)), g)
    p = plot(showaxis=false, ticks=false, xlims = (0.5, maximum(xs) + 1.))
    
    for (edge, path) in edge2path
        x, y = path
        ann = text(intOrRound(edgeLabels[(edge.src, edge.dst)]), pointsize=edgeLabelSize, valign=y[end] + 1 < y[end-1] ? :bottom : :top)
        curves!(p, x, y, arrow=Plots.arrow(:closed), label=nothing)
        annotate!(p, [((x[end-1] + x[end]) / 2, (y[end-1] + y[end]) / 2, ann)])
    end

    for e in removedEdges
        x = [xs[e[1]], (xs[e[1]] + xs[e[2]]) / 2, xs[e[2]]]
        y = [ys[e[1]], (ys[e[1]] + ys[e[2]]) / 2, ys[e[2]]]
        ann = ["", text(intOrRound(edgeLabels[e[1], e[2]]), pointsize=edgeLabelSize, valign=:top), ""]
        plot!(p, x, y, text=ann, arrow=Plots.arrow(:closed), label=nothing)
    end
    
    scatter!(p, xs, ys, text=text.(labels, pointsize=nodeLabelSize, valign=:bottom, halign=:left), label=nothing,)

    p
end

# maximize!(ModularFrame ; resources = Dict(IronOre => 420), lockedRecipes = lockedRecipes)

end
