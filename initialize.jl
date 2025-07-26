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

    
    # build nodes
    for n in 1:num_nodes

        node = SimNode(sim.rng)

        sim_log(sim.io, sim.config.quiet_init, string("..."))
        sim_log_fence(sim.io, sim.config.quiet_init)
        sim_log(sim.io, sim.config.quiet_init, string("Constructing Node ", n))
        sim_log_fence(sim.io, sim.config.quiet_init)
        
        node.base_input_idx = sim.num_inputs
        # create model functions for each dimension
        sim_log(sim.io, sim.config.quiet_init, string("Creating Models: ", num_dimensions))
        for i in 1:num_dimensions
            mdl = SimModel(sim.config, sim.rng)
            push!(node.models, mdl)
            if config.save_debug_figs
                sim_plot_spline(mdl.gov_spline, "x", "g(x)", string("Model: ", i, " Governing Basic Spline"), debug_folder, string("node_", n, "_mdl_", i, "_gov_fun.png"))
                sim_plot_spline(mdl.mdl_spline, "u", "f(u)", string("Model: ", i, " Model Basic Spline"), debug_folder, string("node_", n, "_mdl_", i, "_mdl_fun.png"))
                sim_plot_model(mdl, string("Model: ", i, " Response"), debug_folder, string("node_", n, "_mdl_", i, "_mdl_resp.png"))
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

        node.comps = Array{Any}(undef, num_comp_fun)
        for i in 1:length(unq)
            idx = findall(x -> x == unq[i], temp)
            so = SimCompositionFunction(sim.config, sim.rng, idx)
            sim_log(sim.io, sim.config.quiet_init, string("- New Comp Function: "))
            sim_log(sim.io, sim.config.quiet_init, string("  - Num Models   : ", so.num_models))
            sim_log(sim.io, sim.config.quiet_init, string("  - Model Mapping: ", so.model_map))
            sim_log(sim.io, sim.config.quiet_init, string("  - Iso-Optimal Limit : ", so.iso_optimal_limit))
            if config.save_debug_figs
                sim_plot_spline(so.scale_spline, "x", "s(x)", string("Comp ", i, " Scale Factor Basic Spline"), debug_folder, string("node_", n, "_comp_", i, "_scale_fun.png"))
            end
            #
            sim.num_inputs += 1
            so.scale_input_idx = sim.num_inputs
            node.comps[i] = so
        end

        sim_log(sim.io, sim.config.quiet_init, string("- Total number of Composition Functions: ", num_comp_fun))
        
        

        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Output Scale Factor"))
        node.scale_spline = SimSpline(sim.config, sim.rng, rand(sim.rng, config.min_scale_knots:config.max_scale_knots))
        if config.save_debug_figs
            sim_plot_spline(node.scale_spline, "x", "s(x)", "Output Scale Factor Basic Spline", debug_folder, string("node_", n, "_out_scale_fun.png"))
        end
        sim.num_inputs += 1
        node.scale_input_idx = sim.num_inputs


        # feature seeds
        flat_rng =        Xoshiro(rand(sim.rng, 1:100000))
        invert_rng =      Xoshiro(rand(sim.rng, 1:100000))
        fault_rng =       Xoshiro(rand(sim.rng, 1:100000))
        couple_rng =      Xoshiro(rand(sim.rng, 1:100000))


        if config.enable_flattening
            sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Flattening"))        
            for i in 1:num_dimensions
                flat = SimFlatten(rand(flat_rng) < sim.config.flattening_rate, flat_rng)
                node.models[i].flat = flat
                if flat.enabled
                    sim_log(sim.io, sim.config.quiet_init, string("- Flattening enabled on Dimension: ", i, ", at: (", flat.x0, ", ", flat.y0, ")-(", flat.x1, ", ", flat.y1, ")-(", flat.override, ")"))
                    if config.save_debug_figs
                        sim_plot_model_flat(node.models[i], flat, string("Model: ", i, " Response with Flattening"), debug_folder, string("node_", n, "_mdl_", i, "_mdl_resp_flat.png"))
                    end
                end
            end
        end

        if config.enable_inversion
            sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Inversions"))        
            for i in 1:num_dimensions
                invert = SimInvert(rand(invert_rng) < sim.config.inversion_rate, invert_rng)
                node.models[i].invert = invert
                if invert.enabled
                    sim_log(sim.io, sim.config.quiet_init, string("- Inversion enabled on Dimension: ", i, ", at: (", invert.x0, ", ", invert.y0, ")-(", invert.x1, ", ", invert.y1, ")"))
                    if config.save_debug_figs
                        sim_plot_model_invert(node.models[i], invert, string("Model: ", i, " Response with Inversion"), debug_folder, string("node_", n, "_mdl_", i, "_mdl_resp_invert.png"))
                    end
                end
            end
        end

        if config.enable_faults
            sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Failure Modes"))
            
            node.faults = Array{Any}(undef, num_dimensions)
            
            # mapping of faults to dimensions
            temp_mode = zeros(Int, num_dimensions)
            temp_thresh = zeros(Float64, num_dimensions)
            temp_deg_factor = zeros(Float64, num_dimensions)
            for i in 1:num_dimensions
                temp_mode[i] = floor(rand(fault_rng) * rand(fault_rng) * max_comp_fun)
                temp_thresh[i] = sim.config.fault_max_thresh * 0.5 * (1.0 + rand(fault_rng))
                temp_deg_factor[i] = rand(fault_rng)
                if temp_deg_factor[i] > sim.config.fault_degredation_rate
                    temp_deg_factor[i] = 0.0
                end
            end
            
            unq = sort(unique(temp_mode))
            num_fail_modes = length(unq)
            node.num_fail_modes = num_fail_modes
            if 1 == num_fail_modes
                sim_log(sim.io, sim.config.quiet_init, string("- No faults present."))
                
            else
                for i in 1:num_fail_modes
                    idx = findall(x -> x == unq[i], temp_mode)
                    for j in idx
                        node.faults[j] = SimFault(unq[i], temp_thresh[j], temp_deg_factor[j])
                    end
                end

                for i in 1:num_dimensions
                    if node.faults[i].enabled
                        sim_log(sim.io, sim.config.quiet_init, string("- Fault ID: ", node.faults[i].id, " enabled on Dimension: ", i, ", at: ", node.faults[i].threshold, ", factor: ", node.faults[i].factor))
                        if config.save_debug_figs
                            sim_plot_model_fault(node.models[i], node.faults[i], string("Model: ", i, " Response with Fault"), debug_folder, string("node_", n, "_mdl_", i, "_mdl_resp_fault.png"))
                        end
                    end
                end
            end
        end


        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Coupling Pairs"))
        
        for i = 1:num_comp_fun
            temp = sortperm(rand(couple_rng, node.comps[i].num_models))
            if 2 > length(temp)
                sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", skipping, not enough models."))
                continue
            end
            num_pairs = rand(couple_rng, 1:Int(floor(length(temp)/2)))
            sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", Num Pairs: ", num_pairs))
            
            if 0 < num_pairs
                for j in 1:num_pairs
                    lhs = node.comps[i].model_map[temp[j*2-1]]
                    rhs = node.comps[i].model_map[temp[j*2-0]]
                    xskew = (rand(couple_rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                    yskew = (rand(couple_rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                    inverted = rand(couple_rng) < 0.5
                    spline = SimSpline(sim.config, couple_rng, rand(couple_rng, config.min_constraint_knots:config.max_constraint_knots))
                    si = SimCouplingRegion(lhs, rhs, sim.config.constraint_input_margin, inverted, spline, xskew, yskew)
                    sim_log(sim.io, sim.config.quiet_init, string("  - New Constraint Pair: ", si.lhs, ", ", si.rhs, ", Inverted: ", si.inverted))
                    push!(node.comps[i].coupling, si)
                end
            end
        end

        push!(sim.nodes, node)
    end

    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Node Paths"))

    # build network
    sim.nominal_path = sortperm(rand(sim.rng, num_nodes))
    sim_log(sim.io, sim.config.quiet_init, string("- Nominal Path: ", sim.nominal_path))
    sim_build_network(sim, sim.rng)

    
    sim.adversarial_spline = SimSpline(sim.config, sim.rng, rand(sim.rng, config.min_adversarial_knots:config.max_adversarial_knots))
    if config.save_debug_figs
        sim_plot_adversarial_spline(sim.adversarial_spline, "Adversarial Offset Basic Spline", debug_folder, string("out_adversarial_fun.png"))
    end

    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Input Mapping"))
    sim.input_map = collect(1:sim.num_inputs); # basline
    if sim.config.enable_input_map
        sim.input_map = sortperm(rand(sim.rng, sim.num_inputs)) # random permutation
    end
    sim_log(sim.io, sim.config.quiet_init, string("- ", sim.input_map))
    sim.next_dyn_input_remap = rand(sim.rng, sim.config.dyn_input_map_freq_min:sim.config.dyn_input_map_freq_max)
    sim.next_dyn_input_shift = rand(sim.rng, sim.config.dyn_input_shift_freq_min:sim.config.dyn_input_shift_freq_max)
    sim.next_dyn_network_remap = rand(sim.rng, sim.config.dyn_network_map_freq_min:sim.config.dyn_network_map_freq_min)
    

    # initialize input offsets
    sim.offset_inputs      = (rand(sim.rng, sim.num_inputs) .- 0.5) .* 2.0
    sim.offset_adversarial = ((rand(sim.rng, sim.num_inputs) .- 0.5) .* 2.0) .* sim.config.adversarial_offset_mag



    sim_log(sim.io, sim.config.quiet_init, string("..."))
    sim_log_fence(sim.io, sim.config.quiet_init)
    sim_log(sim.io, sim.config.quiet_init, string("Sim Initialization Complete - Number of Design Inputs: ", sim.num_inputs))
    sim_log_fence(sim.io, sim.config.quiet_init)

    close(sim.io)
    
    return sim
end


function sim_build_network(sim::SimStruct, temp_rng::Xoshiro)
    
    num_nodes = sim.config.num_nodes

    # visitation requirements - first x
    sim.nodes_visit_req = sim.nominal_path[1:Int(ceil(abs(sim.config.node_visit_required_freq) * num_nodes))]
    if sim.config.enable_node_required_visits
        sim_log(sim.io, sim.config.quiet_init, string("- Required Visits: ", sim.nodes_visit_req))
    end

    # make sure node exits are clear if this is a reconfigure event
    for i in 1:num_nodes
        sim.nodes[i].valid_exits = []
    end

    # make connection list
    for i in 1:(num_nodes - 1)
        lhs = sim.nominal_path[i]
        rhs = sim.nominal_path[i+1]
        push!(sim.nodes[lhs].valid_exits, rhs)
    end

    # total up new node weights
    sim.sum_node_weights = 0.0
    for i in 1:num_nodes
        lhs = sim.nominal_path[i]
        # enhance node weight based on position in nominal path
        if 1 < i
            sim.nodes[lhs].node_weight *= (1 + (i-1)/(num_nodes-1))
        end
        sim.sum_node_weights += sim.nodes[lhs].node_weight
    end

    # add extra random valid
    for i in 1:num_nodes - 1
        if rand(temp_rng) > sim.config.node_random_connection_freq
            continue
        end
        lhs = sim.nominal_path[i]
        rhs = rand(temp_rng, 1:(num_nodes-1))
        rhs = sim.nominal_path[mod1(i + rhs, num_nodes)]
        push!(sim.nodes[lhs].valid_exits, rhs)
        sim.nodes[lhs].valid_exits = unique(sim.nodes[lhs].valid_exits) # remove duplicates
        sim_log(sim.io, sim.config.quiet_init, string("- Adding extra random path: ", lhs, " -> ", rhs))
    end
end