
# SimModel: Holds the model implementation
mutable struct SimModel
    gen_spline      :: SimSpline       # function that converts input x to output u.
    mdl_spline      :: SimSpline       # function that converts input u to output value m(u).
    flat            :: SimFlatten
    invert          :: SimInvert
    scale_factor    :: Float64
    #
    function SimModel(config::SimConfig, rng::Xoshiro)
        ret = new()
        gen_knots = rand(rng, config.min_knots:config.max_knots)
        mdl_knots = rand(rng, config.min_knots:config.max_knots)
        ret.gen_spline = SimSpline(config, rng, gen_knots)
        ret.mdl_spline = SimSpline(config, rng, mdl_knots)
        ret.flat = SimFlatten(false, rng)
        ret.invert = SimInvert(false, rng)
        ret.scale_factor = rand() * 0.95 + 0.05
        return ret
    end
end

function model_query(mdl::SimModel, x::Float64)
    u = spline_eval(mdl.gen_spline, x)
    y = spline_eval(mdl.mdl_spline, u)

    if mdl.flat.enabled
        if x > mdl.flat.x0 && x < mdl.flat.x1 && y > mdl.flat.y0 && y < mdl.flat.y1
            y = mdl.flat.override
        end
    end

    if mdl.invert.enabled
        if x > mdl.invert.x0 && x < mdl.invert.x1 && y > mdl.invert.y0 && y < mdl.invert.y1
            y = mdl.invert.y0 + mdl.invert.y1 - y
        end
    end

    return y, u
end