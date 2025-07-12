
# SimConfig: Input structure defining the simulation configuration with defaults
mutable struct SimConfig
    logfile                     :: String
    debug_folder                :: String
    #
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
    save_debug_figs             :: Bool
    #
    function SimConfig()
        ret = new()
        
        # defaults
        ret.logfile = "logfile.txt"
        ret.debug_folder = ""
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
        ret.save_debug_figs = false
        
        return ret
    end
end


function config_log_inputs(io::IOStream, config::SimConfig)

    sim_log(io, config.quiet_init, "Configuration Parameters:")

    sim_log(io, config.quiet_init, string("- structure_seed             : ", config.structure_seed           ))
    sim_log(io, config.quiet_init, string("- noise_seed                 : ", config.noise_seed               ))
    sim_log(io, config.quiet_init, string("- num_dimensions             : ", config.num_dimensions           ))
    sim_log(io, config.quiet_init, string("- num_nodes                  : ", config.num_nodes                ))
    #
    sim_log(io, config.quiet_init, string("- input_noise_sigma          : ", config.input_noise_sigma        ))
    sim_log(io, config.quiet_init, string("- model_noise_sigma          : ", config.model_noise_sigma        ))
    sim_log(io, config.quiet_init, string("- random_fault_freq          : ", config.random_fault_freq        ))
    sim_log(io, config.quiet_init, string("- constraint_margin          : ", config.constraint_margin        ))
    sim_log(io, config.quiet_init, string("- min_knots                  : ", config.min_knots                ))
    sim_log(io, config.quiet_init, string("- max_knots                  : ", config.max_knots                ))
    sim_log(io, config.quiet_init, string("- min_scale_knots            : ", config.min_scale_knots          ))
    sim_log(io, config.quiet_init, string("- max_scale_knots            : ", config.max_scale_knots          ))
    sim_log(io, config.quiet_init, string("- knot_feedback              : ", config.knot_feedback            ))
    #
    sim_log(io, config.quiet_init, string("- enable_input_noise         : ", config.enable_input_noise       ))
    sim_log(io, config.quiet_init, string("- enable_model_noise         : ", config.enable_model_noise       ))
    sim_log(io, config.quiet_init, string("- enable_constraints         : ", config.enable_constraints       ))
    sim_log(io, config.quiet_init, string("- enable_faults              : ", config.enable_faults            ))
    sim_log(io, config.quiet_init, string("- enable_iso_optimal         : ", config.enable_iso_optimal       ))
    sim_log(io, config.quiet_init, string("- enable_comp_scale_inputs   : ", config.enable_comp_scale_inputs ))
    sim_log(io, config.quiet_init, string("- enable_total_scale_input   : ", config.enable_total_scale_input ))
    #
    sim_log(io, config.quiet_init, string("- quiet_init                 : ", config.quiet_init               ))

end