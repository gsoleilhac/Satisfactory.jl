module Satisfactory

using JuMP, CPLEX, DataFrames, InteractiveUtils, CSV, LightGraphs, GraphPlot

@enum Building Smelter Constructor Assembler Manufacturer Refinery Miner Foundry WaterExtractor OilExtractor

include("products.jl")
include("recipes.jl")

export maximize!, maximizeDiscrete!, recipes, dependantRecipes, allRecipes
for p in subtypes(Product)
    @eval export $(nameof(p))
end

function maximize!(::Type{T} ; 
    resources = Dict(), availableProducts = Dict(),
    lockedRecipes = String[], allowMultiRecipes = true) where T <: Product
    
    m = Model(CPLEX.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 10000)
    @variable(m, 0 <= y[r in allRecipes] <= 10000)

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 1e-6 * sum(r.duration * y[r] for r in allRecipes))

    # Link product variables to their recipes variables
    #   Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        @constraint(m, x[p] == sum(qty * y[r] for (r, qty) in recipes(p)) + get(availableProducts, p, 0))
        if !allowMultiRecipes
            @constraint(m, [y[r] for (r, qty) in recipes(p)] in SOS1()) # only use 1 recipe to produce a specific product
        end
    end

    # For each Product
    #   Make sure we have enough of that product for all recipes depending on it
    for p in subtypes(Product)
        @constraint(m, x[p] >= sum(qty * y[r] for (r, qty) in dependantRecipes(p)))
    end

    # If no limit is set for these resources, assume 0 by default
    get!.(Ref(resources), (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, SAMOre, Uranium, Water, CrudeOil), 0)
    for (r, v) in resources
        @constraint(m, x[r] <= v)
    end

    # Disallow use of locked recipes
    for r in allRecipes
        if r.name in lockedRecipes
            @constraint(m, y[r] == 0)
        end
    end

    JuMP.set_silent(m)
    optimize!(m);

    print_results(m, 1.)
end

function maximizeDiscrete!(::Type{T}, frac = 1/4 ; 
    resources = Dict(), availableProducts = Dict(),
    lockedRecipes = String[], allowMultiRecipes = true) where T <: Product
    
    m = Model(CPLEX.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 10000)
    @variable(m, 0 <= y[r in allRecipes] <= 10000, Int)

    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 1e-6 * sum(r.duration * y[r] for r in allRecipes))

    # Link product variables to their recipes variables
    #   Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        @constraint(m, x[p] == sum(frac * qty * y[r] for (r, qty) in recipes(p)) + get(availableProducts, p, 0))
        if !allowMultiRecipes
            @constraint(m, [y[r] for (r, qty) in recipes(p)] in SOS1()) # only use 1 recipe to produce a specific product
        end
    end

    # For each Product
    #   Make sure we have enough of that product for all recipes depending on it
    for p in subtypes(Product)
        @constraint(m, x[p] >= sum(frac * qty * y[r] for (r, qty) in dependantRecipes(p)) )
    end

    # If no limit is set for these resources, assume 0 by default
    get!.(Ref(resources), (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, SAMOre, Uranium, Water, CrudeOil), 0)
    for (r, v) in resources
        @constraint(m, x[r] <= v)
    end

    # Disallow use of locked recipes
    for r in allRecipes
        if r.name in lockedRecipes
            @constraint(m, y[r] == 0)
        end
    end

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

    buildGraph(returnedProducts, returnedRecipes)
end

function buildGraph(returnedProducts, returnedRecipes)
    g = SimpleDiGraph()
    add_vertices!(g, length(returnedRecipes))
    indices = Dict(r => i for (i, r) in enumerate(first.(returnedRecipes)))

    w = []
    
    for (r1, _) in returnedRecipes, (r2, used) in returnedRecipes
        for p1 in first.(r1.out), (p2, qty) in r2.in
            if p1 == p2
                add_edge!(g, indices[r1], indices[r2])
                push!(w, round(qty * used, digits=3))
            end
        end
    end

    labels = [r.name  * "(" * string(round(used, digits=3)) * ")" for (r, used) in returnedRecipes]

    @show w
    gplot(g, nodelabel = labels, edgelabel=w, edgelabeldistx=0.1, edgelabeldisty=0.1)
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
