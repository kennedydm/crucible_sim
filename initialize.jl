# sim_init: Builds the simulation structure for later querying by an optimizer
function sim_init(config::SimConfig)

    sim = SimStruct(config)
    num_dimensions = sim.config.num_dimensions
    num_nodes = sim.config.num_nodes

    debug_folder = string("./debug/", sim.config.debug_folder)
    if ispath(debug_folder) && config.save_debug_figs
        rm(debug_folder, recursive=true) # remove old folder before saving new figures
    end

    sim.io = open(config.logfile, "w")
    
    sim_log_fence(sim.io, sim.config.quiet_init)
    sim_log(sim.io, sim.config.quiet_init, string("Initializing Crucible Simulation"))
    sim_log_fence(sim.io, sim.config.quiet_init)
    
    config_log_inputs(sim.io, sim.config)

    if 1 > num_dimensions
        sim_log(sim.io, sim.config.quiet_init, string("Error, not enough dimensions."))
        return
    end
    if 1 > num_nodes
        sim_log(sim.io, sim.config.quiet_init, string("Error, not enough nodes."))
        return
    end
    

    sim_log(sim.io, sim.config.quiet_init, string("..."))
    sim_log_fence(sim.io, sim.config.quiet_init)
    sim_log(sim.io, sim.config.quiet_init, string("Constructing Node 1"))
    sim_log_fence(sim.io, sim.config.quiet_init)
    
    
    # create model functions for each dimension
    sim_log(sim.io, sim.config.quiet_init, string("Creating Models: ", num_dimensions))
    for i in 1:num_dimensions
        mdl = SimModel(sim.config, sim.rng)
        push!(sim.models, mdl)
        if config.save_debug_figs
            sim_plot_spline(mdl.gen_spline, "x", "g(x)", string("Model: ", i, " Governing Basic Spline"), debug_folder, string("mdl_", i, "_gov_fun.png"))
            sim_plot_spline(mdl.mdl_spline, "u", "f(u)", string("Model: ", i, " Model Basic Spline"), debug_folder, string("mdl_", i, "_mdl_fun.png"))
            sim_plot_model(mdl, string("Model: ", i, " Response"), debug_folder, string("mdl_", i, "_mdl_resp.png"))
        end
    end
    sim.num_inputs += num_dimensions
    
    
    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Composition Functions"))
    
    # create composition functions
    max_comp_fun = floor(Int, sqrt(num_dimensions))

    # mapping of dimensions to composition functions
    temp = zeros(Int, num_dimensions)
    for i in 1:num_dimensions
        temp[i] = rand(sim.rng, 1:max_comp_fun)
    end

    unq = sort(unique(temp))
    num_comp_fun = length(unq)

    sim.comps = Array{Any}(undef, num_comp_fun)
    for i in 1:length(unq)
        idx = findall(x -> x == unq[i], temp)
        so = SimCompositionFunction(sim.config, sim.rng, idx)
        sim_log(sim.io, sim.config.quiet_init, string("- New Comp Function: "))
        sim_log(sim.io, sim.config.quiet_init, string("  - Num Models   : ", so.num_models))
        sim_log(sim.io, sim.config.quiet_init, string("  - Model Mapping: ", so.model_map))
        sim_log(sim.io, sim.config.quiet_init, string("  - Iso-Optimal Limit : ", so.iso_optimal_limit))
        if config.save_debug_figs
            sim_plot_spline(so.scale_spline, "x", "s(x)", string("Comp ", i, " Scale Factor Basic Spline"), debug_folder, string("comp_", i, "_scale_fun.png"))
        end
        #
        sim.comps[i] = so
    end

    sim_log(sim.io, sim.config.quiet_init, string("- Total number of Composition Functions: ", num_comp_fun))
    
    sim.num_comp_fun = num_comp_fun
    sim.num_inputs += num_comp_fun   # composition function scale factors


    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Output Scale Factor"))
    sim.scale_spline = SimSpline(sim.config, sim.rng, rand(sim.rng, config.min_scale_knots:config.max_scale_knots))
    if config.save_debug_figs
        sim_plot_spline(sim.scale_spline, "x", "s(x)", "Output Scale Factor Basic Spline", debug_folder, string("out_scale_fun.png"))
    end
    sim.num_inputs += 1


    # feature seeds
    flat_rng = Xoshiro(rand(sim.rng, 1:100000))
    invert_rng = Xoshiro(rand(sim.rng, 1:100000))
    fault_rng = Xoshiro(rand(sim.rng, 1:100000))
    couple_rng = Xoshiro(rand(sim.rng, 1:100000))

    if config.enable_flattening
        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Flattening"))        
        for i in 1:num_dimensions
            flat = SimFlatten(rand(flat_rng) < sim.config.flattening_rate, flat_rng)
            sim.models[i].flat = flat
            if flat.enabled
                sim_log(sim.io, sim.config.quiet_init, string("- Flattening enabled on Dimension: ", i, ", at: (", flat.x0, ", ", flat.y0, ")-(", flat.x1, ", ", flat.y1, ")-(", flat.override, ")"))
                if config.save_debug_figs
                    sim_plot_model_flat(sim.models[i], flat, string("Model: ", i, " Response with Flattening"), debug_folder, string("mdl_", i, "_mdl_resp_flat.png"))
                end
            end
        end
    end

    if config.enable_inversion
        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Inversions"))        
        for i in 1:num_dimensions
            invert = SimInvert(rand(invert_rng) < sim.config.inversion_rate, invert_rng)
            sim.models[i].invert = invert
            if invert.enabled
                sim_log(sim.io, sim.config.quiet_init, string("- Inversion enabled on Dimension: ", i, ", at: (", invert.x0, ", ", invert.y0, ")-(", invert.x1, ", ", invert.y1, ")"))
                if config.save_debug_figs
                    sim_plot_model_invert(sim.models[i], invert, string("Model: ", i, " Response with Inversion"), debug_folder, string("mdl_", i, "_mdl_resp_invert.png"))
                end
            end
        end
    end

    if config.enable_faults
        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Failure Modes"))
        
        sim.faults = Array{Any}(undef, num_dimensions)
        
        # mapping of faults to dimensions
        temp_mode = zeros(Int, num_dimensions)
        temp_thresh = zeros(Float64, num_dimensions)
        temp_deg_factor = zeros(Float64, num_dimensions)
        for i in 1:num_dimensions
            temp_mode[i] = floor(rand(fault_rng) * rand(fault_rng) * max_comp_fun)
            temp_thresh[i] = rand(fault_rng) * 0.25 + 0.05
            temp_deg_factor[i] = rand(fault_rng)
            if temp_deg_factor[i] > sim.config.fault_degredation_rate
                temp_deg_factor[i] = 0.0
            end
        end
        
        unq = sort(unique(temp_mode))
        num_fail_modes = length(unq)
        sim.num_fail_modes = num_fail_modes-1
        if 1 == num_fail_modes
            sim_log(sim.io, sim.config.quiet_init, string("- No faults present."))
            
        else
            for i in 1:num_fail_modes
                idx = findall(x -> x == unq[i], temp_mode)
                for j in idx
                    sim.faults[j] = SimFault(unq[i], temp_thresh[j], temp_deg_factor[j])
                end
            end

            for i in 1:num_dimensions
                if sim.faults[i].enabled
                    sim_log(sim.io, sim.config.quiet_init, string("- Fault ID: ", sim.faults[i].id, " enabled on Dimension: ", i, ", at: ", sim.faults[i].threshold, ", factor: ", sim.faults[i].factor))
                    if config.save_debug_figs
                        sim_plot_model_fault(sim.models[i], sim.faults[i], string("Model: ", i, " Response with Fault"), debug_folder, string("mdl_", i, "_mdl_resp_fault.png"))
                    end
                end
            end
        end
    end


    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Coupling Pairs"))
    
    for i = 1:num_comp_fun
        temp = sortperm(rand(couple_rng, sim.comps[i].num_models))
        if 2 > length(temp)
            sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", skipping, not enough models."))
            continue
        end
        num_pairs = rand(couple_rng, 1:Int(floor(length(temp)/2)))
        sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", Num Pairs: ", num_pairs))
        
        if 0 < num_pairs
            for j in 1:num_pairs
                lhs = sim.comps[i].model_map[temp[j*2-1]]
                rhs = sim.comps[i].model_map[temp[j*2-0]]
                xskew = (rand(couple_rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                yskew = (rand(couple_rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                inverted = rand(couple_rng) < 0.5
                spline = SimSpline(sim.config, couple_rng, rand(couple_rng, config.min_constraint_knots:config.max_constraint_knots))
                si = SimCouplingRegion(lhs, rhs, sim.config.constraint_input_margin, inverted, spline, xskew, yskew)
                sim_log(sim.io, sim.config.quiet_init, string("  - New Constraint Pair: ", si.lhs, ", ", si.rhs, ", Inverted: ", si.inverted))
                push!(sim.comps[i].coupling, si)
            end
        end
    end

    sim_log(sim.io, sim.config.quiet_init, string("..."))
    sim_log_fence(sim.io, sim.config.quiet_init)
    sim_log(sim.io, sim.config.quiet_init, string("Sim Initialization Complete - Number of Design Inputs: ", sim.num_inputs))
    sim_log_fence(sim.io, sim.config.quiet_init)

    close(sim.io)
    
    return sim
end