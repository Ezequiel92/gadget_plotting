############################################################################################
# Julia module for creating plots, GIFs, and videos from the data 
# produced by GAGET2/3/4 simulations. 
############################################################################################

module GADGETPlotting

using GadgetIO, GadgetUnits, SPHtoGrid, SPHKernels
using Unitful, UnitfulAstro
using Plots, LaTeXStrings, StatsPlots.PlotMeasures, AverageShiftedHistograms, GLM
using Glob, FileIO, VideoIO, DelimitedFiles, Accessors, ProgressMeter

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 3
end

"Hₒ = 100 km s^(-1) Mpc^(-1) in Gyr^(-1)"
const HUBBLE_CONST = 0.102201

"""
Solar metallicity.

M. Asplund et al. (2009). The Chemical Composition of the Sun. Annual Review of Astronomy 
and Astrophysics, 47(1), 481–522. https://doi.org/10.1146/annurev.astro.46.060407.145222
"""
const SOLAR_METALLICITY = 0.0134

"""
Slope, intercept and unit of area density for the Kennicutt-Schmidt law.

R. C. Kennicutt (1998). The Global Schmidt Law in Star-forming Galaxies. The Astrophysical 
Journal, 498(2), 541-552. https://doi.org/10.1086/305588
"""
const KENNICUTT98_SLOPE = 1.4
const KENNICUTT98_INTERCEPT = 2.5e-4 * (UnitfulAstro.Msun / UnitfulAstro.yr / UnitfulAstro.kpc^2)
const KENNICUTT98_RHO_UNIT = 1.0 * UnitfulAstro.Msun / UnitfulAstro.pc^2

include("auxiliary.jl")
include("data_acquisition.jl")
include("plotting.jl")
include("pipelines.jl")
 
export 
    # Plotting functions ###################################################################
    scatterGridPlot,                              
    densityMapPlot,
    starMapPlot,
    gasStarEvolutionPlot,
    CMDFPlot,
    birthHistogramPlot,
    timeSeriesPlot,
    scaleFactorSeriesPlot,
    redshiftSeriesPlot,
    compareSimulationsPlot,
    densityHistogramPlot,
    densityProfilePlot,
    metallicityProfilePlot,
    massProfilePlot,
    sfrTxtPlot,
    temperatureHistogramPlot,
    rhoTempPlot,
    KennicuttSchmidtPlot,               
    # Pipeline functions ###################################################################           
    scatterGridPipeline,                
    densityMapPipeline,
    starMapPipeline,
    gasStarEvolutionPipeline,
    evolutionSummaryPipeline,
    compareSimulationsPipeline,
    densityHistogramPipeline,
    densityProfilePipeline,
    metallicityProfilePipeline,
    massProfilePipeline,
    CMDFPipeline,
    birthHistogramPipeline,
    sfrTxtPipeline,
    temperatureHistogramPipeline,
    rhoTempPipeline,
    KennicuttSchmidtPipeline,           
    # Auxiliary functions ##################################################################
    comparison,                     
    deep_comparison

end