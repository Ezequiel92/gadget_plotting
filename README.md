# 🌌 GADGET Plotting

[![ForTheBadge built-with-science](http://forthebadge.com/images/badges/built-with-science.svg)](https://GitHub.com/Ezequiel92/) 

[![ForTheBadge made-with-julia](https://forthebadge.com/images/badges/made-with-julia.svg)](https://julialang.org)

[![Codecov](https://img.shields.io/codecov/c/github/Ezequiel92/GADGETPlotting?style=flat&logo=Codecov&labelColor=2B2D2F)](https://codecov.io/github/Ezequiel92/BiblographyFormatter?branch=main) [![GitHub Workflow Status](https://img.shields.io/github/workflow/status/Ezequiel92/GADGETPlotting/Continuous%20integration?style=flat&logo=GitHub&labelColor=2B2D2F)](https://github.com/Ezequiel92/GADGETPlotting/actions) [![GitHub](https://img.shields.io/github/license/Ezequiel92/GADGETPlotting?style=flat&logo=GNU&labelColor=2B2D2F)](https://github.com/Ezequiel92/GADGETPlotting/blob/main/LICENSE) [![Maintenance](https://img.shields.io/maintenance/yes/2021?style=flat&labelColor=2B2D2F)](mailto:lozano.ez@gmail.com)

Julia module for creating plots, GIFs, and videos from the data produced by GAGET2/3/4 simulations.

- It only works with the alternative (binary data) output format of GADGET2/3/4 (option `SnapFormat = 2`).
- It is a script inside a module, not a package. Only five global constants and no data structures are defined.
- A small testing data set is provided in `example/example_data/`.
- The script `example/run_examples.jl` shows how to import the main module, gives examples for every function, and provides a sanity check, as it should run as is without errors.
- The dependencies are given by the `Manifest.toml` and `Project.toml` files.

## 🖥️ Functions

There are four tiers of functions:

- Auxiliary functions (`src/auxiliary.jl`): These are only for internal use. All but `make_video` are pure functions that do soma data processing. Some of these are exported for testing purposes.
- Data acquisition functions (`src/data_acquisition.jl`): These are only for internal use. They take the location of the data files, apply some transformation (e.g. unit conversions) and return the data inside a familiar data structure.
- Plotting functions (`src/plotting.jl`): These are exported, but I do not recommend using them as is. If you insist in using them, read the [Plotting backends](https://github.com/Ezequiel92/GADGETPlotting#-plotting-backends) section below. These are pure functions that take data in the format outputted by the data acquisition functions and return plot objects. They do all the data processing necessary to create the plots, except unit conversions. They will plot using the units selected when the data acquisition functions were called.
- Pipeline functions (`src/pipelines.jl`): These are exported. These functions run a whole pipeline, from raw data to the final plot. They take the location of the snapshot files with some configuration parameters, and as a result, produce a series of plots/GIFs/videos. By default, some of these functions may generate a large number of images (but it can be configured to do less), and they may take a long time to run, especially if the function uses the `pgfplotsx` backend of [Plots.jl](https://github.com/JuliaPlots/Plots.jl).

## 🚨 Plotting backends

The plotting functions use different backends, which are activated within each function. So, to save the figures after a plotting function call, you have to use `Base.invokelatest(savefig, figure, location)` instead of `savefig(figure, location)` (as it is done in `example/example_plotting.jl`). The pipeline functions do this internally, so you can call them directly with no extra caveats. 

## 📘 Documentation

Each function is documented within the corresponding source file where a docstring explains the functionality, the arguments, and the returns.

Refer to `examples/` for how to use the functions. Note that the scripts there expect the simple file structure of this repo, namely:

    .
    ├── src
    │    ├── GADGETPlotting.jl 
    │    └── ...
    ├── examples   
    │    ├── example_data
    │    │    └── ...
    │    ├── run_examples.jl
    │    └── ...
    └── ...
    
More examples can be found in the repository [plotting_scripts](https://github.com/Ezequiel92/plotting_scripts).

## 🔗 References

[GADGET2](https://wwwmpa.mpa-garching.mpg.de/gadget/)

[GADGET4](https://wwwmpa.mpa-garching.mpg.de/gadget4/)

## 📣 Contact

[![image](https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white)](mailto:lozano.ez@gmail.com)

[![image](https://img.shields.io/badge/Microsoft_Outlook-0078D4?style=for-the-badge&logo=microsoft-outlook&logoColor=white)](mailto:lozano.ez@outlook.com)

## ⚠️ Warnings

- Some functions use data generated exclusively by GADGET3, which is not a publicly available code. See for example the documentation for the `sfr_txt_data` function.
- This script is written for personal use and may break at any moment. So, use it at your own risk.
