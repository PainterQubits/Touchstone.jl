__precompile__()
module Touchstone

using FileIO
using AxisArrays
using Interpolations
using UUIDs

export Linear, Constant, RealImag, MagAngle, dBAngle, reformat, loadset

const tsextensions = [".s1p",".s2p",".s3p",".s4p",".s5p",".s6p",".s7p",".s8p",".ts"]
function __init__()
    FileIO.add_format(format"TS", (), tsextensions, [:Touchstone => UUID("958a2305-7e5c-4f48-8401-e0b3f0c58adc")])
end

"""
    loadset(path::String; interpolation = Linear())
Loads a set of Touchstone files found in a given directory `path` that represent a
parameter sweep. All files will be combined into a single AxisArray with axes for each swept
parameter.

Sometimes Sonnet will report different frequencies for different values of the swept
parameter when running in Adaptive Band Synthesis mode. The frequency axis lengths won't
match in this case, so a merged frequency axis is constructed. The simulation results are
then interpolated over the merged frequency axis. Either `Linear()` or `Constant()`
(nearest neighbor) may be passed using the `interp` keyword argument.
"""
function loadset(path::String; interp = Linear())
    # Load each file in its own AxisArray.
    local axarrs
    first = true
    for f in readdir(path)
        if any(endswith(f, ext) for ext in tsextensions)
            if first
                first = false
                axarrs = [FileIO.load(joinpath(path,f))]
            else
                push!(axarrs, FileIO.load(joinpath(path,f)))
            end
        end
    end

    # Do all the frequencies match?
    # The following does a pairwise comparison of the frequency axes in all files.
    # Only the upper (lower?) triangle of the pairwise comparison matrix is used.
    fmatches = all([(i, a[Axis{:f}].val == b[Axis{:f}].val)[2]
        for (i,a) in enumerate(axarrs) for b in axarrs[i:end]])

    # TODO: merge :parameter axes like we do with :f if they don't match.

    if fmatches
        return merge(axarrs...)
    else
        # Find combined frequency axis
        faxis = axarrs[1][Axis{:f}].val
        for j in axarrs[2:end]
            faxis = union(faxis, j[Axis{:f}].val)
        end
        sort!(faxis)

        local newaxarrs
        first = true
        for a in axarrs
            if first
                first = false
                newaxarrs = [
                    AxisArray(zeros(size(a)[1:4]..., length(faxis), size(a)[6:end]...),
                    AxisArrays.axes(a)[1:4]..., Axis{:f}(faxis), AxisArrays.axes(a)[6:end]...)
                    ]
            else
                push!(newaxarrs, AxisArray(zeros(size(a)[1:4]..., length(faxis),
                    size(a)[6:end]...), AxisArrays.axes(a)[1:4]..., Axis{:f}(faxis), AxisArrays.axes(a)[6:end]...))
            end

            # This is a little ugly, probably could be better but Interpolations.jl doesn't
            # seem to allow interpolating when there are dimensions of length 1
            b = newaxarrs[end]
            for f in a[Axis{:format}].val, p in a[Axis{:parameter}].val,
                i in a[Axis{:to}].val, j in a[Axis{:from}].val
                onetuple = ntuple(x->1, ndims(a)-5)
                b[f,p,i,j,:,onetuple...] =
                    interpolate((a[Axis{:f}].val, ), a[f,p,i,j,:,onetuple...].data,
                        Gridded(interp))[faxis]
            end
        end
        return merge(newaxarrs...)
    end
end

function load(f::File{format"TS"}; kwargs...)
    open(f) do s
        n = filename(f)
        ext = splitext(n)[2]
        if ext == ".ts"
            # Touchstone v2 specifies number of ports in the file.
            return load(s; v2=true)
        else
            # Touchstone v1 conventionally specifies the number of ports by
            # the file extension (i.e. .s2p means two ports; sNp means N).
            # Any arguments passed in via kwargs override assumptions made here.
            params = Dict(
                :v2=>false, :nports=>parse(Int, match(r"s([0-9]+)p", ext)[1]))
            return load(s; merge(params, Dict(kwargs))...)
        end
    end
end

function load(s0::Stream{format"TS"};
        v2::Bool=false, nports::Int=2)
    v2 && error("Touchstone v2 not yet implemented.") #TODO
    @assert nports > 0
    nl = nlines(nports)
    s = stream(s0)

    opts = Dict(
        :f=>"ghz",
        :parameter=>"s",
        :format=>"ma",
        :resistance=>50.0
    )
    sweepaxes = AxisArrays.Axis[]
    freq = Float64[]
    data = Float64[]
    lct = 0
    while !eof(s)
        l = readline(s); lct+=1
        if l == "!< PARAMS"         # Sonnet spits this out
            while true
                l = readline(s); lct+=1
                l == "!< END PARAMS" && break
                param = replace(l[4:end], " "=>"")
                (k,v) = split(param, "=")
                push!(sweepaxes, AxisArrays.Axis{Symbol(k)}([parse(Float64, v)]))
            end
            continue
        end
        l[1] == '!' && continue     # Skip comment lines

        if l[1] == '#'              # Parse option line
            #TODO: check that the option line precedes all data lines
            #TODO: check that there is only one option line per file
            #TODO: more input sanitizing, etc.
            optargs = split(lowercase(l), ' ', keepempty=false)[2:end]

            # resistances specified as e.g. "R 50.0"
            ridx = findfirst(x->x=="r", optargs)
            (ridx > 0) && (opts[:resistance] = optargs[ridx+1])

            fs = intersect(["ghz","mhz","khz","hz"], optargs)
            length(fs) > 1 && error("more than one frequency unit specified.")
            (length(fs) == 1) && (opts[:f] = fs[1])

            ps = intersect(["s","y","z","g","h"], optargs)
            length(ps) > 1 && error("more than one parameter specified.")
            (length(ps) == 1) && (opts[:parameter] = ps[1])

            formats = intersect(["ma","db","ri"], optargs)
            length(formats) > 1 && error("more than one format specified.")
            (length(formats) == 1) && (opts[:format] = formats[1])

            continue # done parsing option line
        end

        # If we made it this far, this is a data line.
        i = 0
        while true
            i += 1
            dataline = split(strip(l), ' ', keepempty=false)
            length(dataline) != expectednum(nports, i) &&
                error("unexpected number of values on line $lct.")
            if i == 1
                push!(freq, parse(Float64, dataline[1]))
                append!(data, (x->parse(Float64, x)).(dataline[2:end]))
            else
                append!(data, (x->parse(Float64, x)).(dataline))
            end
            i == nl && break
            l = readline(s); lct+=1
        end
    end

    # TODO: check that frequencies are strictly increasing
    #       (required by Touchstone spec)

    reshapeddata = reshape(data,
        (2, 1, nports, nports, length(freq), ntuple(x->1, length(sweepaxes))...))
    axarr = AxisArrays.AxisArray(reshapeddata, format_axis(opts[:format]),
        param_axes(opts[:parameter], nports)..., Axis{:f}(freq), sweepaxes...)
    if nports == 2
        return axarr
    else
        # We want to have Axis{:to} before Axis{:from} so that the indices always
        # are ordered like the subscripts on e.g. S_{21}.
        return permutedims(axarr, [1,2,4,3,5:ndims(axarr)...])
    end
end

"""
    format_axis(fmt)
Given a format code from the options line of the file, return a suitable
`AxisArrays.Axis{:format}` object.
"""
function format_axis(fmt)
    if fmt == "ma"
        return Axis{:format}([:mag, :angle])
    elseif fmt == "db"
        return Axis{:format}([:dB, :angle])
    elseif fmt == "ri"
        return Axis{:format}([:real, :imag])
    else
        error("unknown format option.")
    end
end

"""
    param_axes(param, nports)
Given a parameter code from the options line of the file and some number
of ports, return suitable `AxisArrays.Axis{:parameter}`, `AxisArrays.Axis{:out}`,
`AxisArrays.Axis{:in}` objects.
"""
function param_axes(param, nports)
    if nports == 2
        # Touchstone file has S11, S21, S12, S22 on data line.
        # The "fast axis" of the data is the "to" port
        return Axis{:parameter}([Symbol(uppercase(param))]),
            Axis{:to}(Base.OneTo(2)), Axis{:from}(Base.OneTo(2))
    else
        # Touchstone file has S11, S12, S13; S21, S22, S23; etc. on data lines.
        # The "fast axis" of the data is the "from" port
        return Axis{:parameter}([Symbol(uppercase(param))]),
            Axis{:from}(Base.OneTo(nports)), Axis{:to}(Base.OneTo(nports))
    end
end

"""
    nlines(nports)
Number of data lines for a particular frequency given `nports`.
"""
function nlines(nports)
    nports == 1 && return 1
    nports == 2 && return 1
    return cld(nports,4)*nports
end

"""
    expectednum(nports, linenum)
Given `nports`, this returns the number of expected values on line number
`linenum`, which should range from `1:nlines(nports)`.
"""
function expectednum(nports, linenum)
    @assert linenum <= nlines(nports)
    @assert linenum >= 1
    adj = ifelse(linenum == 1, true, false)

    # special cases
    nports == 1 && return 3
    if nports == 3
        linenum == 1 && return 7
        return 6
    end

    # generic code
    lpp = cld(nports,4) # lines per port
    linenumpp = mod(linenum - 1, lpp) + 1
    linenumpp == lpp && lpp != 1 && return rem(nports, 4)*2+adj
    return 8+adj
end

abstract type Format end
struct RealImag <: Format end
struct MagAngle <: Format end
struct dBAngle  <: Format end

"""
    reformat(::Type{T}, A::AxisArray) where {T<:Format}
Reformat imported Touchstone data. The type can be one of `RealImag`, `MagAngle`, or
`dBAngle`. Take care to use the special AxisArray indexing since the axes may not be in the
same order afterwards.

As usual for the Touchstone format, angles are in degrees.
"""
function reformat(::Type{T}, A::AxisArray) where {T<:Format}
    if :format in axisnames(A)
        formats = A[Axis{:format}].val
        if :real in formats && :imag in formats
            _reformat(T, RealImag, A)
        elseif :mag in formats && :angle in formats
            _reformat(T, MagAngle, A)
        elseif :dB in formats && :angle in formats
            _reformat(T, dBAngle, A)
        else
            error("unknown formats in Axis{:format}.")
        end
    else
        error("Axis{:format} missing.")
    end
end

_reformat(::Type{T}, ::Type{T}, A::AxisArray) where {T<:Format} = A

function _reformat(::Type{MagAngle}, ::Type{RealImag}, A::AxisArray)
    cs = Complex.(A[Axis{:format}(:real)], A[Axis{:format}(:imag)])
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), abs.(cs), rad2deg.(angle.(cs))),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:mag, :angle]))
end

function _reformat(::Type{dBAngle}, ::Type{RealImag}, A::AxisArray)
    cs = Complex.(A[Axis{:format}(:real)], A[Axis{:format}(:imag)])
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), 20*log10.(abs.(cs)), rad2deg.(angle.(cs))),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:dB, :angle]))
end

function _reformat(::Type{dBAngle}, ::Type{MagAngle}, A::AxisArray)
    decibels = @. 20*log10(A[Axis{:format}(:mag)])
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), decibels, view(A, Axis{:format}(:angle))),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:dB, :angle]))
end

function _reformat(::Type{RealImag}, ::Type{MagAngle}, A::AxisArray)
    re = @. cosd(A[Axis{:format}(:angle)]) * A[Axis{:format}(:mag)]
    im = @. sind(A[Axis{:format}(:angle)]) * A[Axis{:format}(:mag)]
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), re, im),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:real, :imag]))
end

function _reformat(::Type{RealImag}, ::Type{dBAngle}, A::AxisArray)
    re = @. cosd(A[Axis{:format}(:angle)]) * exp10(A[Axis{:format}(:mag)]/20)
    im = @. sind(A[Axis{:format}(:angle)]) * exp10(A[Axis{:format}(:mag)]/20)
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), re, im),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:real, :imag]))
end

function _reformat(::Type{MagAngle}, ::Type{dBAngle}, A::AxisArray)
    mg = @. exp10(A[Axis{:format}(:dB)]/20)
    ind = findfirst(x -> x==:format, axisnames(A))
    return AxisArray(cat(ndims(A), mg, view(A, Axis{:format}(:angle))),
        axes(A)[setdiff(1:ndims(A),ind)]..., Axis{:format}([:mag, :angle]))
end

end # module
