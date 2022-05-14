
function maxModelLinear(::Type{T}; resources::Dict, alternates=String[], blacklist=String[], allowMultiRecipes=true) where {T<:Product}

    allowedRecipes = union(baseRecipes, filter(r -> any(alt -> occursin(alt, r.name), alternates), allRecipes))
    filter!(r -> !(r.name in blacklist), allowedRecipes)

    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)])
    @variable(m, 0 <= y[r in allRecipes])

    @objective(
        m,
        Max,
        x[T] - sum(qty * y[r] for (r, qty) in dependantRecipes(T))
        -
        1e-5 * sum(y[r] for r in allowedRecipes)
        # - 1e-5 * sum(y[r] for r in allRecipes if occursin("Alternate", r.name))
    )

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

    @constraint(m, [r in allRecipes; !(r in allowedRecipes)], y[r] == 0)

    return m, x, y
end

function maxModelMIP(::Type{T}, frac=1 / 4; resources::Dict, alternates=String[], blacklist=String[], allowMultiRecipes=true, minProductionThreshold=1) where {T<:Product}

    allowedRecipes = union(baseRecipes, filter(r -> any(alt -> occursin(alt, r.name), alternates), allRecipes))
    filter!(r -> !(r.name in blacklist), allowedRecipes)

    m = Model(Cbc.Optimizer)
    @variable(m, 0 <= x[p in subtypes(Product)])
    @variable(m, 0 <= y[r in allRecipes], Int)
    @variable(m, is_used[r in allRecipes], Bin)

    M = 100_000_000 / frac
    minProductionThreshold /= frac
    @constraint(m, [r in allRecipes], y[r] >= minProductionThreshold * is_used[r])
    @constraint(m, [r in allRecipes], y[r] <= M * is_used[r])

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

    @constraint(m, [r in allRecipes; !(r in allowedRecipes)], y[r] == 0)

    return m, x, y
end