
# SimCouplingRegion: Defines a coupling region between two dimensions
mutable struct SimCouplingRegion
    lhs                     :: Int
    rhs                     :: Int
    constraint_input_margin :: Float64
    spline                  :: SimSpline
    xskew                   :: Float64
    yskew                   :: Float64
    inverted                :: Bool
    #
    function SimCouplingRegion(lhs::Int, rhs::Int, margin::Float64, inverted::Bool, spline::SimSpline, xskew::Float64, yskew::Float64)
        ret = new()
        ret.lhs = lhs
        ret.rhs = rhs
        ret.constraint_input_margin = margin
        ret.inverted = inverted
        ret.spline = spline
        ret.xskew = xskew
        ret.yskew = yskew
        return ret
    end
end

function constraint_eval(cr::SimCouplingRegion, u0::Float64, u1::Float64)
    y = spline_eval(cr.spline, u0)
    margin = cr.constraint_input_margin
    if (!cr.inverted && u1 > y + margin) || (cr.inverted && u1 < y - margin)
        return NaN
    end
    return 1.0
end