
# SimCompositionFunction: Defines an composition function, mapping simulation inputs to response splines and scale factors
mutable struct SimCompositionFunction
    num_models              :: Int
    model_map               :: Array{Int}
    scale_factors           :: Array{Float64}
    sum_scale_factors       :: Float64
    iso_optimal_limit       :: Float64
    scale_spline            :: SimSpline
    #
    # num_constraint_pairs    :: Int
    constraints             :: Array{Any}
    #
    function SimCompositionFunction(config::SimConfig, rng::Xoshiro, map_in::Array{Int})
        ret = new()
        ret.num_models = length(map_in)
        ret.model_map = map_in
        ret.scale_factors = rand(rng, ret.num_models) .* 0.95 .+ 0.5
        ret.sum_scale_factors = sum(ret.scale_factors)
        ret.iso_optimal_limit = (0.8 + 0.2 * rand(rng)) * ret.sum_scale_factors
        ret.scale_spline = SimSpline(config, rng, rand(rng, config.min_scale_knots:config.max_scale_knots))
        #
        ret.constraints = []
        #
        return ret
    end
end