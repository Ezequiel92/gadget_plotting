# GADGET Plotting

Julia script for creating figures, GIFs and videos from the data produce by a GAGET3/4 simulation.

- It only works with the traditional output format (binary data) which is the default in GADGET3 (SnapFormat=1) and a compatibility option in GADGET4 (legacy format selected with SnapFormat=1 too).
- It is just a script intended to be included as is (`include("GADGETPlotting.jl")`), it is not a module nor a package.
- A small testing data set is provided in test_snapshots/.
- The testing script testing.jl shows examples for every function, how to import the script, and provides a sanity check, as it should run without errors.
- The dependencies are given by the Manifest.toml and Project.toml files.

## Functions

There are four tiers of functions:

- AUXILIARY FUNCTIONS: These are only for internal use. They compensate some lack of functionality in Base and other libraries GADGETPlotting.jl uses, e.g. [Unitful.jl](https://github.com/PainterQubits/Unitful.jl).
- DATA ACQUISITION FUNCTIONS: These are only for internal use. They take the raw data, apply some transformation and return it as a familiar data estructures.
- PLOTTING FUNCTIONS: These are only for internal use. They take data in the format outputted by the data acquisition functions and return plot objects.
- PIPELINE FUNCTIONS: These are the ones intended to be externally used. They take the location of the snapshot files, and configuration parameters, and produce a series of figures/gif/videos automatically. Some of these functions may produce by default a large number of images (but it can be configure to do less), and they may take a long time to run, especially if the function uses the `pgfplotsx` backend of [Plots.jl](https://github.com/JuliaPlots/Plots.jl).

NOTE: Despite what is mention above, being this a simple script, every function is exposed. So all can be used, as it is shown in testing.jl. Only two global constants and no data structures are defined (discounting what the dependencies may bring to the namespace).

## Documentation

Each function is documented within the script, where a docstring explains the functionality, the arguments and the returns.

For examples on how to use the functions refer to testing.jl, note that it expect the simple file structure present in this repo, namely:

    .
    ├── GADGETPlotting.jl 
    ├── testing.jl
    ├── Manifest.toml 
    └── Project.toml

## References

[GADGET2](https://wwwmpa.mpa-garching.mpg.de/gadget/)

[GADGET4](https://wwwmpa.mpa-garching.mpg.de/gadget4/)

## Warning

This script may break at any moment, and some functions are intended for data generated by GADGET3 which is not a publicly available code. So no guaranties are given.