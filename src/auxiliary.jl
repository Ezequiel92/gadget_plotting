############################################################################################
# AUXILIARY FUNCTIONS.
############################################################################################

"""
    relative(
        p::Plots.Plot,
        rx::Float64,
        ry::Float64,
        rz::Union{Float64, Nothing} = nothing,
    )::Union{NTuple{2, Float64}, NTuple{3, Float64}}
    
Give the absolute coordinates for a Plot, given the relative ones.

# Arguments 
- `p::Plots.Plot`: Plot for which the absolute coordinates will be calculated.
- `rx::Float64`: relative x coordinate, rx ∈ [0, 1].
- `ry::Float64`: relative y coordinate, ry ∈ [0, 1].
- `rz::Union{Float64,Nothing} = nothing`: relative z coordinate, rz ∈ [0, 1].

# Returns
- A Tuple with the absolute coordinates: (x, y) or (x, y, z).
"""
function relative(
    p::Plots.Plot,
    rx::Float64,
    ry::Float64,
    rz::Union{Float64, Nothing} = nothing,
)::Union{NTuple{2, Float64}, NTuple{3, Float64}}

    # Plot axes limits.
    xlims = Plots.xlims(p)
    ylims = Plots.ylims(p)

    if rz === nothing
        return xlims[1] + rx * (xlims[2] - xlims[1]), ylims[1] + ry * (ylims[2] - ylims[1])
    else
        zlims = Plots.zlims(p)

        return xlims[1] + rx * (xlims[2] - xlims[1]),
        ylims[1] + ry * (ylims[2] - ylims[1]),
        zlims[1] + rz * (zlims[2] - zlims[1])
    end
end

"""
    makeVideo(
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
function makeVideo(
    source_path::String,
    source_format::String,
    output_path::String,
    output_filename::String,
    frame_rate::Int64,
)::Nothing

    # Loads the target images.
    image_stack = [load(image) for image in glob("*" * source_format, source_path)]

    (
        !isempty(image_stack) ||
        error("I couldn't find any '$source_format' images in '$source_path'.")
    )

    # Creates the video with the specified frame rate and filename.
    properties = [:priv_data => ("crf" => "0", "preset" => "ultrafast")]
    encodevideo(
        output_path * output_filename * ".mp4",
        image_stack,
        framerate = frame_rate,
        AVCodecContextProperties = properties,
    )

    return nothing
end

"""
    smoothWindow(
        x_data::Vector{T} where {T <: Real},
        y_data::Vector{T} where {T <: Real},
        bins::Int64,
    )::NTuple{2, Vector{Float64}}

Separate the range of values of `x_data` in `bins` contiguous windows, and replaces 
every value within the window with the mean in order to smooth out the data. 

# Arguments
- `x_data::Vector{T} where {T <: Real}`: Data used to create the windows.
- `y_data::Vector{T} where {T <: Real}`: Data to be smoothed out.
- `bins::Int64`: Number of windows to be used in the smoothing.
- `log::Bool = false`: If the x axis will be divided using logarithmic bins.

# Returns
- The smooth data.
"""
function smoothWindow(
    x_data::Vector{T} where {T <: Real},
    y_data::Vector{T} where {T <: Real},
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
        start = log10(minimum(x -> x <= 0 ? Inf : x, x_data))
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
                x -> 10^(start + width * (i - 1)) <= x < 10^(start + width * i), 
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
    densityProfile(
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
function densityProfile(
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
            volume = 4 / 3 * π * width^3 * (3 * i * i - 3 * i + 1)

            # Mean distance for window i.
            x_data[i] = sum(distance_data[idx]) / length(idx)
            # Density for window i.
            y_data[i] = total_mass / volume
        end
    end

    return x_data, y_data
end

"""
    metallicityProfile(
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
function metallicityProfile(
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
    massProfile(
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
function massProfile(
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
    CMDF(
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
- `bins::Int64`: Number of subdivisions of [0, `max_Z`] to be used for the profile.
- `x_norm::Bool = false`: If the x axis will be normalize to its maximum value. 

# Returns
- A Tuple of two Arrays.
  The first with the metallicities and the second with the accumulated masses.
"""
function CMDF(
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
        width = 1 / bins
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