############################################################################################
# PIPELINE FUNCTIONS.
############################################################################################

"""
    scatterGridPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the scatterGridPlot function as one image per snapshot, 
and then generate a GIF and video animating the images. 

# Arguments
- `base_name::String`: Base name of the snapshot files, 
  set in the GADGET variable SnapshotFileBase.
- `source_path::String`: Path to the directory containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "scatter_grid"`: Path to the output directory. The images will 
  be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX 
  is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  GR backend can be used, namely ".pdf", ".ps", ".svg" and ".png". 
"""
function scatterGridPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64; 
    output_path::String = "scatter_grid",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the scatter plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.                     
    animation = @animate for (number, snapshot) in zip(snap_numbers, snap_files)

        positions = positionData(
            snapshot; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )

        figure = scatterGridPlot(positions)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    gif(
        animation, 
        joinpath(output_path, anim_name * ".gif"), 
        fps = frame_rate, 
        show_msg = false
    )

    # Make the video.
    makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    densityMapPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the densityMapPlot function as one image per snapshot, 
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base name of the snapshot files, 
  set in the GADGET variable SnapshotFileBase.
- `source_path::String`: Path to the directory containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "density_map"`: Path to the output directory. The images will 
  be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX 
  is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `plane::String = "All"`: Indicates which plane will be plotted. 
  "XY" -> XY plane alone.
  "XZ" -> XZ plane alone.
  "YZ" -> YZ plane alone.
  "All" -> The three planes in a single 1x3 figure.
- `axes::Bool = false`: If true, the axes passing through (0.0, 0.0) are drawn. If false, 
  no axes are drawn.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the 
  GR backend can be used, namely ".pdf", ".ps", ".svg" and ".png". 
"""
function densityMapPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "density_map",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    plane::String = "All",
    axes::Bool = false,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)

    snap_files = @view sim["snap_files"][1:step:end]  
    snap_numbers = @view sim["numbers"][1:step:end]  

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Generate and store the plots.                      
    animation = @animate for (number, snapshot) in zip(snap_numbers, snap_files)

        pos = positionData(snapshot; sim_cosmo, filter_function, box_size, length_unit)
        mass = massData(snapshot, "gas"; sim_cosmo, filter_function)

        density_unit = mass["unit"] / length_unit^3

        density = densityData(snapshot; sim_cosmo, filter_function, density_unit)
        hsml = hsmlData(snapshot; sim_cosmo, filter_function, length_unit)

        figure = densityMapPlot(pos, mass, density, hsml; plane, axes)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

    end

    # Make the GIF.
    gif(
        animation, 
        joinpath(output_path, anim_name * ".gif"), 
        fps = frame_rate, 
        show_msg = false
    )

    # Make the video.
    makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    starMapPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the starMapPlot function as one image per snapshot, 
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base name of the snapshot files, 
  set in the GADGET variable SnapshotFileBase.
- `source_path::String`: Path to the directory containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "star_map"`: Path to the output directory. The images will 
  be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX 
  is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `plane::String = "All"`: Indicates which plane will be plotted. 
  "XY" -> XY plane alone.
  "XZ" -> XZ plane alone.
  "YZ" -> YZ plane alone.
  "All" -> The three planes in a single 1x3 figure.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `axes::Bool = false`: If true, the axes passing through (0.0, 0.0) are drawn. If false, 
  no axes are drawn.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the 
  GR backend can be used, namely ".pdf", ".ps", ".svg" and ".png". 
"""
function starMapPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "star_map",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    plane::String = "All",
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    box_factor::Float64 = 1.0, 
    axes::Bool = false,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,  
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)

    snap_files = @view sim["snap_files"][1:step:end]
    snap_numbers = @view sim["numbers"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the star map plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.                     
    animation = @animate for (number, snapshot) in zip(snap_numbers, snap_files)

        pos = positionData(snapshot; sim_cosmo, filter_function, box_size, length_unit)

        figure = starMapPlot(pos; plane, box_factor, axes)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    gif(
        animation, 
        joinpath(output_path, anim_name * ".gif"), 
        fps = frame_rate, 
        show_msg = false,
    )

    # Make the video.
    makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    gasStarEvolutionPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the gasStarEvolutionPlot for the last snapshot as one image and 
generate a GIF and a video animating the whole evolution for all snapshots. 
                                
# Arguments
- `base_name::String`: Base name of the snapshot files, 
  set in the GADGET variable SnapshotFileBase.
- `source_path::String`: Path to the directory containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "gas_star_evolution"`: Path to the output directory. 
  The image will be stored in `output_path`/images/ and will be named 
  `base_name`_XXX`format` where XXX is the number of the last snapshot. 
  The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr`: Unit of mass/time to 
  be used in the output, all available time and mass units in Unitful and UnitfulAstro 
  can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the 
  GR backend can be used, namely ".pdf", ".ps", ".svg" and ".png". 
"""
function gasStarEvolutionPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "gas_star_evolution",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_series = timeSeriesData(
        sim["snap_files"]; 
        sim_cosmo, 
        filter_function, 
        time_unit, 
        sfr_unit,
    ) 

    snap_files = @view sim["snap_files"][1:step:end]
    snap_numbers = @view sim["numbers"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    temp_path = mkpath(joinpath(output_path, "TEMP"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the gas-star-evolution plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.   
    data_iter = enumerate(zip(snap_numbers, snap_files))                 
    animation = @animate for (i, (number, snapshot)) in data_iter

        positions = positionData(
            snapshot; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )

        figure = gasStarEvolutionPlot(1 + step * (i - 1), time_series, positions)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(temp_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    gif(
        animation, 
        joinpath(output_path, anim_name * ".gif"), 
        fps = frame_rate, 
        show_msg = false,
    )

    # Make the video.
    makeVideo(temp_path, format, output_path, anim_name, frame_rate)

    # Move the last figure out of the temporary directory.
    mv(
        joinpath(temp_path, base_name * "_" * snap_numbers[end] * format),
        joinpath(output_path, anim_name * format),
        force = true,
    )

    # Delete the temporary directory and all its contents.
    rm(temp_path, recursive = true)

    return nothing
end

"""
    CMDFPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the CMDFPlot function as one image per snapshot, if there are stars 
present, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "CMDF"`: Path to the output directory. The images will be stored 
  in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX is the 
  number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `x_norm::Bool = false`: If the x axis will be normalized to its maximum value. 
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function CMDFPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "CMDF",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    x_norm::Bool = false,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the CMDF plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        header = read_header(snapshot)
        
        if header.nall[5] != 0
            mass_data = massData(snapshot, "stars"; sim_cosmo, filter_function)
            z_data = zData(snapshot, "stars"; sim_cosmo, filter_function)

            figure = CMDFPlot(
                mass_data, 
                z_data,
                time * time_unit; 
                bins = 50, 
                x_norm,
            )

            Base.invokelatest(
                savefig, 
                figure, 
                joinpath(img_path, base_name * "_" * number * format),
            )

        end

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    CMDFPipeline(
        base_name::Vector{String},
        source_path::Vector{String},
        anim_name::String,
        frame_rate::Int64,
        labels::Array{String, 2}; 
        <keyword arguments>
    )::Nothing

Save the results of the CMDFPlot function for several simulations as one image per snapshot,
if there are stars present, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::Vector{String}`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::Vector{String}`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `labels::Array{String, 2}`: Labels for the different simulations.
- `output_path::String = "CMDF"`: Path to the output directory. The images will be stored 
  in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX is the 
  ordinal of the frame. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `x_norm::Bool = false`: If the x axis will be normalized to its maximum value. 
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function CMDFPipeline(
    base_name::Vector{String},
    source_path::Vector{String},
    anim_name::String,
    frame_rate::Int64,
    labels::Array{String, 2};
    output_path::String = "CMDF",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    x_norm::Bool = false,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim_data = [getSnapshotPaths(base_name[i], path)["snap_files"]
                for (i, path) in enumerate(source_path)]
    # Time stamps (they should be the same for every dataset).
    time_data = timeSeriesData(sim_data[1]; sim_cosmo, filter_function, time_unit)
    times = @view time_data["clock_time"][1:step:end]

    # Length of the shortest simulation.
    min_len = minimum(length.(sim_data))
    # Trim longer simulations so all have the same length, 
    # and change their shape to facilitate processing.
    trim_matrix = hcat(map(x -> getindex(x, 1:min_len), sim_data)...)
    snap_files = eachrow(trim_matrix[1:step:end, :])

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))
    
    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the CMDF plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = enumerate(zip(times, snap_files))
    # animation = @animate 
    for (i, (time, snapshots)) in data_iter
        
        headers = read_header.(snapshots)
        num_stars = getindex.(getfield.(headers, :nall), 5)

        if all(num_stars .!= 0)
    
            masses = massData.(snapshots, "stars"; sim_cosmo, filter_function)
            metallicities = zData.(snapshots, "stars"; sim_cosmo, filter_function) 

            figure = CMDFPlot(
                masses, 
                metallicities,
                time * time_unit,
                labels;
                bins = 50, 
                x_norm,
            )

            Base.invokelatest(
                savefig, 
                figure, 
                joinpath(img_path, "frame_" * string(step * (i - 1)) * format),
            )

        end

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    birthHistogramPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the birthHistogramPlot function as one image per snapshot, if there are 
stars present, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "birth_histogram"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where 
  XXX is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function birthHistogramPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "birth_histogram",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the birth histograms... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = enumerate(zip(snap_numbers, snap_files))
    # animation = @animate          
    for (i, (number, snapshot)) in data_iter

        header = read_header(snapshot)

        if header.nall[5] != 0
            nursery = birthPlace(
                1 + step * (i - 1), 
                sim["snap_files"], 
                time_data["clock_time"],
                time_data["units"]["time"];
                sim_cosmo, 
                filter_function,
                length_unit, 
                time_unit = time_data["units"]["time"],
            )

            figure = birthHistogramPlot(nursery, bins = 50)

            Base.invokelatest(
                savefig, 
                figure, 
                joinpath(img_path, base_name * "_" * number * format),
            )
        end

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    evolutionSummaryPipeline(
        base_name::String,
        source_path::String,
        fig_name::String; 
        <keyword arguments>
    )::Nothing

Produce up to three figures summarizing the time evolution of the simulation.

The plotted parameters are the number of particles, the total mass, the baryonic 
fractional mass and the star formation rate (SFR), the first three for gas and stars.
If the simulation is Newtonian, only one figure is produced (parameters vs. time),
but if the simulation is cosmological, three figures are produced (parameters vs. time,
parameters vs. scale factor and parameters vs. redshift).

Args:
- `base_name::String`: Base name of the snapshot files, 
  set in the GADGET variable SnapshotFileBase.
- `source_path::String`: Path to the directory containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `fig_name::String`: Base name for the figures. The images will be named
  `fig_name`_vs_XXX`format` where XXX is 'time', 'redshift' or 'scale_factor'.
- `output_path::String = "evolution_summary"`: Path to the output directory. The images 
  will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `mass_factor::Int64 = 0`: Numerical exponent to scale the mass, e.g. if mass_factor = 10 
  the corresponding axis will be scaled by 10^10.
- `number_factor::Int64 = 0`: Numerical exponent to scale the number of particles, 
  e.g. if number_factor = 4 the corresponding axis will be scaled by 10^4.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr`: Unit of mass/time to 
  be used in the output, all available time and mass units in Unitful and UnitfulAstro 
  can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function evolutionSummaryPipeline(
    base_name::String,
    source_path::String,
    fig_name::String;
    output_path::String = "evolution_summary",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    mass_factor::Int64 = 0,
    number_factor::Int64 = 0,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr,
    format::String = ".png",
)::Nothing

    snap_files = getSnapshotPaths(base_name, source_path)

    # Create a directory to save the plots, if it doesn't exist.
    mkpath(output_path)

    time_series = timeSeriesData(
                    snap_files["snap_files"]; 
                    sim_cosmo, 
                    filter_function,
                    mass_unit, 
                    time_unit, 
                    sfr_unit,
                )

    # Parameters vs. time. 
    figure_t = timeSeriesPlot(time_series; mass_factor, number_factor)
    Base.invokelatest(
        savefig, 
        figure_t, 
        joinpath(output_path, fig_name * "_vs_time" * format),
    )

    if sim_cosmo == 1

        # Parameters vs. scale factor. 
        figure_a = scaleFactorSeriesPlot(time_series;mass_factor, number_factor)
        Base.invokelatest(
            savefig, 
            figure_a, 
            joinpath(output_path, fig_name * "_vs_scale_factor" * format),
        )

        # Parameters vs. redshift. 
        figure_z = redshiftSeriesPlot(time_series; mass_factor, number_factor)
        Base.invokelatest(
            savefig, 
            figure_z, 
            joinpath(output_path, fig_name * "_vs_redshift" * format),
        )

    end

    return nothing
end

"""
    compareSimulationsPipeline(
        base_name::Vector{String},
        source_path::Vector{String},
        labels::Array{String, 2},
        fig_name::String,
        x_quantity::String,
        y_quantity::String; 
        <keyword arguments>
    )::Nothing

Make a figure comparing `y_quantity` vs. `x_quantity` for several simulations.

`x_quantity` and `y_quantity` can be any magnitude used in the timeSeriesData 
function, namely:

- "scale_factor"                  
- "redshift"                  
- "clock_time" (Physical time)
- "sfr" (SFR) 			              
- "sfr_prob" (SFR probability - Not normalized) 			           
- "gas_number" (Gas particle number) 	            
- "dm_number" (Dark matter particle number)		               
- "star_number" (Star number)         
- "gas_mass" (Total gas mass)               
- "dm_mass" (Total dark matter mass)	            
- "star_mass" (Total star mass)	
- "gas_density" (Total gas density)	               
- "gas_frac" (Gas fraction)		                
- "dm_frac" (Dark matter fraction)		                
- "star_frac" (Star fraction)	                   
- "gas_bar_frac" (Baryonic gas fraction)                  
- "star_bar_frac" (Baryonic star fraction)

# Arguments
- `base_name::Vector{String}`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::Vector{String}`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `labels::Array{String, 2}`: Labels for the different simulations, e.g. [label1 label2 ...].
- `fig_name::String`: Base name for the figure. The file will be named
  `fig_name`_`y_quantity`_vs_`x_quantity` `format`.
- `x_quantity::String`: Physical magnitude for the x axis. 
- `y_quantity::String`: Physical magnitude for the y axis.
- `output_path::String = "compare_simulations"`: Path to the output directory. The images 
  will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `title::String = ""`: Title for the figure. If an empty string is given, no title is 
  printed.
- `x_factor::Int64 = 0`: Numerical exponent to scale the `x_quantity`, e.g. if x_factor = 10 
  the corresponding axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `y_factor::Int64 = 0`: Numerical exponent to scale the `y_quantity`, e.g. if y_factor = 10 
  the corresponding axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `scale::Vector{Symbol} = [:identity, :identity]`: Scaling to be used for the x 
  and y axes. The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `smooth_data::Bool = false`: If true a smoothing window with no weighs is applied to 
  the y data. If false (the default) no transformation occurs.
- `bins::Int64 = 0`: Number of subdivisions for the smoothing of the data, only relevant if
  `smooth_data = true`. 
- `legend_pos::Symbol = :bottomright`: Position of the legend, e.g. :topleft.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used, 
  e.g. UnitfulAstro.Msun.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used, 
  e.g. UnitfulAstro.Myr.
- `sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr`: Unit of mass/time to 
  be used in the output, all available time and mass units in Unitful and UnitfulAstro 
  can be used, e.g. UnitfulAstro.Msun/UnitfulAstro.yr.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png".  
"""
function compareSimulationsPipeline(
    base_name::Vector{String},
    source_path::Vector{String},
    labels::Array{String, 2},
    fig_name::String,
    x_quantity::String,
    y_quantity::String;
    output_path::String = "compare_simulations",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    title::String = "",
    x_factor::Int64 = 0,
    y_factor::Int64 = 0,
    scale::Vector{Symbol} = [:identity, :identity],
    smooth_data::Bool = false, 
    bins::Int64 = 50,
    legend_pos::Symbol = :bottomright,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr,
    format::String = ".png",
)::Nothing

    time_series = [timeSeriesData(
                        getSnapshotPaths(name, path)["snap_files"]; 
                        sim_cosmo,
                        filter_function, 
                        mass_unit, 
                        time_unit, 
                        sfr_unit,
                    ) for (name, path) in zip(base_name, source_path)]

    # Create a directory to store the figure, if it doesn't exist.
    mkpath(output_path)

    # `y_quantity` vs. `x_quantity` plot.  
    figure = compareSimulationsPlot(
        time_series,
        x_quantity,
        y_quantity,
        labels;
        title,
        x_factor,
        y_factor,
        scale,
        smooth_data,
        bins,
        legend_pos,
    )
    
    Base.invokelatest(
        savefig, 
        figure, 
        joinpath(output_path, fig_name * "_" * y_quantity * "_vs_" * x_quantity * format),
    )

    return nothing
end

"""
    densityHistogramPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the densityHistogramPlot function as one image per snapshot, 
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "density_histogram"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where 
  XXX is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `factor::Int64 = 0`: Numerical exponent to scale the density, e.g. if factor = 10 
  the y axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `density_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.kpc^3`: Unit of 
  density to be used in the output, all available density units in Unitful and UnitfulAstro 
  can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function densityHistogramPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "density_histogram",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    factor::Int64 = 0,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    density_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.kpc^3,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end]
    snap_numbers = @view sim["numbers"][1:step:end]
    times = @view time_data["clock_time"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the density histograms... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate 
    for (time, number, snapshot) in data_iter

        density = densityData(snapshot; sim_cosmo, filter_function, density_unit)

        figure = densityHistogramPlot(density, time * time_unit; factor)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    densityProfilePipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64,
        type::String; 
        <keyword arguments>
    )::Nothing

Save the results of the densityProfilePlot function as one image per snapshot,
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `output_path::String = "density_profile"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where 
  XXX is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `scale::Symbol = :identity`: Scaling to be used for the y axis.
  The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `factor::Int64 = 0`: Numerical exponent to scale the density, e.g. if factor = 10 
  the y axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function densityProfilePipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64,
    type::String;
    output_path::String = "density_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    factor::Int64 = 0,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end] 

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the density profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        positions = positionData(
            snapshot; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        mass = massData(snapshot, type; sim_cosmo, filter_function, mass_unit)

        figure = densityProfilePlot(
            positions,
            mass,
            time * time_unit;
            scale,
            bins,
            factor,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path * type, anim_name, frame_rate)

    return nothing
end

"""
    densityProfilePipeline(
        base_name::Vector{String},
        source_path::Vector{String},
        anim_name::String,
        frame_rate::Int64,
        type::String,
        labels::Array{String, 2}; 
        <keyword arguments>
    )::Nothing

Save the results of the densityProfilePlot function for several simulations as one image 
per snapshot, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::Vector{String}`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::Vector{String}`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `labels::Array{String, 2}`: Labels for the different simulations.
- `output_path::String = "density_profile"`: Path to the output directory. The images will 
  be stored in `output_path`/images/ and will be named frame_XXX`format` where XXX is the 
  ordinal of the frame. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `scale::Symbol = :identity`: Scaling to be used for the y axis.
  The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `factor::Int64 = 0`: Numerical exponent to scale the density, e.g. if factor = 10 
  the y axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function densityProfilePipeline(
    base_name::Vector{String},
    source_path::Vector{String},
    anim_name::String,
    frame_rate::Int64,
    type::String,
    labels::Array{String, 2};
    output_path::String = "density_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    factor::Int64 = 0,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing
    
    # Get the simulation data.
    sim_data = [getSnapshotPaths(base_name[i], path)["snap_files"] 
                for (i, path) in enumerate(source_path)]

    # Time stamps (they should be the same for every dataset).
    time_data = timeSeriesData(sim_data[1]; sim_cosmo, filter_function, time_unit)
    times = @view time_data["clock_time"][1:step:end]

    # Length of the shortest simulation.
    min_len = minimum(length.(sim_data))
    # Trim longer simulations so all have the same length, 
    # and change their shape to facilitate processing.
    trim_matrix = hcat(map(x -> getindex(x, 1:min_len), sim_data)...)
    snap_files = eachrow(trim_matrix[1:step:end, :])

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the density profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = enumerate(zip(times, snap_files))
    # animation = @animate 
    for (i, (time, snapshots)) in data_iter

        positions = positionData.(
            snapshots; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        masses = massData.(snapshots, type; sim_cosmo, filter_function, mass_unit)

        figure = densityProfilePlot(
            positions,
            masses,
            time * time_unit,
            labels;
            scale,
            bins,
            factor,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, "frame_"  * string(step * (i - 1)) * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    metallicityProfilePipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64,
        type::String; 
        <keyword arguments>
    )::Nothing

Save the results of the metallicityProfilePlot function as one image per snapshot,
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `output_path::String = "metallicity_profile"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where 
  XXX is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used.  Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function metallicityProfilePipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64,
    type::String;
    output_path::String = "metallicity_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end] 

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the metallicity profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        positions = positionData(
            snapshot; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        mass = massData(snapshot, type; sim_cosmo, filter_function)
        metallicities = zData(snapshot, type; sim_cosmo, filter_function)

        figure = metallicityProfilePlot(
            positions,
            mass,
            metallicities,
            time * time_unit;
            scale,
            bins,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    metallicityProfilePipeline(
        base_name::Vector{String},
        source_path::Vector{String},
        anim_name::String,
        frame_rate::Int64,
        type::String,
        labels::Array{String, 2}; 
        <keyword arguments>
    )::Nothing

Save the results of the metallicityProfilePlot function for several simulations as one 
image per snapshot, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::Vector{String}`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::Vector{String}`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `labels::Array{String,2}`: Labels for the different simulations.
- `output_path::String = "metallicity_profile"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named frame_XXX`format` where XXX is 
  the ordinal of the frame. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `scale::Symbol = :identity`: Scaling to be used for the y axis.
  The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used.  Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function metallicityProfilePipeline(
    base_name::Vector{String},
    source_path::Vector{String},
    anim_name::String,
    frame_rate::Int64,
    type::String,
    labels::Array{String, 2};
    output_path::String = "metallicity_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,  
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim_data = [getSnapshotPaths(base_name[i], path)["snap_files"] 
                for (i, path) in enumerate(source_path)]

    # Time stamps (they should be the same for every dataset).
    time_data = timeSeriesData(sim_data[1]; sim_cosmo, filter_function, time_unit)
    times = @view time_data["clock_time"][1:step:end]

    # Length of the shortest simulation.
    min_len = minimum(length.(sim_data))
    # Trim longer simulations so all have the same length, 
    # and change their shape to facilitate processing.
    trim_matrix = hcat(map(x -> getindex(x, 1:min_len), sim_data)...)
    snap_files = eachrow(trim_matrix[1:step:end, :])

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the metallicity profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = enumerate(zip(times, snap_files))
    # animation = @animate 
    for (i, (time, snapshots)) in data_iter

        positions = positionData.(
            snapshots; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        masses = massData.(snapshots, type; sim_cosmo, filter_function)
        metallicities = zData.(snapshots, type; sim_cosmo, filter_function)

        figure = metallicityProfilePlot(
            positions,
            masses,
            metallicities,
            time * time_unit,
            labels;
            scale,
            bins,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, "frame_" * string(step * (i - 1)) * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    massProfilePipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64,
        type::String; 
        <keyword arguments>
    )::Nothing

Save the results of the massProfilePlot function as one image per snapshot,
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `scale::Symbol = :identity`: Scaling to be used for the y axis.
  The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `output_path::String = "mass_profile"`: Path to the output directory. The images will be 
  stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX is 
  the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `factor::Int64 = 0`: Numerical exponent to scale the mass, e.g. if factor = 10 
  the y axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function massProfilePipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64,
    type::String;
    output_path::String = "mass_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    factor::Int64 = 0,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end] 

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the mass profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        positions = positionData(
            snapshot; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        mass = massData(snapshot, type; sim_cosmo, filter_function, mass_unit)

        figure = massProfilePlot(
            positions,
            mass,
            time * time_unit;
            scale,
            bins,
            factor,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    massProfilePipeline(
        base_name::Vector{String},
        source_path::Vector{String},
        anim_name::String,
        frame_rate::Int64,
        type::String,
        labels::Array{String, 2}; 
        <keyword arguments>
    )::Nothing

Save the results of the massProfilePlot function for several simulations as one image 
per snapshot, and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::Vector{String}`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::Vector{String}`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.
- `labels::Array{String, 2}`: Labels for the different simulations.
- `output_path::String = "mass_profile"`: Path to the output directory. The images will be 
  stored in `output_path`/images/ and will be named frame_XXX`format` where XXX is the 
  ordinal of the frame. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `scale::Symbol = :identity`: Scaling to be used for the y axis.
  The two options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `bins::Int64 = 100`: Number of subdivisions of the region to be used for the profile.
- `factor::Int64 = 0`: Numerical exponent to scale the mass, e.g. if factor = 10 
  the y axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `box_factor::Float64 = 1.0`: Multiplicative factor for the plotting region. 
  It will scale `positions["box_size"]` if vacuum boundary conditions were used, and
  it will scale `positions["box_size"] / 2` if periodic boundary conditions were used.
- `box_size::Unitful.Quantity = 1000UnitfulAstro.kpc`: Size of the plotting region 
  if vacuum boundary conditions were used. Its unit doesn't have to be the same 
  as `length_unit`.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png".  
"""
function massProfilePipeline(
    base_name::Vector{String},
    source_path::Vector{String},
    anim_name::String,
    frame_rate::Int64,
    type::String,
    labels::Array{String, 2};
    output_path::String = "mass_profile",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    scale::Symbol = :identity,
    step::Int64 = 1,
    bins::Int64 = 100,
    factor::Int64 = 0,
    box_factor::Float64 = 1.0,
    box_size::Unitful.Quantity = 1000UnitfulAstro.kpc,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim_data = [getSnapshotPaths(base_name[i], path)["snap_files"] 
                for (i, path) in enumerate(source_path)]

    # Time stamps (they should be the same for every dataset).
    time_data = timeSeriesData(sim_data[1]; sim_cosmo, filter_function, time_unit)
    times = @view time_data["clock_time"][1:step:end]

    # Length of the shortest simulation.
    min_len = minimum(length.(sim_data))
    # Trim longer simulations so all have the same length, 
    # and change their shape to facilitate processing.
    trim_matrix = hcat(map(x -> getindex(x, 1:min_len), sim_data)...)
    snap_files = eachrow(trim_matrix[1:step:end, :])

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the mass profiles... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = enumerate(zip(times, snap_files))
    # animation = @animate 
    for (i, (time, snapshots)) in data_iter

        positions = positionData.(
            snapshots; 
            sim_cosmo, 
            filter_function, 
            box_size, 
            length_unit,
        )
        masses = massData.(snapshots, type; sim_cosmo, filter_function)

        figure = massProfilePlot(
            positions,
            masses,
            time * time_unit,
            labels;
            scale,
            bins,
            factor,
            box_factor,
        )

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, "frame_" * string(step * (i - 1)) * format),
        )

        next!(prog_bar)

    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    sfrTxtPipeline(
        snapshots::Vector{String},
        source_path::Vector{String},
        x_axis::Int64,
        y_axis::Vector{Int64}; 
        <keyword arguments>
    )::Nothing

Save the results of the sfrTxtPlot function as one image per simulation or one image 
per column depending on `comparison_type`.

# Warning 
This function takes a modified version of sfr.txt which is produced by a private version of 
GADGET3. GADGET4 produces a sfr.txt, but it is not compatible with this function.

# Arguments
- `snapshots::Vector{String}`: Path to the snapshot files, to get its headers.
- `source_path::Vector{String}`: Paths to the directories containing the sfr.txt files, 
  set in the GADGET variable OutputDir.
- `x_axis::Int64`: Column number for the x axis.
- `y_axis::Vector{Int64}`: Column numbers for the y axis.
- `output_path::String = "sfr_txt"`: Path to the output directory.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `comparison_type::Int64 = 0`: Selects which parameters (columns or simulations)
  will be compared:
  0 -> Different columns are compared, for a single simulation (one plot per simulation).
  1 -> Different simulations are compared, using the same column (one plot per column).
- `title::Vector{String} = String[]`: Titles for the figures. If an empty string is given,
  no title is printed.
- `names::Vector{String} = String[]`: Names for the files. If an empty string is given, the 
  images will be assigned a number given by the order of `source_path`.
- `labels::Union{Nothing, Array{String, 2}} = nothing`: Labels for the different 
  simulations. Only relevant if `comparison_type = 1`.
- `bins::Int64 = 0`: Number of subdivisions for the smoothing of the data. 
  The default is 0, i.e. no smoothing. It will apply equally to every figure produced.
- `scale::NTuple{2, Symbol} = (:identity, :identity)`: Scaling to be used for the x and y 
  axes. It will apply equally to every figure produced.
  The options are:
  :identity => no scaling.
  :log10 => logarithmic scaling.
- `x_factor::Int64 = 0`: Numerical exponent to scale the `x_quantity`, e.g. if x_factor = 10 
  the corresponding axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `y_factor::Int64 = 0`: Numerical exponent to scale the `y_quantity`, e.g. if y_factor = 10 
  the corresponding axis will be scaled by 10^10. The default is 0, i.e. no scaling.
- `min_filter::NTuple{2, Float64} = (-Inf, -Inf)`: Value filter for the x and y axes. 
  It will apply equally to every figure produced. If a value of the x data is lower 
  than min_filter[1], then it is deleted. Equivalently with the y axis and min_filter[2]. 
  The default is -Inf for both, i.e. no filtering.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr`: Unit of mass/time to 
  be used in the output, all available time and mass units in Unitful and UnitfulAstro 
  can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function sfrTxtPipeline(
    snapshots::Vector{String},
    source_path::Vector{String},
    x_axis::Int64,
    y_axis::Vector{Int64};
    output_path::String = "sfr_txt",
    sim_cosmo::Int64 = 0,
    comparison_type::Int64 = 0,
    title::Vector{String} = String[],
    names::Vector{String} = String[],
    labels::Union{Nothing, Array{String, 2}} = nothing,
    bins::Int64 = 0,
    scale::NTuple{2, Symbol} = (:identity, :identity),
    x_factor::Int64 = 0,
    y_factor::Int64 = 0,
    min_filter::NTuple{2, Float64} = (-Inf, -Inf),
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    sfr_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.yr,
    format::String = ".png",
)::Nothing

    # By default every figure has no title.
    if isempty(title)
        title = ["" for _ in eachindex(source_path)]
    end

    # By default every figure has a number as its name.
    if isempty(names)
        names = [string(i - 1) for i in eachindex(source_path)]
    end

    # Create a directory to save the plots, if it doesn't exist.
    mkpath(output_path)

    sfr_data = [
        sfrTxtData(source, snap; sim_cosmo, mass_unit, time_unit, sfr_unit) 
        for (source, snap) in zip(source_path, snapshots)
    ]

    if comparison_type == 0
        @inbounds for (i, source) in enumerate(source_path)

            figure = sfrTxtPlot(
                sfr_data[i], 
                x_axis, 
                y_axis;
                title = title[i], 
                bins, 
                scale,
                x_factor, 
                y_factor, 
                min_filter,
            )

            Base.invokelatest(
                savefig, 
                figure, 
                joinpath(output_path, names[i] * format),
            )

        end
    else 
        @inbounds for (i, column) in enumerate(y_axis)

            figure = sfrTxtPlot(
                sfr_data, 
                x_axis, 
                column,
                labels;
                title = title[i], 
                bins, 
                scale,
                x_factor, 
                y_factor, 
                min_filter,
            )

            Base.invokelatest(
                savefig, 
                figure, 
                joinpath(output_path, names[i] * format),
            )

        end
    end

    return nothing
end

"""
    temperatureHistogramPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the temperatureHistogramPlot function as one image per snapshot, 
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "temperature_histogram"`: Path to the output directory. The images 
  will be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where 
  XXX is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `temp_unit::Unitful.FreeUnits = Unitful.K`: Unit of temperature to be used in the 
  output, all available temperature units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function temperatureHistogramPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "temperature_histogram",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    temp_unit::Unitful.FreeUnits = Unitful.K,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function)
    time_unit = time_data["units"]["time"]

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))
    
    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Computing the temperature histograms... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        temp_data = tempData(snapshot; sim_cosmo, filter_function, temp_unit)

        figure = temperatureHistogramPlot(temp_data, time * time_unit, bins = 30)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)
        
    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    rhoTempPipeline(
        base_name::String,
        source_path::String,
        anim_name::String,
        frame_rate::Int64; 
        <keyword arguments>
    )::Nothing

Save the results of the rhoTempPlot function as one image per snapshot, 
and then generate a GIF and a video animating the images. 

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `anim_name::String`: File name of the generated video and GIF, without the extension.
- `frame_rate::Int64`: Frame rate of the output video and GIF.
- `output_path::String = "rho_vs_temp"`: Path to the output directory. The images will be 
  stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX is 
  the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `temp_unit::Unitful.FreeUnits = Unitful.K`: Unit of temperature to be used in the 
  output, all available temperature units in Unitful and UnitfulAstro can be used.
- `density_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.kpc^3`: Unit of 
  density to be used in the output, all available density units in Unitful and UnitfulAstro 
  can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function rhoTempPipeline(
    base_name::String,
    source_path::String,
    anim_name::String,
    frame_rate::Int64;
    output_path::String = "rho_vs_temp",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    temp_unit::Unitful.FreeUnits = Unitful.K,
    density_unit::Unitful.FreeUnits = UnitfulAstro.Msun / UnitfulAstro.kpc^3,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function)
    time_unit = time_data["units"]["time"]

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))
    
    # Progress bar.
    prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Generating the ρ vs T plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)
    # animation = @animate          
    for (time, number, snapshot) in data_iter

        temp_data = tempData(snapshot; sim_cosmo, filter_function, temp_unit)
        density_data = densityData(snapshot; sim_cosmo, filter_function, density_unit)

        figure = rhoTempPlot(temp_data, density_data, time * time_unit)

        Base.invokelatest(
            savefig, 
            figure, 
            joinpath(img_path, base_name * "_" * number * format),
        )

        next!(prog_bar)
        
    end

    # Make the GIF.
    # gif(
    #     animation, 
    #     joinpath(output_path, anim_name * ".gif"), 
    #     fps = frame_rate, 
    #     show_msg = false,
    # )

    # Make the video.
    # makeVideo(img_path, format, output_path, anim_name, frame_rate)

    return nothing
end

"""
    KennicuttSchmidtPipeline(
        base_name::String,
        source_path::String; 
        <keyword arguments>
    )::Nothing

Save the results of the KennicuttSchmidtPlot function as one image per snapshot.

It will produce output only for the snapshots that have enough young stars to produce 
at least five data points for the linear fitting.

# Arguments
- `base_name::String`: Base names of the snapshot files, set in the GADGET 
  variable SnapshotFileBase.
- `source_path::String`: Paths to the directories containing the snapshot files, 
  set in the GADGET variable OutputDir.
- `output_path::String = "Kennicutt_Schmidt"`: Path to the output directory. The images will 
  be stored in `output_path`/images/ and will be named `base_name`_XXX`format` where XXX 
  is the number of the snapshot. The GIF and the video will be stored in `output_path`.
- `sim_cosmo::Int64 = 0`: Value of the GADGET variable ComovingIntegrationOn: 
  0 -> Newtonian simulation (static universe).
  1 -> Cosmological simulation (expanding universe).
- `filter_function::Function = pass_all`: A function with the signature: 
  foo(snap_file::String, type::String)::Vector{Int64}. See pass_all() in `src/auxiliary.jl` 
  for an example. By default no particles are filtered.
- `step::Int64 = 1`: Step used to traverse the list of snapshots. The default is 1, 
  i.e. all snapshots will be plotted.
- `temp_filter::Unitful.Quantity = 3e4Unitful.K`: Maximum temperature allowed for the 
  gas particles.
- `age_filter::Unitful.Quantity = 100UnitfulAstro.Myr`: Maximum star age allowed for the 
  calculation of the SFR.
- `max_r::Unitful.Quantity = 1000UnitfulAstro.kpc`: Maximum distance up to which the 
  parameters will be calculated, with units.
- `bins::Int64 = 50`: Number of subdivisions of [0, `max_r`] to be used. 
  It has to be at least 5.
- `error_formating::String = "std_error"`: What type of error for the fitting results to 
  print. The options are:
  "std_error": `mean ± standard_error`.
  "conf_interval": `mean ± max(upper_95% - mean, mean - lower_95%)`.
- `time_unit::Unitful.FreeUnits = UnitfulAstro.Myr`: Unit of time to be used in the output, 
  all available time units in Unitful and UnitfulAstro can be used.
- `mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun`: Unit of mass to be used in the output, 
  all available mass units in Unitful and UnitfulAstro can be used.
- `temp_unit::Unitful.FreeUnits = Unitful.K`: Unit of temperature to be used in the 
  output, all available temperature units in Unitful and UnitfulAstro can be used.
- `length_unit::Unitful.FreeUnits = UnitfulAstro.kpc`: Unit of length to be used in the 
  output, all available length units in Unitful and UnitfulAstro can be used.
- `format::String = ".png"`: File format of the output figure. All formats supported by the
  pgfplotsx backend can be used, namely ".pdf", ".tex", ".svg" and ".png". 
"""
function KennicuttSchmidtPipeline(
    base_name::String,
    source_path::String;
    output_path::String = "Kennicutt_Schmidt",
    sim_cosmo::Int64 = 0,
    filter_function::Function = pass_all,
    step::Int64 = 1,
    temp_filter::Unitful.Quantity = 3e4Unitful.K,
    age_filter::Unitful.Quantity = 20UnitfulAstro.Myr,
    max_r::Unitful.Quantity = 1000UnitfulAstro.kpc,
    bins::Int64 = 50,
    error_formating::String = "std_error",
    time_unit::Unitful.FreeUnits = UnitfulAstro.Myr,
    mass_unit::Unitful.FreeUnits = UnitfulAstro.Msun,
    temp_unit::Unitful.FreeUnits = Unitful.K,
    length_unit::Unitful.FreeUnits = UnitfulAstro.kpc,
    format::String = ".png",
)::Nothing

    # Get the simulation data.
    sim = getSnapshotPaths(base_name, source_path)
    time_data = timeSeriesData(sim["snap_files"]; sim_cosmo, filter_function, time_unit)

    snap_files = @view sim["snap_files"][1:step:end] 
    snap_numbers = @view sim["numbers"][1:step:end] 
    times = @view time_data["clock_time"][1:step:end]

    # Create a directory to save the plots, if it doesn't exist.
    img_path = mkpath(joinpath(output_path, "images"))

     # Progress bar.
     prog_bar = Progress(
        length(snap_files), 
        dt = 0.5, 
        desc = "Generating the Kennicutt-Schmidt plots... ",
        color = :blue,
        barglyphs = BarGlyphs("|#  |"),
    )

    # Generate and store the plots.
    data_iter = zip(times, snap_numbers, snap_files)        
    for (time, number, snapshot) in data_iter

        header = read_header(snapshot)
        if header.nall[5] != 0

            # Gas masses.
            gas_mass_data = massData(snapshot, "gas"; sim_cosmo, filter_function, mass_unit)
            # Gas temperatures.
            temperature_data = tempData(snapshot; sim_cosmo, filter_function, temp_unit)
            # Stars masses.
            star_mass_data = massData(
                snapshot, 
                "stars"; 
                sim_cosmo, 
                filter_function, 
                mass_unit,
            )
            # Stars ages.
            age_data = ageData(snapshot, time * time_unit; sim_cosmo, filter_function)
            # Positions.
            pos_data = positionData(
                snapshot; 
                sim_cosmo, 
                filter_function,  
                length_unit,
            )

            figure = KennicuttSchmidtPlot(
                gas_mass_data,
                temperature_data,
                star_mass_data,
                age_data,
                pos_data,
                temp_filter,
                age_filter,
                max_r,
                time * time_unit;
                bins,
                error_formating,
            )

            if figure !== nothing
                # If there was enough data to make a fit.
                Base.invokelatest(
                    savefig, 
                    figure, 
                    joinpath(img_path, base_name * "_" * number * format),
                )
            end

        end

        next!(prog_bar)

    end

    return nothing
end