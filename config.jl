
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
    fidelity_power              :: Float64
    inversion_rate              :: Float64
    flattening_rate             :: Float64
    random_fault_rate           :: Float64
    random_infeasible_rate      :: Float64
    fault_degredation_rate      :: Float64
    constraint_input_margin     :: Float64
    constraint_optimal_margin   :: Float64
    min_knots                   :: Int
    max_knots                   :: Int
    min_scale_knots             :: Int
    max_scale_knots             :: Int
    min_constraint_knots        :: Int
    max_constraint_knots        :: Int
    max_skew_magnitude          :: Float64
    knot_feedback               :: Float64
    #
    dyn_model_inp_vel_mag       :: Float64
    dyn_model_gen_vel_mag       :: Float64
    #
    enable_input_noise          :: Bool
    enable_model_noise          :: Bool
    enable_dynamic              :: Bool
    enable_dynamic_spline       :: Bool
    enable_constraints          :: Bool
    enable_inversion            :: Bool
    enable_flattening           :: Bool
    enable_faults               :: Bool
    enable_iso_optimal          :: Bool
    enable_skewing              :: Bool
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
        ret.model_noise_sigma = 0.01
        ret.fidelity_power = 1.5
        ret.inversion_rate = 0.3
        ret.flattening_rate = 0.3
        ret.random_fault_rate = 0.02
        ret.random_infeasible_rate = 0.02
        ret.fault_degredation_rate = 0.5
        ret.constraint_input_margin = 0.05
        ret.constraint_optimal_margin = 0.05
        ret.min_knots = 10
        ret.max_knots = 20
        ret.min_scale_knots = 5
        ret.max_scale_knots = 10
        ret.min_constraint_knots = 10
        ret.max_constraint_knots = 20
        ret.max_skew_magnitude = 0.3
        ret.knot_feedback = 0.5
        ret.dyn_model_inp_vel_mag = 0.05 # per 1000 iterations
        ret.dyn_model_gen_vel_mag = 0.05 # per 1000 iterations
        #
        ret.enable_input_noise = true
        ret.enable_model_noise = true
        ret.enable_dynamic = true
        ret.enable_dynamic_spline = true
        ret.enable_constraints = true
        ret.enable_flattening = true
        ret.enable_faults = true
        ret.enable_inversion = true
        ret.enable_iso_optimal = true
        ret.enable_skewing = true
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

    sim_log(io, config.quiet_init, string("- structure_seed             : ", config.structure_seed              ))
    sim_log(io, config.quiet_init, string("- noise_seed                 : ", config.noise_seed                  ))
    sim_log(io, config.quiet_init, string("- num_dimensions             : ", config.num_dimensions              ))
    sim_log(io, config.quiet_init, string("- num_nodes                  : ", config.num_nodes                   ))
    #
    sim_log(io, config.quiet_init, string("- input_noise_sigma          : ", config.input_noise_sigma           ))
    sim_log(io, config.quiet_init, string("- model_noise_sigma          : ", config.model_noise_sigma           ))
    sim_log(io, config.quiet_init, string("- fidelity_power             : ", config.fidelity_power              ))
    sim_log(io, config.quiet_init, string("- inversion_rate             : ", config.inversion_rate              ))
    sim_log(io, config.quiet_init, string("- flattening_rate            : ", config.flattening_rate             ))
    sim_log(io, config.quiet_init, string("- random_fault_rate          : ", config.random_fault_rate           ))
    sim_log(io, config.quiet_init, string("- random_infeasible_rate     : ", config.random_infeasible_rate      ))
    sim_log(io, config.quiet_init, string("- fault_degredation_rate     : ", config.fault_degredation_rate      ))
    sim_log(io, config.quiet_init, string("- constraint_input_margin    : ", config.constraint_input_margin     ))
    sim_log(io, config.quiet_init, string("- constraint_optimal_margin  : ", config.constraint_optimal_margin   ))
    sim_log(io, config.quiet_init, string("- min_knots                  : ", config.min_knots                   ))
    sim_log(io, config.quiet_init, string("- max_knots                  : ", config.max_knots                   ))
    sim_log(io, config.quiet_init, string("- min_scale_knots            : ", config.min_scale_knots             ))
    sim_log(io, config.quiet_init, string("- max_scale_knots            : ", config.max_scale_knots             ))
    sim_log(io, config.quiet_init, string("- min_constraint_knots       : ", config.min_constraint_knots        ))
    sim_log(io, config.quiet_init, string("- max_constraint_knots       : ", config.max_constraint_knots        ))
    sim_log(io, config.quiet_init, string("- max_skew_magnitude         : ", config.max_skew_magnitude          ))
    sim_log(io, config.quiet_init, string("- knot_feedback              : ", config.knot_feedback               ))
    sim_log(io, config.quiet_init, string("- dyn_model_inp_vel_mag      : ", config.dyn_model_inp_vel_mag       ))
    sim_log(io, config.quiet_init, string("- dyn_model_gen_vel_mag      : ", config.dyn_model_gen_vel_mag       ))
    #   
    sim_log(io, config.quiet_init, string("- enable_input_noise         : ", config.enable_input_noise          ))
    sim_log(io, config.quiet_init, string("- enable_model_noise         : ", config.enable_model_noise          ))
    sim_log(io, config.quiet_init, string("- enable_dynamic             : ", config.enable_dynamic              ))
    sim_log(io, config.quiet_init, string("- enable_dynamic_spline      : ", config.enable_dynamic_spline       ))
    sim_log(io, config.quiet_init, string("- enable_constraints         : ", config.enable_constraints          ))
    sim_log(io, config.quiet_init, string("- enable_inversion           : ", config.enable_inversion            ))
    sim_log(io, config.quiet_init, string("- enable_flattening          : ", config.enable_flattening           ))
    sim_log(io, config.quiet_init, string("- enable_faults              : ", config.enable_faults               ))
    sim_log(io, config.quiet_init, string("- enable_iso_optimal         : ", config.enable_iso_optimal          ))
    sim_log(io, config.quiet_init, string("- enable_skewing             : ", config.enable_skewing              ))
    sim_log(io, config.quiet_init, string("- enable_comp_scale_inputs   : ", config.enable_comp_scale_inputs    ))
    sim_log(io, config.quiet_init, string("- enable_total_scale_input   : ", config.enable_total_scale_input    ))
    #   
    sim_log(io, config.quiet_init, string("- quiet_init                 : ", config.quiet_init                  ))
    sim_log(io, config.quiet_init, string("- save_debug_figs            : ", config.save_debug_figs             ))
    

end