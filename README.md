# Touchstone

[![Build Status](https://travis-ci.org/ajkeller34/Touchstone.jl.svg?branch=master)](https://travis-ci.org/ajkeller34/Touchstone.jl)

[![Coverage Status](https://coveralls.io/repos/ajkeller34/Touchstone.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/ajkeller34/Touchstone.jl?branch=master)

[![codecov.io](http://codecov.io/github/ajkeller34/Touchstone.jl/coverage.svg?branch=master)](http://codecov.io/github/ajkeller34/Touchstone.jl?branch=master)

Reads Touchstone files into [AxisArrays](https://github.com/JuliaArrays/AxisArrays.jl).
Supports Sonnet parameter sweeps.

## What's a Touchstone file?

The gory details:

- [Touchstone v1.1 specification](https://ibis.org/connector/touchstone_spec11.pdf)
- [Touchstone v2.0 specification](http://www.ibis.org/touchstone_ver2.0/touchstone_ver2_0.pdf)

## Usage

To load a Touchstone file with extension `.s2p`, `.s3p`, etc. into an
[AxisArray](http://github.com/JuliaArrays/AxisArrays.jl), it could not be
any easier:

```
julia> using Touchstone, FileIO

julia> load("BusResonator_16\\BusResonator_16_param01.s2p")
4-dimensional AxisArray{Float64,4,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:s11, :s21, :s12, :s22]
    :f, [8.0, 8.02, 8.04, 8.06, 8.08, 8.1, 8.12, 8.14, 8.16, 8.18  …  12.82, 12.84, 12.86, 12.88, 12.9, 12.92, 12.94, 12.96, 12.98, 13.0]
    :BusLengthControl, [280.0]
And data, a 2×4×848×1 Array{Float64,4}:
[:, :, 1, 1] =
   0.999999     1.905e-5     1.905e-5    0.999997
 -13.17      -114.0       -114.0       -34.73

[:, :, 2, 1] =
   0.999999     1.874e-5     1.874e-5    0.999997
 -13.21      -114.0       -114.0       -34.83

[:, :, 3, 1] =
   0.999999     1.838e-5     1.838e-5    0.999997
 -13.24      -114.1       -114.1       -34.92

...

[:, :, 846, 1] =
   0.999998   0.000209   0.000209    0.999995
 -21.35      52.665     52.665     -53.32

[:, :, 847, 1] =
   0.999998   0.0002085   0.0002085    0.999995
 -21.39      52.596      52.596      -53.42

[:, :, 848, 1] =
   0.999998   0.000208   0.000208    0.999996
 -21.42      52.528     52.528     -53.52
```

Notice how some parameter appeared as a fourth dimension? That parameter was
included as a comment by Sonnet when the .s2p file was exported. Here's the
fun part. If you have a parameter sweep or even a multi-parameter sweep saved
as a collection of .s2p files in a folder, you can use `loadset` to import
everything into *one* AxisArray:

```
julia> loadset("BusResonator_16\\")
4-dimensional AxisArray{Float64,4,...} with axes:
    :format, Symbol[:mag, :angle]
    :parameter, Symbol[:s11, :s21, :s12, :s22]
    :f, [8.0, 8.02, 8.04, 8.06, 8.08, 8.1, 8.12, 8.14, 8.16, 8.18  …  12.6132, 12.621, 12.629, 12.6372, 12.6455, 12.6541, 12.6628, 12.6718, 12.681, 12.6904]
    :BusLengthControl, [280.0, 510.0, 740.0, 970.0, 1200.0, 1430.0, 1660.0, 1890.0, 2120.0, 2350.0, 2580.0]
And data, a 2×4×5624×11 Array{Float64,4}:
[:, :, 1, 1] =
   0.999999     1.905e-5     1.905e-5    0.999997
 -13.17      -114.0       -114.0       -34.73

[:, :, 2, 1] =
   0.999999     1.874e-5     1.874e-5    0.999997
 -13.21      -114.0       -114.0       -34.83

[:, :, 3, 1] =
   0.999999     1.838e-5     1.838e-5    0.999997
 -13.24      -114.1       -114.1       -34.92

...
```

In this way, you can then:

- Plot heatmaps with, for example, one axis as frequency and one axis as a swept parameter, etc.
- Do peak-finding as a function of a swept parameter
- Other fun things

## Caveats

Touchstone v2 is not yet supported. Probably has bugs. Needs many more tests.
