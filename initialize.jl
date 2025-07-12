# sim_init: Builds the simulation structure for later querying by an optimizer
function sim_init(config::SimConfig)

    sim = SimStruct(config)
    num_dimensions = sim.config.num_dimensions
    num_nodes = sim.config.num_nodes


    sim_log(sim.config.quiet_init, string("Initializing Crucible Simulation"))
    sim_log(sim.config.quiet_init, string("- Structure Seed: ", sim.config.structure_seed))
    sim_log(sim.config.quiet_init, string("- Number of Dimensions: ", num_dimensions))
    if 1 > num_dimensions
        sim_log(sim.config.quiet_init, string("Error, not enough dimensions."))
        return
    end

    sim_log(sim.config.quiet_init, string("- Number of Nodes: ", num_nodes))
    if 1 > num_nodes
        sim_log(sim.config.quiet_init, string("Error, not enough nodes."))
        return
    end
    
    sim_log(sim.config.quiet_init, string("...\nConstructing Node 1"))
    
    
    # create model functions for each dimension
    sim_log(sim.config.quiet_init, string("Creating Models: ", num_dimensions))
    for i in 1:num_dimensions
        push!(sim.models, SimModel(sim.config, sim.rng))
    end
    sim.num_inputs += num_dimensions
    
    
    sim_log(sim.config.quiet_init, string("...\nCreating Composition Functions"))
    
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
        sim_log(sim.config.quiet_init, string("- New Comp Function: "))
        sim_log(sim.config.quiet_init, string("  - Num Models   : ", so.num_models))
        sim_log(sim.config.quiet_init, string("  - Model Mapping: ", so.model_map))
        sim_log(sim.config.quiet_init, string("  - Scale Factors: ", so.scale_factors))
        sim_log(sim.config.quiet_init, string("  - Sum Scale Factors: ", so.sum_scale_factors))
        sim_log(sim.config.quiet_init, string("  - Iso-Optimal Limit : ", so.iso_optimal_limit))
        #
        sim.comps[i] = so
    end

    sim_log(sim.config.quiet_init, string("- Total number of Composition Functions: ", num_comp_fun))
    
    sim.num_comp_fun = num_comp_fun
    sim.num_inputs += num_comp_fun   # composition function scale factors


    sim_log(sim.config.quiet_init, string("...\nCreating Output Scale Factor"))
    sim.scale_spline = SimSpline(sim.config, sim.rng, rand(sim.rng, 5:10))
    sim.num_inputs += 1

    if config.enable_faults
        sim_log(sim.config.quiet_init, string("...\nCreating Failure Modes"))
        
        sim.faults = Array{Any}(undef, num_dimensions)
        
        # mapping of dimensions to composition functions
        temp_mode = zeros(Int, num_dimensions)
        temp_thresh = zeros(Float64, num_dimensions)
        for i in 1:num_dimensions
            temp_mode[i] = floor(rand(sim.rng) * rand(sim.rng) * max_comp_fun)
            temp_thresh[i] = rand(sim.rng) * 0.25 + 0.05
        end
        
        unq = sort(unique(temp_mode))
        num_fail_modes = length(unq)
        sim.num_fail_modes = num_fail_modes-1
        if 1 == num_fail_modes
            sim_log(sim.config.quiet_init, string("- No faults present."))
            
        else
            for i in 1:num_fail_modes
                idx = findall(x -> x == unq[i], temp_mode)
                for j in idx
                    sim.faults[j] = SimFault(unq[i], temp_thresh[j])
                end
            end

            for i in 1:num_dimensions
                if sim.faults[i].enabled
                    sim_log(sim.config.quiet_init, string("- Fault ID: ", sim.faults[i].fault_id, " enabled on Dimension: ", i, ", at: ", sim.faults[i].fault_threshold))
                end
            end
        end
    end


    sim_log(sim.config.quiet_init, string("...\nCreating Constraint Pairs"))
    
    if !config.enable_constraints
        sim_log(sim.config.quiet_init, string("- Disabled."))
        
    else
        for i = 1:num_comp_fun
            temp = sortperm(rand(sim.rng, sim.comps[i].num_models))
            if 2 > length(temp)
                sim_log(sim.config.quiet_init, string("- Composition Function: ", i, ", skipping, not enough models."))
                continue
            end
            num_pairs = rand(sim.rng, 1:Int(floor(length(temp)/2)))
            sim_log(sim.config.quiet_init, string("- Composition Function: ", i, ", Num Pairs: ", num_pairs))
            
            if 0 < num_pairs
                for j in 1:num_pairs
                    lhs = sim.comps[i].model_map[temp[j*2-1]]
                    rhs = sim.comps[i].model_map[temp[j*2-0]]
                    inverted = rand(sim.rng) < 0.5
                    spline = SimSpline(sim.config, sim.rng, rand(sim.rng, 10:20))
                    si = SimConstraintRegion(lhs, rhs, sim.config.constraint_margin, inverted, spline)
                    sim_log(sim.config.quiet_init, string("  - New Constraint Pair: ", si.lhs_dimension, ", ", si.rhs_dimension, ", Inverted: ", si.inverted))
                    
                    # find best unconstrained location
                    best_lhs = 0.0
                    best_rhs = 0.0
                    best_lhs_x = -1.0
                    best_rhs_x = -1.0
                    best_zxy = 0.0
                    for y in 0:1/100:1
                        for x in 0:1/100:1
                            zx, ux = model_query(sim.models[lhs], x)
                            zy, uy = model_query(sim.models[rhs], y)
                            c = constraint_eval(si, ux, uy)
                            if !isnan(c)
                                if sim.config.enable_faults && 0 != sim.num_fail_modes
                                    if sim.faults[lhs].enabled && zx < sim.faults[lhs].fault_threshold
                                        zx = 0.0
                                    end
                                    if sim.faults[rhs].enabled && zy < sim.faults[rhs].fault_threshold
                                        zy = 0.0
                                    end
                                end
                                if zx > best_lhs
                                    best_lhs = zx
                                end
                                if zy > best_rhs
                                    best_rhs = zy
                                end
                                if zx+zy > best_zxy
                                    best_zxy = zx+zy
                                    best_lhs_x = x
                                    best_rhs_x = y
                                end
                            end
                        end
                    end

                    sim.models[lhs].max_constrained = best_lhs
                    # println("x[", lhs, "] = ", best_lhs_x)
                    sim.models[rhs].max_constrained = best_rhs
                    # println("x[", rhs, "] = ", best_rhs_x)
                    if 0.001 > best_lhs
                        println("Error, max_constrained test failed for model: ", lhs)
                    end
                    if 0.001 > best_rhs
                        println("Error, max_constrained test failed for model: ", rhs)
                    end

                    push!(sim.comps[i].constraints, si)
                end
            end
        end
    end

    
    sim_log(sim.config.quiet_init, string("...\nSim Initialization Complete"))
    
    return sim
end