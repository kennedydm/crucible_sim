
# SimCompositionFunction: Defines an composition function, mapping simulation inputs to response splines and scale factors
mutable struct SimCompositionFunction
    num_models              :: Int
    model_map               :: Array{Int}
    iso_optimal_limit       :: Float64
    scale_spline            :: SimSpline
    #
    coupling                :: Array{Any}
    #
    function SimCompositionFunction(config::SimConfig, rng::Xoshiro, map_in::Array{Int})
        ret = new()
        ret.num_models = length(map_in)
        ret.model_map = map_in
        ret.iso_optimal_limit = (0.8 + 0.2 * rand(rng))
        ret.scale_spline = SimSpline(config, rng, rand(rng, config.min_scale_knots:config.max_scale_knots))
        #
        ret.coupling = []
        #
        return ret
    end
end