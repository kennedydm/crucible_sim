
# SimModel: Holds the model implementation
mutable struct SimModel
    gen_spline :: SimSpline       # function that converts input x to output u.
    mdl_spline :: SimSpline       # function that converts input u to output value m(u).
    max_constrained :: Float64
    #
    function SimModel(config::SimConfig, rng::Xoshiro)
        ret = new()
        gen_knots = rand(rng, config.min_knots:config.max_knots)
        mdl_knots = rand(rng, config.min_knots:config.max_knots)
        ret.gen_spline = SimSpline(config, rng, gen_knots)
        ret.mdl_spline = SimSpline(config, rng, mdl_knots)
        ret.max_constrained = 1.0
        return ret
    end
end

function model_query(mdl::SimModel, x::Float64)
    u = spline_eval(mdl.gen_spline, x)
    return spline_eval(mdl.mdl_spline, u), u
end