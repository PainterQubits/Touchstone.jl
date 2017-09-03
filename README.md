# Touchstone

[![Build Status](https://travis-ci.org/PainterQubits/Touchstone.jl.svg?branch=master)](https://travis-ci.org/PainterQubits/Touchstone.jl)
[![Coverage Status](https://coveralls.io/repos/PainterQubits/Touchstone.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/PainterQubits/Touchstone.jl?branch=master)
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

julia> load("/Users/ajkeller/Desktop/BusResonator_16/BusResonator_16_param01.s2p")
6-dimensional AxisArray{Float64,6,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:S]
    :to, Base.OneTo(2)
    :from, Base.OneTo(2)
    :f, [8.0, 8.02, 8.04, 8.06, 8.08, 8.1, 8.12, 8.14, 8.16, 8.18  …  12.82, 12.84, 12.86, 12.88, 12.9, 12.92, 12.94, 12.96, 12.98, 13.0]
    :BusLengthControl, [280.0]
And data, a 2×1×2×2×848×1 Array{Float64,6}:
[:, :, 1, 1, 1, 1] =
   0.999999
 -13.17    

[:, :, 2, 1, 1, 1] =
    1.905e-5
 -114.0     

...
```

Notice how some parameter appeared as a fourth dimension? That parameter was
included as a comment by Sonnet when the .s2p file was exported. Here's the
fun part. If you have a parameter sweep or even a multi-parameter sweep saved
as a collection of .s2p files in a folder, for example as exported by Sonnet,
you can use `loadset` to import everything into *one* AxisArray:

```
julia> loadset("/Users/ajkeller/Desktop/BusResonator_16/")
6-dimensional AxisArray{Float64,6,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:S]
    :to, [1, 2]
    :from, [1, 2]
    :f, [8.0, 8.02, 8.04, 8.06, 8.08, 8.1, 8.12, 8.14, 8.16, 8.18  …  12.82, 12.84, 12.86, 12.88, 12.9, 12.92, 12.94, 12.96, 12.98, 13.0]
    :BusLengthControl, [280.0, 510.0, 740.0, 970.0, 1200.0, 1430.0, 1660.0, 1890.0, 2120.0, 2350.0, 2580.0]
And data, a 2×1×2×2×5624×11 Array{Float64,6}:
[:, :, 1, 1, 1, 1] =
   0.999999
 -13.17    

[:, :, 2, 1, 1, 1] =
    1.905e-5
 -114.0     

...
```

Note that sometimes Sonnet will save files with different frequency axes in one parameter
sweep depending on what adaptive band synthesis chose to do. If this happens, all of the
frequency axes are merged, and missing values are interpolated. `Linear()` or `Constant()`
(nearest-neighbor) interpolation may be chosen using the `interp` keyword argument in
`loadset`.

The parameter is kept as a separate axis so that you can load S-parameters,
Y-parameters, Z-parameters and the like into one `AxisArray`.

Once you have imported the data, then you can:

- Plot heatmaps with, for example, one axis as frequency and one axis as a swept parameter, etc.
- Do peak-finding as a function of a swept parameter
- Other fun things

## Caveats

Touchstone v2 is not yet supported. Probably has bugs. Needs many more tests.
