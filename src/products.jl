abstract type Product end

for s in (:AIExpansionServer, :AILimiter, :AdaptiveControlUnit, :AlcladAluminumSheet, :AlienCarapace, :AlienDNACapsule, 
    :AlienOrgans, :AlienPowerMatrix, :AlienProtein, :AluminaSolution, :AluminumCasing, :AluminumIngot, :AluminumScrap, 
    :AssemblyDirectorSystem, :AutomatedWiring, :BallisticWarpDrive, :Battery, :Bauxite, :BiochemicalSculptor, :Biomass, 
    :BlackPowder, :BluePowerSlug, :Cable, :CateriumIngot, :CateriumOre, :CircuitBoard, :ClusterNobelisk, :Coal, 
    :CompactedCoal, :Computer, :Concrete, :CoolingSystem, :CopperIngot, :CopperOre, :CopperPowder, :CopperSheet, 
    :CrudeOil, :CrystalOscillator, :DarkMatterCrystal, :DarkMatterResidue, :Diamonds, :DissolvedSilica, 
    :ElectromagneticControlRod, :EmptyCanister, :EmptyFluidTank, :EncasedIndustrialBeam, :EncasedPlutoniumCell, 
    :EncasedUraniumCell, :ExcitedPhotonicMatter, :ExplosiveRebar, :FICSITCoupon, :Fabric, :FicsiteIngot, :FicsiteTrigon,
    :Ficsonium, :FicsoniumFuelRod, :FlowerPetals, :Fuel, :FusedModularFrame, :GasFilter, :GasNobelisk, :GreenPowerSlug, 
    :HatcherRemains, :HeatSink, :HeavyModularFrame, :HeavyOilResidue, :HighSpeedConnector, :HogRemains, :HomingRifleAmmo, 
    :IodineInfusedFilter, :IonizedFuel, :IronIngot, :IronOre, :IronPlate, :IronRebar, :IronRod, :Leaves, :Limestone, 
    :LiquidBiofuel, :MagneticFieldGenerator, :ModularEngine, :ModularFrame, :Motor, :Mycelia, :NeuralQuantumProcessor, 
    :NitricAcid, :NitrogenGas, :Nobelisk, :NonFissileUranium, :NuclearPasta, :NukeNobelisk, :PackagedAluminaSolution, 
    :PackagedFuel, :PackagedHeavyOilResidue, :PackagedIonizedFuel, :PackagedLiquidBiofuel, :PackagedNitricAcid, 
    :PackagedNitrogenGas, :PackagedOil, :PackagedRocketFuel, :PackagedSulfuricAcid, :PackagedTurbofuel, :PackagedWater, 
    :PetroleumCoke, :Plastic, :PlutoniumFuelRod, :PlutoniumPellet, :PlutoniumWaste, :PolymerResin, :PortableMiner, 
    :PowerShard, :PressureConversionCube, :PulseNobelisk, :PurplePowerSlug, :QuartzCrystal, :Quickwire, :RadioControlUnit, 
    :RawQuartz, :ReanimatedSAM, :ReinforcedIronPlate, :RifleAmmo, :RocketFuel, :Rotor, :Rubber, :SAM, :SAMFluctuator, 
    :SAMOre, :Screw, :ShatterRebar, :Silica, :SingularityCell, :SmartPlating, :SmokelessPowder, :SolidBiofuel, :SpitterRemains, 
    :Stator, :SteelBeam, :SteelIngot, :SteelPipe, :StingerRemains, :StunRebar, :Sulfur, :SulfuricAcid, :Supercomputer, 
    :SuperpositionOscillator, :ThermalPropulsionRocket, :TimeCrystal, :TurboMotor, :TurboRifleAmmo, :Turbofuel, :Uranium, 
    :UraniumFuelRod, :UraniumWaste, :VersatileFramework, :Water, :Wire, :Wood, :YellowPowerSlug)
    @eval struct $s <: Product end
    @eval export $s
end



struct ErrorProductNotFound <: Product
end
export ErrorProductNotFound