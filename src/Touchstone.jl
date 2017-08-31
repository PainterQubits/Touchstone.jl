__precompile__()
module Touchstone
using FileIO, AxisArrays
export loadset

const tsextensions = [".s2p",".s3p",".s4p",".s5p",".s6p",".s7p",".s8p",".ts"]
function __init__()
    FileIO.add_format(format"TS", (), tsextensions)
end

"""
    loadset(path::String)
Loads a set of Touchstone files found in a given directory `path` that
represent a parameter sweep. All files will be combined into a single
AxisArray with axes for each swept parameter.
"""
function loadset(path::String)
    first = true
    local a
    for f in readdir(path)
        if any(endswith(f, ext) for ext in tsextensions)
            if first
                first = false
                a = FileIO.load(joinpath(path,f))
            else
                a = merge(a, FileIO.load(joinpath(path,f)))
            end
        end
    end
    return a
end

function FileIO.load(f::File{format"TS"}; kwargs...)
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

function FileIO.load(s0::Stream{format"TS"};
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
    paramaxes = AxisArrays.Axis[]
    freq = Float64[]
    data = Float64[]
    lct = 0
    while !eof(s)
        l = readline(s); lct+=1
        if l == "!< PARAMS"         # Sonnet spits this out
            while true
                l = readline(s); lct+=1
                l == "!< END PARAMS" && break
                param = replace(l[4:end], " ", "")
                (k,v) = (split(param, "=")...)
                push!(paramaxes, AxisArrays.Axis{Symbol(k)}([parse(Float64, v)]))
            end
            continue
        end
        l[1] == '!' && continue     # Skip comment lines

        if l[1] == '#'              # Parse option line
            #TODO: check that the option line precedes all data lines
            #TODO: check that there is only one option line per file
            #TODO: replace 1 or more whitespace by 1 space
            #TODO: more input sanitizing, etc.
            optargs = split(lowercase(l),' ')[2:end]

            # resistances specified as e.g. "R 50.0"
            ridx = findfirst(x->x=="R", optargs)
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
            # TODO: Replace multiple spaces by one space.
            dataline = split(l, ' ')
            length(dataline) != expectednum(nports, i) &&
                error("unexpected number of values on line $lct.")
            if i == 1
                push!(freq, parse(Float64, dataline[1]))
                append!(data, (x->parse(Float64, x)).(dataline[2:end]))
            else
                append!(data, dataline)
            end
            i == nl && break
            l = readline(s); lct+=1
        end
    end

    # TODO: check that frequencies are strictly increasing
    #       (required by Touchstone spec)

    reshapeddata = reshape(data,
        (2, nports^2, length(freq), ntuple(x->1, length(paramaxes))...))
    return AxisArrays.AxisArray(reshapeddata, format_axis(opts[:format]),
        param_axis(opts[:parameter], nports), Axis{:f}(freq), paramaxes...)
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
    param_axis(param, nports)
Given a parameter code from the options line of the file and some number
of ports, return a suitable `AxisArrays.Axis{:parameter}` object.
"""
function param_axis(param, nports)
    if nports == 2
        return Axis{:parameter}(Symbol.(param.*["11","21","12","22"]))
    else
        numvec = string.(collect(1:nports))
        numrow = reshape(numvec,1,length(numvec))
        return Axis{:parameter}(
            Symbol.(param.*(permutedims(numvec.*numrow,(2,1))[:])))
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

end # module
