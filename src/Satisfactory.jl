module Satisfactory

using JuMP, Cbc, DataFrames, CSV, LightGraphs, LayeredLayouts, Plots
using InteractiveUtils: subtypes

include("products.jl") ; export Product #, subtypes(Product)
include("recipes.jl") ; export recipes, dependantRecipes, allRecipes
include("models.jl") ; export maxModelLinear, maxModelMIP
include("utils.jl")

export baseRecipes, baseResources, maxResources
export maximize!, maximizeDiscrete!

const baseRecipes = filter(x -> !occursin("Alternate", x.name), allRecipes)
const baseResources = (Limestone, IronOre, CopperOre, CateriumOre, Coal, RawQuartz, Sulfur, Bauxite, Uranium, Water, CrudeOil)
const maxResources = Dict(zip(baseResources, (52860, 70380, 28860, 11040, 31680, 10500, 3300, 7800, 1200, 100_000, 7500)))

function maximize!(::Type{T} ; resources::Dict, alternates = String[], 
    allowMultiRecipes = true, nodeLabelSize = 4, edgeLabelSize = 4) where T <: Product
    
    m, x, y = maxModelLinear(T ; resources, alternates, allowMultiRecipes)
    JuMP.set_silent(m)
    optimize!(m);
    print_results(m, 1., nodeLabelSize, edgeLabelSize, T)
end

function maximizeDiscrete!(::Type{T}, frac = 1/4 ; resources::Dict, alternates = String[], 
    allowMultiRecipes = true, nodeLabelSize = 4, edgeLabelSize = 4, minProductionThreshold = 1) where T <: Product
    
    m, x, y = maxModelMIP(T, frac ; resources, alternates, allowMultiRecipes, minProductionThreshold)
    JuMP.set_silent(m)
    optimize!(m);
    print_results(m, frac, nodeLabelSize, edgeLabelSize, T)
end

end
