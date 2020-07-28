struct Recipe
    name::String
    out::Vector{Tuple{DataType, Float64}}
    in::Vector{Tuple{DataType, Float64}}
    building::Building
    duration::Float64
end

recipes(::Type{T}) where T <: Product = dictProductRecipes[T]
recipes(::T) where T <: Product = recipes(T)

dependantRecipes(::Type{T}) where T <: Product = dictProductDependantRecipes[T]
dependantRecipes(::T) where T <: Product = dictProductDependantRecipes(T)

import Base.show, Base.==, Base.hash
show(io::IO, r::Recipe) = print(io, "$(r.name)")
hash(r::Recipe, h::UInt) = hash(r.name, h)
==(r1::Recipe, r2::Recipe) = r1.name == r2.name

# https://docs.google.com/spreadsheets/d/1nMw0y-i5aoAmsw2SLmIL-88ClzCc6nt2UqiLSGr2o6Q/edit#gid=0
# replace Filter with Gas Filter
# replace Cartridge with Rifle Cartridge
# replace Miner with Oil Extractor for Crude Oil
# divide all liquid quantities by 1000
# Fix quantities used for Plastic and Rubber
const allRecipes = Recipe[]
for row in eachrow(DataFrame(CSV.File(joinpath(@__DIR__, "recipes.txt"))))
    name, inputs, outputs, duration, buildings, _ = row

    (buildings == "Build Tool" || buildings == "Workshop") && continue

    in = Tuple{DataType, Float64}[]
    for x in split(inputs, ",")
        item, s_qty = match(r"(.*)\((\d*)\)", x).captures
        item = replace(item, r"\s|-|\." => "") # removes whitespaces, dots and dashes
        qty = parse(Float64, s_qty)
        type = eval(Symbol(item))
        push!(in, (type, qty / duration * 60))
    end

    out = Tuple{DataType, Float64}[]
    for x in split(outputs, ",")
        item, s_qty = match(r"(.*)\((\d*)\)", x).captures
        item = replace(item, r"\s|-|\." => "") # removes whitespaces, dots and dashes
        qty = parse(Float64, s_qty)
        type = eval(Symbol(item))
        push!(out, (type, qty / duration * 60))
    end

    building = if occursin("Miner", buildings)
        Miner
    elseif occursin("Smelter", buildings)
        Smelter
    elseif occursin("Refinery", buildings)
        Refinery
    elseif occursin("Constructor", buildings)
        Constructor
    elseif occursin("Assembler", buildings)
        Assembler
    elseif occursin("Manufacturer", buildings)
        Manufacturer
    elseif occursin("Foundry", buildings)
        Foundry
    elseif occursin("Oil Extractor", buildings)
        OilExtractor
    end

    if building == Miner || building == OilExtractor
        empty!(in)
        out = [(p, 2 * qty) for (p,qty) in out]
    end

    push!(allRecipes, Recipe(name, out, in, building, duration))
end
push!(allRecipes, Recipe("Water", [(Water, 120)], [], WaterExtractor, 6))

const dictProductRecipes = Dict(p => Set{Tuple{Recipe, Float64}}() for p in subtypes(Product))
for r in allRecipes
    for (p, qty) in r.out
        push!(dictProductRecipes[p], (r, qty))
    end
end  

const dictProductDependantRecipes = Dict(p => Set{Tuple{Recipe, Float64}}() for p in subtypes(Product))
for r in allRecipes
    for (p, qty) in r.in
        push!(dictProductDependantRecipes[p], (r, qty))
    end
end 