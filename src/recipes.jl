@enum Building Smelter Constructor Assembler Manufacturer Refinery Miner Foundry WaterExtractor OilExtractor Packager Blender ParticleAccelerator ResourceWellExtractor

struct Recipe
    name::String
    out::Vector{Tuple{DataType, Float64}}
    in::Vector{Tuple{DataType, Float64}}
    building::Building
    duration::Float64
end

dataPath = joinpath(@__DIR__, "data.json")

function readData()
    data = JSON3.read(read(dataPath))

    _buildings = [data.buildings[b] for b in first.(filter(!isempty, unique(r.producedIn for r in values(data.recipes))))]
    _recipes = filter(x -> !isempty(x.producedIn), collect(values(data.recipes)))
    _products = unique(union((p.item for r in _recipes for p in r.products), (p.item for r in _recipes for p in r.ingredients)))
    
    classNameToProduct = Dict{String, Type{<:Product}}(data.items[p].className => nameToType(data.items[p].name) for p in _products)
    classNameToBuilding = Dict{String, Building}(b.className => nameToType(b.name) for b in _buildings)

    empty!(allRecipes)
    empty!(dictProductDependantRecipes)
    empty!(dictProductRecipes)
    empty!(baseRecipes)

    for r in _recipes
        out = [(classNameToProduct[p.item], p.amount * 60 / r.time) for p in r.products]
        in = [(classNameToProduct[p.item], p.amount * 60 / r.time) for p in r.ingredients]
        building = classNameToBuilding[only(r.producedIn)]
        push!(allRecipes, Recipe(r.name, out, in, building, r.time))
    end

    minerMK1 = data.miners.Build_MinerMk1_C
    for p in minerMK1.allowedResources
        product = classNameToProduct[p]
        qty = minerMK1.itemsPerCycle / minerMK1.extractCycleTime * 60
        push!(allRecipes, Recipe("$product", [(product, qty)], [], Miner, 60))
    end
    oilPump = data.miners.Build_OilPump_C
    for p in oilPump.allowedResources
        product = classNameToProduct[p]
        qty = oilPump.itemsPerCycle / oilPump.extractCycleTime * 60 / 1000
        push!(allRecipes, Recipe("$product", [(product, qty)], [], OilExtractor, 60))
    end

    push!(allRecipes, Recipe("Water", [(Water, 180)], [], WaterExtractor, 60))
    push!(allRecipes, Recipe("Nitrogen Gas", [(NitrogenGas, 60)], [], ResourceWellExtractor, 60))
    

    for r in allRecipes
        for (p, qty) in r.out
            push!(get!(dictProductRecipes, p, Set()), (r, qty))
        end
    end  
    for r in allRecipes
        for (p, qty) in r.in
            push!(get!(dictProductDependantRecipes, p, Set()), (r, qty))
        end
    end

    for p in subtypes(Product)
        if p in harvestedProducts
            dictProductRecipes[p] = Set()
        end
        if !haskey(dictProductDependantRecipes, p)
            dictProductDependantRecipes[p] = Set()
        end
        if !haskey(dictProductRecipes, p)
            @warn "No recipe found to make $p"
            dictProductRecipes[p] = Set()
        end
    end

    append!(baseRecipes, filter(x -> !occursin("Alternate", x.name), allRecipes))
    nothing
end

nameToType(s::AbstractString) = getfield(Satisfactory, Symbol(replace(s, r" |-|\." => ""))) # remove spaces, dashes and dots 

recipes(::Type{T}) where T <: Product = dictProductRecipes[T]
recipes(::T) where T <: Product = recipes(T)

dependantRecipes(::Type{T}) where T <: Product = dictProductDependantRecipes[T]
dependantRecipes(::T) where T <: Product = dictProductDependantRecipes(T)

import Base.show, Base.==, Base.hash
show(io::IO, r::Recipe) = print(io, "$(r.name)")
hash(r::Recipe, h::UInt) = hash(r.name, h)
==(r1::Recipe, r2::Recipe) = r1.name == r2.name
