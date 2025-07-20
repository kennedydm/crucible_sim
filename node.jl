
# SimNode: Contains network node structural information
mutable struct SimNode
    #
    models              :: Array{Any}
    comps               :: Array{Any}
    faults              :: Array{Any}
    scale_spline        :: SimSpline
    node_weight         :: Float64
    valid_exits         :: Array{Int}
    num_fail_modes      :: Int
    base_input_idx      :: Int
    scale_input_idx     :: Int
    #
    function SimNode(rng::Xoshiro)
        ret = new()
        ret.models = []
        ret.comps = []
        ret.faults = []
        ret.valid_exits = []
        ret.node_weight = rand(rng) * 0.95 + 0.05
        ret.num_fail_modes = 1
        return ret
    end
end
