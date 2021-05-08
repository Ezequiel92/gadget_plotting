############################################################################################
# AUXILIARY FUNCTIONS.
############################################################################################

"""
    relative(
        p::Plots.Plot,
        rx::Float64,
        ry::Float64,
        rz::Union{Float64, Nothing} = nothing; 
        <keyword arguments>
    )::Union{NTuple{2, Float64}, NTuple{3, Float64}}
    
Give the absolute coordinates for a Plot, given the relative ones.

# Arguments 
- `p::Plots.Plot`: Plot for which the absolute coordinates will be calculated.
- `rx::Float64`: relative x coordinate, rx ∈ [0, 1].
- `ry::Float64`: relative y coordinate, ry ∈ [0, 1].
- `rz::Union{Float64,Nothing} = nothing`: relative z coordinate, rz ∈ [0, 1].
- `log::Union{NTuple{2, Bool}, NTuple{3, Bool}} = (false, false, false)` = If the x, y or
  z axis will be in a logarithmic scale.

# Returns
- A Tuple with the absolute coordinates: (x, y) or (x, y, z).
"""
function relative(
    p::Plots.Plot,
    rx::Float64,
    ry::Float64,
    rz::Union{Float64, Nothing} = nothing;
    log::Union{NTuple{2, Bool}, NTuple{3, Bool}} = (false, false, false),
)::Union{NTuple{2, Float64}, NTuple{3, Float64}}

    if log[1]
        xlims = log10.(Plots.xlims(p))
        ax = 10.0^(xlims[1] + rx * (xlims[2] - xlims[1]))
    else
        xlims = Plots.xlims(p)
        ax = xlims[1] + rx * (xlims[2] - xlims[1])
    end

    if log[2]
        ylims = log10.(Plots.ylims(p))
        ay = 10.0^(ylims[1] + ry * (ylims[2] - ylims[1]))
    else
        ylims = Plots.ylims(p)
        ay = ylims[1] + ry * (ylims[2] - ylims[1])
    end

    if rz === nothing

        return ax, ay

    else

        (
            length(log) == 3 || 
            error("If you have 3D coordinates, log has to have three values.")
        )

        if log[3]
            zlims = log10.(Plots.zlims(p))
            az = 10.0^(zlims[1] + rz * (zlims[2] - zlims[1]))
        else
            zlims = Plots.zlims(p)
            az = zlims[1] + rz * (zlims[2] - zlims[1])
        end

        return ax, ay, az

    end
end

"""
    make_video(
        source_path::String,
        source_format::String,
        output_path::String,
        output_filename::String,
        frame_rate::Int64,
    )::Nothing
	
Make a MP4 video from a series of images. 

The H.264 codec is used with no compression and the source images can be in
any format available in ImageIO.jl, e.g. ".png", ".svg", ".jpeg", etc.

# Arguments
- `source_path::String`: Path to the directory containing the images.	
- `source_format::String`: File format of the source images. 
- `output_path::String`: Path to the directory where the resulting video will be saved.
- `output_filename::String`: Name of the video to be generated without extension.	
- `frame_rate::Int64`: Frame rate of the video to be generated.
"""
function make_video(
    source_path::String,
    source_format::String,
    output_path::String,
    output_filename::String,
    frame_rate::Int64,
)::Nothing

    # Loads the target images.
    imagestack = [load(image) for image in glob("*" * source_format, source_path)]

    (
        !isempty(imagestack) ||
        error("I couldn't find any '$source_format' images in '$source_path'.")
    )

    # Creates the video with the specified frame rate and filename.
    VideoIO.save(
        joinpath(output_path, output_filename * ".mp4"),
        imagestack,
        framerate = frame_rate;
        encoder_options = (crf = 0, preset = "ultrafast"),
        codec_name = "libx264rgb",
    )

    return nothing
end

"""
    smooth_window(
        x_data::Vector{<:Real},
        y_data::Vector{<:Real},
        bins::Int64,
    )::NTuple{2, Vector{Float64}}

Separate the range of values of `x_data` in `bins` contiguous windows, and replaces 
every value within the window with the mean in order to smooth out the data. 

# Arguments
- `x_data::Vector{<:Real}`: Data used to create the windows.
- `y_data::Vector{<:Real}`: Data to be smoothed out.
- `bins::Int64`: Number of windows to be used in the smoothing.
- `log::Bool = false`: If the x axis will be divided using logarithmic bins.

# Returns
- The smooth data.
"""
function smooth_window(
    x_data::Vector{<:Real},
    y_data::Vector{<:Real},
    bins::Int64;
    log::Bool = false,
)::NTuple{2, Vector{Float64}}

    # Dimension consistency check.
    (
        length(x_data) == length(y_data) ||
        throw(DimensionMismatch("The input vectors should have the same length."))
    )

    if log 
        # First positive value of the x axis.
        start = log10(minimum(x -> x <= 0.0 ? Inf : x, x_data))
        # Logarithmic widths of the smoothing windows.
        width = (log10(maximum(x_data)) - start) / bins
    else
        # First value of the x axis.
        start = minimum(x_data)
        # Linear widths of the smoothing windows.
        width = (maximum(x_data) - start) / bins
    end

    # Initialize output arrays.
    smooth_x_data = Vector{Float64}(undef, bins)
    smooth_y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(smooth_x_data, smooth_y_data)

        # Find the indices of `x_data` which fall within window `i`.
        if log
            idx = findall(
                x -> 10.0^(start + width * (i - 1)) <= x < 10.0^(start + width * i), 
                x_data,
            )
        else 
            idx = findall(x -> start + width * (i - 1) <= x < start + width * i, x_data)
        end
		
		if isempty(idx)
			error("Using $bins bins is too high for the data, lower it.")
		else
			# Store mean values in output arrays.
			smooth_x_data[i] = sum(x_data[idx]) / length(idx)
			smooth_y_data[i] = sum(y_data[idx]) / length(idx)
		end
    end

    return smooth_x_data, smooth_y_data
end

"""
    density_profile(
        mass_data::Vector{Float64},
        distance_data::Vector{Float64},
        max_radius::Float64,
        bins::Int64,
    )::NTuple{2, Vector{Float64}}
	
Compute a density profile up to a radius `max_radius`. 

`max_radius` and `distance_data` must be in the same units.

# Arguments
- `mass_data::Vector{Float64}`: Masses of the particles.
- `distance_data::Vector{Float64}`: Radial distances of the particles. 
- `max_radius::Float64`: Maximum distance up to which the profile will be calculated.
- `bins::Int64`: Number of subdivisions of [0, `max_radius`] to be used for the profile.

# Returns
- A Tuple of two Arrays. 
  The first with the radial distances and the second with the densities.
"""
function density_profile(
    mass_data::Vector{Float64},
    distance_data::Vector{Float64},
    max_radius::Float64,
    bins::Int64,
)::NTuple{2, Vector{Float64}}

    # Dimension consistency check.
    (
        length(mass_data) == length(distance_data) ||
        throw(DimensionMismatch("The input vectors should have the same length."))
    )

    # Width of each spherical shell used to calculate the density.
    width = max_radius / bins

    # Initialize output arrays.
    x_data = Vector{Float64}(undef, bins)
    y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(x_data, y_data)
        # Find the indices of `distance_data` which fall within window `i`.
        idx = findall(x -> width * (i - 1) <= x < width * i, distance_data)

        if isempty(idx)
            x_data[i] = width * (i - 0.5)
            y_data[i] = 0.0
        else
            total_mass = sum(mass_data[idx])
            volume = 4.0 / 3.0 * π * width^3.0 * (3.0 * i * i - 3.0 * i + 1.0)

            # Mean distance for window i.
            x_data[i] = sum(distance_data[idx]) / length(idx)
            # Density for window i.
            y_data[i] = total_mass / volume
        end
    end

    return x_data, y_data
end

"""
    metallicity_profile(
        mass_data::Vector{Float64},
        distance_data::Vector{Float64},
        z_data::Vector{Float64},
        max_radius::Float64,
        bins::Int64,
    )::NTuple{2, Vector{Float64}}
	
Compute a metallicity profile up to a radius `max_radius`, 
and normalize it to the solar metallicity.

`max_radius` and `distance_data` must be in the same units.
`z_data` and `mass_data` must be in the same units.

# Arguments
- `mass_data::Vector{Float64}`: Masses of the particles.
- `distance_data::Vector{Float64}`: Radial distances of the particles. 
- `z_data::Vector{Float64}`: Metal content of the particles in mass units.
- `max_radius::Float64`: Maximum distance up to which the profile will be calculated.
- `bins::Int64`: Number of subdivisions of [0, `max_radius`] to be used for the profile.

# Returns
- A Tuple of two Arrays.
  The first with the radial distances and the second with the metallicities.
"""
function metallicity_profile(
    mass_data::Vector{Float64},
    distance_data::Vector{Float64},
    z_data::Vector{Float64},
    max_radius::Float64,
    bins::Int64,
)::NTuple{2, Vector{Float64}}

    # Dimension consistency check.
    (
        length(mass_data) == length(distance_data) == length(z_data) ||
        throw(DimensionMismatch("The input vectors should have the same length."))
    )

    # Width of each spherical shell used to calculate the metallicity.
    width = max_radius / bins

    # Initialize output arrays.
    x_data = Vector{Float64}(undef, bins)
    y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(x_data, y_data)
        # Find the indices of `distance_data` which fall within window `i`.
        idx = findall(x -> width * (i - 1) <= x < width * i, distance_data)

        if isempty(idx)
            x_data[i] = width * (i - 0.5)
            y_data[i] = 0.0
        else
            total_mass = sum(mass_data[idx])
            total_z = sum(z_data[idx])

            # Mean distance for window i.
            x_data[i] = sum(distance_data[idx]) / length(idx)
            # Metallicity for window i.
            y_data[i] = (total_z / total_mass) / SOLAR_METALLICITY
        end
    end

    return x_data, y_data
end

"""
    mass_profile(
        mass_data::Vector{Float64},
        distance_data::Vector{Float64},
        max_radius::Float64,
        bins::Int64,
    )::NTuple{2, Vector{Float64}}
	
Compute an accumulated mass profile up to a radius `max_radius`. 

`max_radius` and `distance_data` must be in the same units.

# Arguments
- `mass_data::Vector{Float64}`: Masses of the particles.
- `distance_data::Vector{Float64}`: Radial distances of the particles. 
- `max_radius::Float64`: Maximum distance up to which the profile will be calculated.
- `bins::Int64`: Number of subdivisions of [0, `max_radius`] to be used for the profile.

# Returns
- A Tuple of two Arrays.
  The first with the radial distances and the second with the accumulated masses.
"""
function mass_profile(
    mass_data::Vector{Float64},
    distance_data::Vector{Float64},
    max_radius::Float64,
    bins::Int64,
)::NTuple{2, Vector{Float64}}

    # Dimension consistency check.
    (
        length(mass_data) == length(distance_data) ||
        throw(DimensionMismatch("The input vectors should have the same length."))
    )

    # Width of each spherical shell used to calculate the mass.
    width = max_radius / bins

    # Initialize output arrays.
    x_data = Vector{Float64}(undef, bins)
    y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(x_data, y_data)
        # Indices of `distance_data` within window i.
        idx = findall(x -> width * (i - 1) <= x < width * i, distance_data)
		
		if isempty(idx)
            x_data[i] = width * (i - 0.5)
        else
			# Mean distance for window i.
			x_data[i] = sum(distance_data[idx]) / length(idx)
		end
		
		# Mass for window i.
		y_data[i] = sum(mass_data[idx])
    end

    return x_data, cumsum(y_data)
end

"""
    compute_cmdf(
        mass_data::Vector{Float64},
        metallicity_data::Vector{Float64},
        max_Z::Float64,
        bins::Int64; 
        <keyword arguments>
    )::NTuple{2, Vector{Float64}}
	
Compute the cumulative metallicity distribution function up to a metallicity `max_Z`. 

`mass_data` and `metallicity_data` must be in the same units.

# Arguments
- `mass_data::Vector{Float64}`: Masses of the particles.
- `metallicity_data::Vector{Float64}`: Metallicities of the particles. 
- `max_Z::Float64`: Maximum metallicity up to which the profile will be calculated.
- `bins::Int64`: Number of subdivisions of [0, `max_Z`] to construct the plot.
- `x_norm::Bool = false`: If the x axis will be normalized to its maximum value. 

# Returns
- A Tuple of two Arrays.
  The first with the metallicities and the second with the accumulated masses.
"""
function compute_cmdf(
    mass_data::Vector{Float64},
    metallicity_data::Vector{Float64},
    max_Z::Float64,
    bins::Int64;
    x_norm::Bool = false,
)::NTuple{2, Vector{Float64}}

    # Dimension consistency check.
    (
        length(mass_data) == length(metallicity_data) ||
        throw(DimensionMismatch("The input vectors should have the same length."))
    )
	
	# Dimensionless metallicity.
	Z = metallicity_data ./ mass_data

    # If required, normalize the x axis.
    if x_norm
        Z = Z ./ max_Z
        # Width of the metallicity bins.
        width = 1.0 / bins
    else
        # Width of the metallicity bins.
	    width = max_Z / bins  
    end
	
	# Total star mass.
	total_m = sum(mass_data)
	
	# Initialize output arrays.
    x_data = Vector{Float64}(undef, bins)
    y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(x_data, y_data)
		idx = findall(x -> width * (i - 1) <= x < width * i, Z)
		
		if isempty(idx)
            x_data[i] = width * (i - 0.5)
        else
			# Mean metallicity for window i.
			x_data[i] = sum(Z[idx]) / length(idx)
		end
		
		# Mass fraction for window i.
		y_data[i] = sum(mass_data[idx]) / total_m			
		
	end
	
	return x_data, cumsum(y_data)
end

"""
    kennicutt_schmidt_law(
        gas_mass_data::Vector{Float64},
        gas_distance_data::Vector{Float64},
        temperature_data::Vector{Float64},
        star_mass_data::Vector{Float64},
        star_distance_data::Vector{Float64},
        age_data::Vector{Float64},
        temp_filter::Float64,
        age_filter::Float64,
        max_r::Float64; 
        <keyword arguments>
    )::Union{Nothing, Dict{String, Any}}
	
Compute mass area density and the SFR area density for the Kennicutt-Schmidt law. 

`temp_filter` and `temperature_data` must be in the same units, and `age_filter` and 
`age_data` must be in the same units too.

# Arguments
- `gas_mass_data::Vector{Float64}`: Masses of the gas particles.
- `gas_distance_data::Vector{Float64}`: 2D distances of the gas particles. 
- `temperature_data::Vector{Float64}`: Temperatures of the gas particles.
- `star_mass_data::Vector{Float64}`: Masses of the stars.
- `star_distance_data::Vector{Float64}`: 2D distances of the stars.
- `age_data::Vector{Float64}`: Ages of the stars.
- `temp_filter::Float64`: Maximum temperature allowed for the gas particles.
- `age_filter::Unitful.Quantity`: Maximum star age allowed for the calculation of the SFR. 
  It should be approximately equal to the time step of the snapshots.
- `max_r::Float64`: Maximum distance up to which the parameters will be calculated.
- `bins::Int64 = 50`: Number of subdivisions of [0, `max_r`] to be used. 
  It has to be at least 5.

# Returns
- A dictionary with three entries.
  - Key "RHO" => Logarithm of the area mass densities.
  - Key "SFR" => Logarithm of the SFR area densities.
  - Key "LM" => Linear model given by GLM.jl.
"""
function kennicutt_schmidt_law(
    gas_mass_data::Vector{Float64},
    gas_distance_data::Vector{Float64},
    temperature_data::Vector{Float64},
    star_mass_data::Vector{Float64},
    star_distance_data::Vector{Float64},
    age_data::Vector{Float64},
    temp_filter::Float64,
    age_filter::Float64,
    max_r::Float64;
    bins::Int64 = 50,
)::Union{Nothing, Dict{String, Any}}

    # Bin size check.
    if bins < 5
        error("You have to use at least 5 bins.")
    end

    # Filter out hot gas particles.
    cold_gas_mass = deleteat!(copy(gas_mass_data), temperature_data .> temp_filter)
    cold_gas_distance = deleteat!(copy(gas_distance_data), temperature_data .> temp_filter)

    # Filter out old stars.
    young_star_mass = deleteat!(copy(star_mass_data), age_data .> age_filter)
    young_star_distance = deleteat!(copy(star_distance_data), age_data .> age_filter)

    r_width = max_r / bins

    # Initialize output arrays.
    x_data = Vector{Float64}(undef, bins)
    y_data = Vector{Float64}(undef, bins)

    @inbounds for i in eachindex(x_data, y_data)

        # Gas.
		idx_gas = findall(x ->  r_width * (i - 1) <= x < r_width * i, cold_gas_distance)
        gas_mass = sum(cold_gas_mass[idx_gas])
		# Gas area density for window i.
		x_data[i] = gas_mass / (π * r_width * r_width * (2.0 * i - 1.0))

        # Stars.
        idx_star = findall(x ->  r_width * (i - 1) <= x < r_width * i, young_star_distance)
        sfr = sum(young_star_mass[idx_star]) / age_filter 
        # SFR area density for window i.
        y_data[i] = sfr / (π * r_width * r_width * (2.0 * i - 1.0))		
		
	end

    # Filter out zeros.
    deleteat!(y_data, x_data .<= 0.0)
    filter!(x -> x > 0.0, x_data)
    deleteat!(x_data, y_data .<= 0.0)
    filter!(y -> y > 0.0, y_data)

    # Set logarithmic scaling.
    x_data = log10.(x_data)
    y_data = log10.(y_data)

    # If there are less than 5 data points return nothing
    if length(x_data) < 5
        return nothing
    end

    # Compute linear fit.
    X = [ones(length(x_data)) x_data]
    linear_model = lm(X, y_data)

    return Dict("RHO" => x_data, "SFR" => y_data, "LM" => linear_model)
end

# """
#     kennicutt_schmidt_law2(
#         gas_mass_data::Vector{Float64},
#         gas_distance_data::Vector{Float64},
#         temperature_data::Vector{Float64},
#         star_mass_data::Vector{Float64},
#         star_distance_data::Vector{Float64},
#         age_data::Vector{Float64},
#         age_filter::Float64,
#         max_r::Float64; 
#         <keyword arguments>
#     )::Union{Nothing, Dict{String, Any}}
	
# Compute mass area density and the SFR area density for the Kennicutt-Schmidt law. 

# `temp_filter` and `temperature_data` must be in the same units, and `age_filter` and 
# `age_data` must be in the same units too.

# # Arguments
# - `gas_mass_data::Vector{Float64}`: Masses of the gas particles.
# - `gas_distance_data::Vector{Float64}`: 2D distances of the gas particles.
# - `star_mass_data::Vector{Float64}`: Masses of the stars.
# - `star_distance_data::Vector{Float64}`: 2D distances of the stars.
# - `age_data::Vector{Float64}`: Ages of the stars.
# - `age_filter::Unitful.Quantity`: Maximum star age allowed for the calculation of the SFR. 
#   It should be approximately equal to the time step of the snapshots.
# - `max_r::Float64`: Maximum distance up to which the parameters will be calculated.
# - `bins::Int64 = 50`: Number of subdivisions of [0, `max_r`] to be used. 
#   It has to be at least 5.

# # Returns
# - A dictionary with three entries.
#   - Key "RHO" => Logarithm of the area mass densities.
#   - Key "SFR" => Logarithm of the SFR area densities.
#   - Key "LM" => Linear model given by GLM.jl.
# """
# function kennicutt_schmidt_law2(
#     gas_mass_data::Vector{Float64},
#     gas_distance_data::Vector{Float64},
#     star_mass_data::Vector{Float64},
#     star_distance_data::Vector{Float64},
#     age_data::Vector{Float64},
#     age_filter::Float64,
#     max_r::Float64;
#     bins::Int64 = 50,
# )::Union{Nothing, Dict{String, Any}}

#     # Bin size check.
#     if bins < 5
#         error("You have to use at least 5 bins.")
#     end

#     # Filter out old stars.
#     young_star_mass = deleteat!(copy(star_mass_data), age_data .> age_filter)
#     young_star_distance = deleteat!(copy(star_distance_data), age_data .> age_filter)

#     r_width = max_r / bins

#     # Initialize output arrays.
#     x_data = Vector{Float64}(undef, bins)
#     y_data = Vector{Float64}(undef, bins)

#     @inbounds for i in eachindex(x_data, y_data)

#         # Gas.
# 		idx_gas = findall(x ->  r_width * (i - 1) <= x < r_width * i, gas_distance_data)
#         gas_mass = sum(gas_mass_data[idx_gas])
# 		# Gas area density for window i.
# 		x_data[i] = gas_mass / (π * r_width * r_width * (2 * i - 1))

#         # Stars.
#         idx_star = findall(x ->  r_width * (i - 1) <= x < r_width * i, young_star_distance)
#         sfr = sum(young_star_mass[idx_star]) / age_filter 
#         # SFR area density for window i.
#         y_data[i] = sfr / (π * r_width * r_width * (2 * i - 1))		
		
# 	end

#     # Filter out zeros.
#     deleteat!(y_data, x_data .<= 0.0)
#     filter!(x -> x > 0.0, x_data)
#     deleteat!(x_data, y_data .<= 0.0)
#     filter!(y -> y > 0.0, y_data)

#     # Set logarithmic scaling.
#     y_data = log10.(y_data)

#     # If there are less than 5 data points return nothing
#     if length(x_data) < 5
#         return nothing
#     end

#     # Compute linear fit.
#     X = [ones(length(x_data)) log10.(x_data)]
#     linear_model = lm(X, y_data)

#     return Dict("RHO" => x_data, "SFR" => y_data, "LM" => linear_model)
# end

"""
    format_error(mean::Float64, error::Float64)::String

Format the mean and error values.

It follows the traditional rules for error presentation. The error has only one significant  
digit, unless such digit is a one, in which case, two significant digits are used.  
The mean will have a number of digits such as to match the error. 

# Arguments 
- `mean::Float64`: Mean value.
- `error::Float64`: Error value. It must be positive.

# Returns
- A Tuple with the formatted mean and error values.

# Examples
```julia-repl
julia> format_error(69.42069, 0.038796)
(69.42, 0.04)

julia> format_error(69.42069, 0.018796)
(69.421, 0.019)

julia> format_error(69.42069, 0.0)
(69.42069, 0.0)

julia> format_error(69.42069, 73.4)
(0.0, 70.0)
```
"""
function format_error(mean::Float64, error::Float64)::NTuple{2, Float64}

    # Positive error check.
    error >= 0.0 || error("The error must be a positive number.")

    if error == 0.0
        round_mean = mean
        round_error = error
    else
        sigdigit_pos = abs(log10(abs(error)))

        if error < 1.0
            if abs(mean) < error
                extra = 0
                round_mean = 0.0
            else
                first_digit = trunc(error * 10.0^(floor(sigdigit_pos) + 1.0))
                first_digit == 1.0 ? extra = 1 : extra = 0

                digits = ceil(Int64, sigdigit_pos) + extra
                round_mean = round(mean; digits)
            end
        else
            if abs(mean) < error
                extra = 0
                round_mean = 0.0
            else
                first_digit = trunc(error / 10.0^(floor(sigdigit_pos)))
                first_digit == 1.0 ? extra = 2 : extra = 1

                sigdigits = ceil(Int64, log10(abs(mean))) - ceil(Int64, sigdigit_pos) + extra
                round_mean = round(mean; sigdigits)
            end
        end

        round_error = round(error, sigdigits = 1 + extra)
    end

    return round_mean, round_error
end

"""
    pass_all(snap_file::String, type::String)::Vector{Int64}

Default filter function for read_blocks_over_all_files().

It does not filter out any particles, allowing the data acquisition functions to gather 
all data. 

# Arguments 
- `snap_file::String`: Snapshot file path.
- `type::String`: Particle type.
  "gas" -> Gas particle. 
  "dark_matter" -> Dark matter particle.
  "stars" -> Star particle.

# Returns
- A Vector with the indices of the allowed particles.
"""
function pass_all(snap_file::String, type::String)::Vector{Int64}

    # Select type of particle.
    if type == "gas"
        type_num = 1
    elseif type == "dark_matter"
        type_num = 2
    elseif type == "stars"
        type_num = 5
    else
        error("Particle type '$type' not supported. 
        The supported types are 'gas', 'dark_matter' and 'stars'")
    end

    header = read_header(snap_file)

    return collect(1:header.npart[type_num])
end

"""
    energy_integrand(header::GadgetIO.SnapshotHeader, a::Float64)::Float64

Give the integrand of the scale factor to physical time function: 

    t₀ = ∫ 1 / (H * √ϵ), 

where H = H₀ * a and ϵ = Ωλ + (1 - Ωλ - Ω₀) / a² + Ω₀ / a³, evaluated in `a`. 

# Arguments 
- `header::GadgetIO.SnapshotHeader`: Header of the relevant snapshot file.
- `a::Float64`: Dimensionless scale factor.

# Returns
- The integrand evaluated in `a` in Gyr.
"""
function energy_integrand(header::GadgetIO.SnapshotHeader, a::Float64)::Float64

    # Ω_K (curvature)
    omega_K = 1.0 - header.omega_0 - header.omega_l
    # Energy function.
    E = header.omega_0 / (a * a * a) + omega_K / (a * a) + header.omega_l
    # Hubble constant in 1 / Gyr.
    H = header.h0 * HUBBLE_CONST * a

    # Integrand of the time integral in Gyr. 
    return 1.0 / (H * sqrt(E))
end

"""
    num_integrate(
        func::Function, 
        inf_lim::Float64, 
        sup_lim::Float64, 
        steps::Int64 = 200,
    )::Float64

Give the numerical integral of `func` between `inf_val` and `sup_val`. 

# Arguments 
- `func::Function`: 1D function to be integrated.
- `inf_lim::Float64`: Inferior limit of the integral.
- `sup_lim::Float64`: Superior limit if the integral.
- `steps::Int64`: Number of subdivisions to be used for the discretization of 
  the `sup_lim` - `inf_lim` region.

# Returns
- The value of the integral.

# Examples
```julia-repl
julia> num_integrate(sin, 0, 3π)
1.9996298761360816

julia> num_integrate(x -> x^3 + 6 * x^2 + 9 * x + 2, 0, 4.69)
438.9004836958452

julia> num_integrate(x -> exp(x^x), 0, 1.0)
2.1975912134624904
```
"""
function num_integrate(
    func::Function, 
    inf_lim::Real, 
    sup_lim::Real, 
    steps::Int64 = 200,
)::Float64
    
    # Width of a single subinterval.
    width = (sup_lim - inf_lim) / steps
    # Integrand evaluated at the rightmost value of each subinterval.
    integrand = func.([inf_lim + width * i for i in 1:steps])

    # Final result of the numerical integration.
    return sum(width .* integrand)
end

"""
    center_of_mass(
        position_data::Matrix{<:Real},
        mass_data::Vector{<:Real},
    )::NTuple{3, Float64}

Calculate the center of mass as

R = (1 / M) * ∑ m_i * r_i

where M = ∑ m_i

# Arguments
- `position_data::Matrix{<:Real}`: The positions of the particles.
- `mass_data::Vector{<:Real}`: The masses of the particles.

# Returns
- The center of mass in the unis of `position_data`.
"""
function center_of_mass(
    position_data::Matrix{<:Real},
    mass_data::Vector{<:Real},
)::NTuple{3, Float64}

    # Total mass
    M = sum(mass_data)

    R = [0.0, 0.0, 0.0]
    for (col, mass) in zip(eachcol(position_data), mass_data)
        R .+= col .* mass
    end

    return R[1] / M, R[2] / M, R[3] / M

end

"""
    comparison(
        x::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}, 
        y::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}; 
        atol::Float64 = 1e-5, 
        rtol::Float64 = 1e-5,
    )::Bool

Determines is two numbers, numeric arrays or numeric tuples are approximately equal.

# Arguments
- `x::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}`: First element to be compared.
- `y::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}`: Second element to be compared.
- `atol::Float64 = 1e-5`: Absolute tolerance.
- `rtol::Float64 = 1e-5`: Relative tolerance.

# Returns
- Return `true` if every pair of elements (X, Y) in (x, y) pass
  norm(X - Y) <= max(atol, rtol * max(norm(X), norm(Y))).
"""
function comparison(
    x::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}, 
    y::Union{Real, AbstractArray{<:Real}, Tuple{Vararg{Real}}}; 
    atol::Float64 = 1e-5, 
    rtol::Float64 = 1e-5,
)::Bool

    return all(isapprox.(x, y; atol, rtol))

end

"""
    comparison(x, y; atol::Float64 = 1e-5, rtol::Float64 = 1e-5)::Bool

Determines is two elements are equal.

# Arguments
- `x`: First element to be compared.
- `y`: Second element to be compared.
- `atol::Float64 = 1e-5`: Absolute tolerance (for compatibility).
- `rtol::Float64 = 1e-5`: Relative tolerance (for compatibility).

# Returns
- Return `true` if x == y.
"""
function comparison(x, y; atol::Float64 = 1e-5, rtol::Float64 = 1e-5)::Bool

    return isequal(x, y)

end

"""
    deep_comparison(
        x::Dict, 
        y::Dict; 
        atol::Float64 = 1e-5, 
        rtol::Float64 = 1e-5,
    )::Bool

Determines is two dictionaries are approximately equal.

Numeric elements are compared with comparison(), everything else with isequal().

# Arguments
- `x::Dict`: First dictionary to be compared.
- `y::Dict`: Second dictionary to be compared.
- `atol::Float64 = 1e-5`: Absolute tolerance for numeric elements.
- `rtol::Float64 = 1e-5`: Relative tolerance for numeric elements.

# Returns
- Return `true` if every pair of elements pass the equality tests.
"""
function deep_comparison(
    x::Dict, 
    y::Dict; 
    atol::Float64 = 1e-5, 
    rtol::Float64 = 1e-5,
)::Bool

    if keys(x) != keys(y)
        return false
    end

    return all([comparison(x[key], y[key]; atol, rtol) for key in keys(x)])
    
end

"""
    deep_comparison(
        x::Union{AbstractArray, Tuple}, 
        y::Union{AbstractArray, Tuple}; 
        atol::Float64 = 1e-5, 
        rtol::Float64 = 1e-5,
    )::Bool

Determines is two arrays or tuples are approximately equal.

Numeric elements are compared with comparison(), everything else with isequal().

# Arguments
- `x::Union{AbstractArray, Tuple}`: First array to be compared.
- `y::Union{AbstractArray, Tuple}`: Second array to be compared.
- `atol::Float64 = 1e-5`: Absolute tolerance for numeric elements.
- `rtol::Float64 = 1e-5`: Relative tolerance for numeric elements.

# Returns
- Return `true` if every pair of elements pass the equality tests.
"""
function deep_comparison(
    x::Union{AbstractArray, Tuple}, 
    y::Union{AbstractArray, Tuple}; 
    atol::Float64 = 1e-5, 
    rtol::Float64 = 1e-5,
)::Bool

    if length(x) != length(y)
        return false
    end

    return all([comparison(X, Y; atol, rtol) for (X, Y) in zip(x, y)])
    
end