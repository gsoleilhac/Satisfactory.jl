
function print_results(m, frac, nodeLabelSize, edgeLabelSize, T)
    x, y = m[:x], m[:y]

    println(termination_status(m))
    println("$T : ", JuMP.value(x[T]))
    println("Obj : ", round(objective_value(m), digits=3), "\n")

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
    edgeProducts = Dict{Tuple{Int, Int}, String}()
    removedEdges = Tuple{Int, Int}[]
    
    for (r1, used1) in returnedRecipes, (r2, used2) in returnedRecipes
        for (p1, qty1) in r1.out, (p2, qty2) in r2.in
            if p1 == p2
                add_edge!(g, indices[r1], indices[r2])
                push!(edgeLabels, (indices[r1], indices[r2]) => min(qty1 * used1, qty2 * used2))
                push!(edgeProducts, (indices[r1], indices[r2]) => string(p1))
                if LightGraphs.is_cyclic(g)
                    rem_edge!(g, indices[r1], indices[r2])
                    println("removed acyclic edge ", r1, " => ", r2, " : ", intOrRound(min(qty1 * used1, qty2 * used2)))
                    push!(removedEdges, (indices[r1], indices[r2]))
                end
            end
        end
    end

    labels = [r.name  * "(" * intOrRound(used) * ")" for (r, used) in returnedRecipes]
    for (i, (r, used)) in enumerate(returnedRecipes)
        x = findfirst(y -> y[1] == T, r.out)
        if x !== nothing
            labels[i] = labels[i] * " => " * intOrRound(r.out[x][2] * used)
        end
    end
    xs, ys, edge2path = LayeredLayouts.solve_positions(LayeredLayouts.Zarate(time_limit=LayeredLayouts.Dates.Second(0)), g)
    p = plot(showaxis=false, ticks=false, xlims = (0.5, maximum(xs) + 2.), dpi = 300)
    
    for (edge, path) in edge2path
        x, y = path
        ann = text(edgeProducts[(edge.src, edge.dst)] * "\n" * intOrRound(edgeLabels[(edge.src, edge.dst)]), pointsize=edgeLabelSize, valign=y[end] + 1 < y[end-1] ? :bottom : :top)
        curves!(p, x, y, arrow=Plots.arrow(:closed), label=nothing)
        annotate!(p, [((x[end-1] + 0.4 * (x[end] - x[end-1])), (y[end-1] + 0.4 * (y[end] - y[end-1])), ann)])
    end

    for e in removedEdges
        x = [xs[e[1]], (xs[e[1]] + xs[e[2]]) / 2, xs[e[2]]]
        y = [ys[e[1]], (ys[e[1]] + ys[e[2]]) / 2 + 0.15, ys[e[2]]]
        ann = text(intOrRound(edgeLabels[e[1], e[2]]), pointsize=edgeLabelSize, valign=:top)
        curves!(p, x, y, arrow=Plots.arrow(:closed), label=nothing)
        annotate!(p, [((x[end-1] + x[end]) / 2, (y[end-1] + y[end]) / 2, ann)])
    end
    
    scatter!(p, xs, ys, text=text.(labels, pointsize=nodeLabelSize, valign=:bottom, halign=:left), label=nothing,)

    p |> display
end