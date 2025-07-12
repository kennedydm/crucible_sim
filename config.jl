
# SimConfig: Input structure defining the simulation configuration with defaults
mutable struct SimConfig
    structure_seed              :: Int
    noise_seed                  :: Int
    num_dimensions              :: Int
    num_nodes                   :: Int
    #
    input_noise_sigma           :: Float64
    model_noise_sigma           :: Float64
    random_fault_freq           :: Float64
    constraint_margin           :: Float64
    min_knots                   :: Int
    max_knots                   :: Int
    min_scale_knots             :: Int
    max_scale_knots             :: Int
    knot_feedback               :: Float64
    #
    enable_input_noise          :: Bool
    enable_model_noise          :: Bool
    enable_constraints          :: Bool
    enable_faults               :: Bool
    enable_iso_optimal          :: Bool
    enable_comp_scale_inputs    :: Bool
    enable_total_scale_input    :: Bool
    #
    quiet_init                  :: Bool
    #
    function SimConfig()
        ret = new()
        
        # defaults
        ret.structure_seed = 0
        ret.noise_seed = 0
        ret.num_dimensions = 1
        ret.num_nodes = 1
        #
        ret.input_noise_sigma = 0.003
        ret.model_noise_sigma = 0.03
        ret.random_fault_freq = 0.05
        ret.constraint_margin = 0.05
        ret.min_knots = 10
        ret.max_knots = 20
        ret.min_scale_knots = 5
        ret.max_scale_knots = 10
        ret.knot_feedback = 0.5
        #
        ret.enable_input_noise = true
        ret.enable_model_noise = true
        ret.enable_constraints = true
        ret.enable_faults = true
        ret.enable_iso_optimal = true
        ret.enable_comp_scale_inputs = true
        ret.enable_total_scale_input = true
        #
        ret.quiet_init = false
        
        return ret
    end
end
