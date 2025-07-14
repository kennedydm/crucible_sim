
# SimStruct: Holds the all simulation structural information for execution.
mutable struct SimStruct
    rng         :: Xoshiro
    config      :: SimConfig
    io          :: IOStream
    
    # data
    models              :: Array{Any}
    comps               :: Array{Any}
    faults              :: Array{Any}
    input_map           :: Array{Int}
    offset_inputs       :: Array{Float64}
    offset_adversarial  :: Array{Float64}
    scale_spline        :: SimSpline

    #
    num_fail_modes          :: Int
    num_inputs              :: Int
    num_comp_fun            :: Int
    
    #
    num_iterations          :: Int
    num_function_evals      :: Int
    adversarial_fitness     :: Float64
    runtime_adv_factor      :: Float64
    adversarial_spline      :: SimSpline
    next_dyn_input_remap    :: Int
    next_dyn_input_shift    :: Int

    #
    function SimStruct(config::SimConfig)
        ret = new()
        ret.models = []
        ret.comps = []
        ret.faults = []
        ret.input_map = []
        ret.offset_inputs = []
        ret.offset_adversarial = []
        ret.config = config
        ret.num_fail_modes = 0
        ret.num_inputs = 0
        ret.num_comp_fun = 0
        ret.num_iterations = 0
        ret.num_function_evals = 0
        ret.adversarial_fitness = 0.0
        ret.runtime_adv_factor = 1.0
        ret.next_dyn_input_remap = 1000
        ret.next_dyn_input_shift = 1000
        ret.rng = Xoshiro(config.structure_seed)
        return ret
    end

end