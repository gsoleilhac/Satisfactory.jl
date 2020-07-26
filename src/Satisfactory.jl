module Satisfactory

using JuMP, CPLEX, DataFrames, InteractiveUtils, CSV

@enum Builing Smelter Constructor Assembler Manufacturer Refinery Miner Foundry WaterExtractor OilExtractor

include("items.jl")
include("recipes.jl")

function maximize!(::Type{T} ; resources::Dict{DataType, Int} = Dict(), lockedRecipes = String[], allowMultiRecipes = true) where T <: Product
    
    m = Model(CPLEX.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)] <= 10000)
    @variable(m, 0 <= y[r in _recipes] <= 10000)

    # @objective(m, Max, x[T] - 0.0000001 * sum(x[a] for a in subtypes(Product)))
    @objective(m, Max, x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T)) - 0.00001 * sum(y[r] for r in _recipes))
    # @objective(m, Max, x[T])

    # Link product variables to their recipes variables
    #   Can't have more of a product than we have recipes producing it
    for p in subtypes(Product)
        @constraint(m, x[p] == sum(qty * y[r] for (r, qty) in recipes(p)))
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
    for r in _recipes
        if r.name in lockedRecipes
            @constraint(m, y[r] == 0)
        end
    end

    JuMP.set_silent(m)
    optimize!(m);

    println(termination_status(m))
    println(round(objective_value(m), digits=3), "\n")

    println("Products : ")
    for p in subtypes(Product)
        production = getvalue(x[p])
        if production > 0
            println(p, " : ", round(production, digits=3))
        end
    end

    println("\nRecipes : ")
    for r in _recipes
        used = getvalue(y[r])
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
        end
    end

    return
end


# export all
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

unlocked = [
    "Alternate: Wet Concrete", "Alternate: Polymer Resin", "Alternate: Recycled Rubber", "Alternate: Pure Copper Ingot", # Refinery
    "Alternate: Steel Rod", "Alternate: Steel Screw", "Alternate: Iron Wire", # Constructor
    "Alternate: Encased Industrial Pipe", "Alternate: Bolted Frame", "Alternate: Coated Iron Plate", "Alternate: Copper Rotor",  #Assembler
    "Alternate: Quickwire Stator", "Alternate: Steel Rotor", "Alternate: Silicone Circuit Board", "Alternate: Cheap Silica", "Alternate: Compacted Coal", #Assembler
    "Alternate: Automated Speed Wiring" #Manufacturer
    ]
lockedRecipes = setdiff(map(r -> r.name, filter(r -> occursin("Alternate:", r.name), _recipes)), unlocked)

maximize!(ModularFrame ; resources = Dict(IronOre => 420), lockedRecipes = lockedRecipes)

end
