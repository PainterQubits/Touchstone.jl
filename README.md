# Touchstone

[![Build Status](https://travis-ci.org/PainterQubits/Touchstone.jl.svg?branch=master)](https://travis-ci.org/PainterQubits/Touchstone.jl)
[![Coverage Status](https://coveralls.io/repos/github/PainterQubits/Touchstone.jl/badge.svg?branch=master)](https://coveralls.io/github/PainterQubits/Touchstone.jl?branch=master)
[![codecov.io](http://codecov.io/github/PainterQubits/Touchstone.jl/coverage.svg?branch=master)](http://codecov.io/github/PainterQubits/Touchstone.jl?branch=master)

Reads Touchstone files into [AxisArrays](https://github.com/JuliaArrays/AxisArrays.jl).
Supports [Sonnet](http://www.sonnetsoftware.com) parameter sweeps.

## What's a Touchstone file?

The gory details:

- [Touchstone v1.1 specification](https://ibis.org/connector/touchstone_spec11.pdf)
- [Touchstone v2.0 specification](http://www.ibis.org/touchstone_ver2.0/touchstone_ver2_0.pdf)

## Usage

To load a Touchstone file with extension `.s1p`, `.s2p`, `.s3p`, etc. into an
[AxisArray](http://github.com/JuliaArrays/AxisArrays.jl), it could not be
any easier:

```
julia> using Touchstone, FileIO, AxisArrays

julia> A = load(joinpath(Pkg.dir("Touchstone"), "test", "paramsweep", "BusResonator_17_param01.s2p"))
6-dimensional AxisArray{Float64,6,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:S]
    :to, Base.OneTo(2)
    :from, Base.OneTo(2)
    :f, [6.0, 6.05, 6.1, 6.15, 6.2, 6.25, 6.3, 6.35, 6.4, 6.45  …  15.55, 15.6, 15.65, 15.7, 15.75, 15.8, 15.85, 15.9, 15.95, 16.0]
    :BusLengthControl, [100.0]
And data, a 2×1×2×2×798×1 Array{Float64,6}:
[:, :, 1, 1, 1, 1] =
  1.0  
 -3.613

[:, :, 2, 1, 1, 1] =
  2.039e-5
 75.309

...
```

Notice how some parameter appeared as a fourth dimension? That parameter was
included as a comment by Sonnet when the .s2p file was exported. Here's the
fun part. If you have a parameter sweep or even a multi-parameter sweep saved
as a collection of .s2p files in a folder, for example as exported by Sonnet,
you can use `loadset` to import everything into *one* AxisArray:

```
julia> loadset(joinpath(Pkg.dir("Touchstone"), "test", "paramsweep"))
6-dimensional AxisArray{Float64,6,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:S]
    :to, [1, 2]
    :from, [1, 2]
    :f, [6.0, 6.05, 6.1, 6.15, 6.2, 6.25, 6.26015, 6.27006, 6.27975, 6.28922  …  15.5886, 15.6, 15.65, 15.7, 15.75, 15.8, 15.85, 15.9, 15.95, 16.0]
    :BusLengthControl, [100.0, 600.0, 1100.0, 1600.0, 2100.0, 2600.0, 3100.0, 3600.0, 4100.0, 4600.0, 5100.0]
And data, a 2×1×2×2×8561×11 Array{Float64,6}:
[:, :, 1, 1, 1, 1] =
  1.0  
 -3.613

[:, :, 2, 1, 1, 1] =
  2.039e-5
 75.309   

...
```

Note that sometimes Sonnet will save files with different frequency axes in one parameter
sweep depending on what adaptive band synthesis chose to do. If this happens, all of the
frequency axes are merged, and missing values are interpolated. `Linear()` or `Constant()`
(nearest-neighbor) interpolation may be chosen using the `interp` keyword argument in
`loadset`.

The parameter is kept as a separate axis so that you can load S-parameters,
Y-parameters, Z-parameters and the like into one `AxisArray`.

You can convert between the various formats (`RealImag`, `dBAngle`, `MagAngle`):

```
julia> reformat(RealImag, A)
6-dimensional AxisArray{Float64,6,...} with axes:
    :parameter, Symbol[:S]
    :to, Base.OneTo(2)
    :from, Base.OneTo(2)
    :f, [6.0, 6.05, 6.1, 6.15, 6.2, 6.25, 6.3, 6.35, 6.4, 6.45  …  15.55, 15.6, 15.65, 15.7, 15.75, 15.8, 15.85, 15.9, 15.95, 16.0]
    :BusLengthControl, [100.0]
    :format, Symbol[:real, :imag]
And data, a 1×2×2×798×1×2 Array{Float64,6}:
[:, :, 1, 1, 1, 1] =
 0.998012  5.17103e-6

[:, :, 2, 1, 1, 1] =
 5.17103e-6  0.900621

...
```

Take care as the axes are reordered, so it is better to use the special Axis-based indexing
(e.g. `A[Axis{:format}(:mag), ...]`).

Once you have imported the data and formatted it to your liking then you can:

- Plot heatmaps with, for example, one axis as frequency and one axis as a swept parameter, etc.
- Do peak-finding as a function of a swept parameter
- Do other fun things

## Caveats

Touchstone v2 is not yet supported.
