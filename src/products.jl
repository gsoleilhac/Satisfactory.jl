abstract type Product end

for s in (:Limestone, :IronOre, :CopperOre, :CateriumOre, :Coal, :RawQuartz, :Sulfur, :Bauxite, :SAMOre, :Uranium, :Water, :CrudeOil, :AlienCarapace, :AlienOrgans, :GreenPowerSlug, :YellowPowerSlug, :PurplePowerSlug, :HeavyOilResidue, :Fuel, :LiquidBiofuel, :Turbofuel, :AluminaSolution, :SulfuricAcid, :Concrete, :IronIngot, :CopperIngot, :CateriumIngot, :SteelIngot, :AluminumIngot, :QuartzCrystal, :PolymerResin, :PetroleumCoke, :AluminumScrap, :Silica, :BlackPowder, :Wire, :Cable, :IronRod, :Screw, :IronPlate, :ReinforcedIronPlate, :CopperSheet, :AlcladAluminumSheet, :Plastic, :Rubber, :PackagedWater, :SteelPipe, :SteelBeam, :EncasedIndustrialBeam, :FlowerPetals, :CrystalOscillator, :EmptyCanister, :Fabric, :ModularFrame, :HeavyModularFrame, :Rotor, :Stator, :Motor, :Quickwire, :CircuitBoard, :Computer, :AILimiter, :HighSpeedConnector, :Supercomputer, :Battery, :HeatSink, :RadioControlUnit, :TurboMotor, :ElectromagneticControlRod, :UraniumPellet, :EncasedUraniumCell, :Beacon, :CompactedCoal, :Leaves, :Mycelia, :Wood, :Biomass, :PackagedOil, :PackagedHeavyOilResidue, :SolidBiofuel, :PackagedFuel, :PackagedLiquidBiofuel, :PackagedTurbofuel, :NuclearFuelRod, :Nobelisk, :GasFilter, :ColorCartridge, :RifleCartridge, :SpikedRebar, :IodineInfusedFilter, :PowerShard, :FICSITCoupon, :SmartPlating, :VersatileFramework, :AutomatedWiring, :ModularEngine, :AdaptiveControlUnit)
    @eval struct $s <: Product end
    @eval export $s
end