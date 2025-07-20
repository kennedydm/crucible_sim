


# SimStruct: Holds the all simulation structural information for execution.
mutable struct SimStruct
    rng         :: Xoshiro
    config      :: SimConfig
    io          :: IOStream
    
    # data
    nodes               :: Array{Any}
    nodes_visit_req     :: Array{Int}
    input_map           :: Array{Int}
    nominal_path        :: Array{Int}
    offset_inputs       :: Array{Float64}
    offset_adversarial  :: Array{Float64}
    sum_node_weights    :: Float64

    #
    num_inputs              :: Int
    num_iterations          :: Int
    num_function_evals      :: Int
    adversarial_fitness     :: Float64
    runtime_adv_factor      :: Float64
    adversarial_spline      :: SimSpline
    next_dyn_input_remap    :: Int
    next_dyn_input_shift    :: Int
    next_dyn_network_remap  :: Int

    #
    function SimStruct(config::SimConfig)
        ret = new()
        ret.input_map = []
        ret.nominal_path = []
        ret.offset_inputs = []
        ret.offset_adversarial = []
        ret.nodes = []
        ret.nodes_visit_req = []
        ret.config = config
        ret.sum_node_weights = 0.0
        ret.num_inputs = 0
        ret.num_iterations = 0
        ret.num_function_evals = 0
        ret.adversarial_fitness = 0.0
        ret.runtime_adv_factor = 1.0
        ret.next_dyn_input_remap = 1000
        ret.next_dyn_input_shift = 1000
        ret.next_dyn_network_remap = 1000
        ret.rng = Xoshiro(config.structure_seed)
        return ret
    end

end