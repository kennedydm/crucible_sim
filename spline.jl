
# SimSpline: Generic spline that maps an input value to an output value
mutable struct SimSpline
    interp
    #
    function SimSpline(config::SimConfig, rng::Xoshiro, N::Int)
        y = fill(0.0, N)
        y[1] = rand(rng) - rand(rng)
        for i in 2:N
            y[i] = y[i-1] * config.knot_feedback + rand(rng) - rand(rng)
        end
        y = y .- minimum(y) # shift to positive
        y = y ./ maximum(y) # normalize
        x = 0:1/(N-1):1
        itp = cubic_spline_interpolation(x, y)
        ret = new()
        ret.interp = itp
        return ret
    end
end

function spline_eval(s::SimSpline, x::Float64)
    return Float64(clamp(s.interp(clamp(x, 0, 1)), 0, 1))
end
