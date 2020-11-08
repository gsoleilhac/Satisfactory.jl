```julia
  >julia ]add https://github.com/gsoleilhac/Satisfactory.jl
  >julia using Satisfactory
```

|  |  |
|:-----:|:------:|
|` maximize!(ModularFrame ; resources = Dict(IronOre => 480))`| <img src="./examples/fig1.png"> |
|` maximize!(ModularFrame ; resources = Dict(p => 320 for p in (IronOre, CopperOre)), alternates=["Ingot", "Wire"])`| <img src="./examples/fig2.png"> |
|` maximizeDiscrete!(Supercomputer, 1/3 ; resources = Dict(p => 300 for p in baseResources), alternates=["Wire", "Ingot"]) # only allows building to run at 0, 33, 66, or 100% efficiency`| <img src="./examples/fig3.png"> |
