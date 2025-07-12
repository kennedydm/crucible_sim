
# SimStruct: Holds the all simulation structural information for execution.
mutable struct SimStruct
    rng         :: Xoshiro
    config      :: SimConfig
    io          :: IOStream
    
    # data
    models          :: Array{Any}
    comps           :: Array{Any}
    faults          :: Array{Any}
    scale_spline    :: SimSpline

    #
    num_fail_modes          :: Int
    num_inputs              :: Int
    num_comp_fun            :: Int
    
    #
    num_iterations          :: Int
    num_function_evals      :: Int
    
    #
    function SimStruct(config::SimConfig)
        ret = new()
        ret.models = []
        ret.comps = []
        ret.faults = []
        ret.config = config
        ret.num_fail_modes = 0
        ret.num_inputs = 0
        ret.num_comp_fun = 0
        ret.num_iterations = 0
        ret.num_function_evals = 0
        ret.rng = Xoshiro(config.structure_seed)
        return ret
    end

end