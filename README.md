# Satisfactory

```julia
    julia> using Satisfactory

    julia>  maximize!(ModularFrame ; resources = Dict(IronOre => 480))
    OPTIMAL
    23.163

    Products :
    IronIngot : 480.0
    IronOre : 480.0
    IronPlate : 115.818
    IronRod : 138.981
    ModularFrame : 23.164
    ReinforcedIronPlate : 34.745
    Wire : 301.126

    Recipes :
    Iron Plate
            input : IronIngot : 173.7265/min
            IronPlate : 115.8177/min
            5.791 Constructor
    Iron Rod
            input : IronIngot : 138.9812/min
            IronRod : 138.9812/min
            9.265 Constructor
    Iron Ore
            IronOre : 480.0/min
            8.0 Miner
    Iron Ingot
            input : IronOre : 480.0/min
            IronIngot : 480.0/min
            16.0 Smelter
    Modular Frame
            input : ReinforcedIronPlate : 34.7453/min IronRod : 138.9812/min
            ModularFrame : 23.1635/min
            11.582 Assembler
    Alternate: Stitched Iron Plate
            input : IronPlate : 115.8177/min Wire : 301.126/min
            ReinforcedIronPlate : 34.7453/min
            6.177 Assembler
    Alternate: Iron Wire
            input : IronIngot : 167.2922/min
            Wire : 301.126/min
            13.383 Constructor

    julia> unlocked = [
        "Alternate: Wet Concrete", "Alternate: Polymer Resin", "Alternate: Recycled Rubber", "Alternate: Pure Copper Ingot", # Refinery
        "Alternate: Steel Rod", "Alternate: Steel Screw", "Alternate: Iron Wire", # Constructor
        "Alternate: Encased Industrial Pipe", "Alternate: Bolted Frame", "Alternate: Coated Iron Plate", "Alternate: Copper Rotor",  #Assembler
        "Alternate: Quickwire Stator", "Alternate: Steel Rotor", "Alternate: Silicone Circuit Board", "Alternate: Cheap Silica", "Alternate: Compacted Coal", #Assembler
        "Alternate: Automated Speed Wiring" #Manufacturer
        ]
    julia> lockedRecipes = setdiff(map(r -> r.name, filter(r -> occursin("Alternate:", r.name), allRecipes)), unlocked)

    julia>  maximize!(ModularFrame ; resources = Dict(IronOre => 480), lockedRecipes = lockedRecipes)
    OPTIMAL
    19.999

    Products :
    IronIngot : 480.0
    IronOre : 480.0
    IronPlate : 180.0
    IronRod : 210.0
    ModularFrame : 20.0
    ReinforcedIronPlate : 30.0
    Screw : 360.0

    Recipes :
    Reinforced Iron Plate
            input : IronPlate : 180.0/min Screw : 360.0/min
            ReinforcedIronPlate : 30.0/min
            6.0 Assembler
    Screw
            input : IronRod : 90.0/min
            Screw : 360.0/min
            9.0 Constructor
    Iron Plate
            input : IronIngot : 270.0/min
            IronPlate : 180.0/min
            9.0 Constructor
    Iron Rod
            input : IronIngot : 210.0/min
            IronRod : 210.0/min
            14.0 Constructor
    Iron Ore
            IronOre : 480.0/min
            8.0 Miner
    Iron Ingot
            input : IronOre : 480.0/min
            IronIngot : 480.0/min
            16.0 Smelter
    Modular Frame
            input : ReinforcedIronPlate : 30.0/min IronRod : 120.0/min
            ModularFrame : 20.0/min
            10.0 Assembler

```