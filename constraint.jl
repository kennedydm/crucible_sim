
# SimConstraintRegion: Defines a nonconvex constraint region between two dimensions
mutable struct SimConstraintRegion
    lhs_dimension       :: Int
    rhs_dimension       :: Int
    constraint_margin   :: Float64
    inverted            :: Bool
    spline              :: SimSpline
    #
    function SimConstraintRegion(lhs::Int, rhs::Int, margin::Float64, inverted::Bool, spline::SimSpline)
        ret = new()
        ret.lhs_dimension = lhs
        ret.rhs_dimension = rhs
        ret.constraint_margin = margin
        ret.inverted = inverted
        ret.spline = spline
        return ret
    end
end

function constraint_eval(cr::SimConstraintRegion, u0::Float64, u1::Float64)
    y = spline_eval(cr.spline, u0)
    margin = cr.constraint_margin
    if (!cr.inverted && u1 > y + margin) || (cr.inverted && u1 < y - margin)
        return NaN
    end
    return 1.0
end