# sim_init: Builds the simulation structure for later querying by an optimizer
function sim_init(config::SimConfig)

    sim = SimStruct(config)
    num_dimensions = sim.config.num_dimensions
    num_nodes = sim.config.num_nodes

    debug_folder = string("./debug/", sim.config.debug_folder)
    if ispath(debug_folder)
        rm(debug_folder, recursive=true)
    end

    sim.io = open(config.logfile, "w")
    
    sim_log(sim.io, sim.config.quiet_init, string("Initializing Crucible Simulation"))
    
    config_log_inputs(sim.io, sim.config)

    if 1 > num_dimensions
        sim_log(sim.io, sim.config.quiet_init, string("Error, not enough dimensions."))
        return
    end
    if 1 > num_nodes
        sim_log(sim.io, sim.config.quiet_init, string("Error, not enough nodes."))
        return
    end
    
    sim_log(sim.io, sim.config.quiet_init, string("...\nConstructing Node 1"))
    
    
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
        sim_log(sim.io, sim.config.quiet_init, string("  - Scale Factors: ", so.scale_factors))
        sim_log(sim.io, sim.config.quiet_init, string("  - Sum Scale Factors: ", so.sum_scale_factors))
        sim_log(sim.io, sim.config.quiet_init, string("  - Iso-Optimal Limit : ", so.iso_optimal_limit))
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

    if config.enable_flattening
        sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Flattening"))        
        sim.flats = Array{Any}(undef, num_dimensions)
        for i in 1:num_dimensions
            flat = SimFlatten(rand(sim.rng) < sim.config.flattening_rate, sim.rng)
            sim.flats[i] = flat
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
        sim.inverts = Array{Any}(undef, num_dimensions)
        for i in 1:num_dimensions
            invert = SimInvert(rand(sim.rng) < sim.config.inversion_rate, sim.rng)
            sim.inverts[i] = invert
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
        for i in 1:num_dimensions
            temp_mode[i] = floor(rand(sim.rng) * rand(sim.rng) * max_comp_fun)
            temp_thresh[i] = rand(sim.rng) * 0.25 + 0.05
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
                    sim.faults[j] = SimFault(unq[i], temp_thresh[j])
                end
            end

            for i in 1:num_dimensions
                if sim.faults[i].enabled
                    sim_log(sim.io, sim.config.quiet_init, string("- Fault ID: ", sim.faults[i].id, " enabled on Dimension: ", i, ", at: ", sim.faults[i].threshold))
                    if config.save_debug_figs
                        sim_plot_model_fault(sim.models[i], sim.faults[i], string("Model: ", i, " Response with Fault"), debug_folder, string("mdl_", i, "_mdl_resp_fault.png"))
                    end
                end
            end
        end
    end


    sim_log(sim.io, sim.config.quiet_init, string("...\nCreating Coupling Pairs"))
    
    for i = 1:num_comp_fun
        temp = sortperm(rand(sim.rng, sim.comps[i].num_models))
        if 2 > length(temp)
            sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", skipping, not enough models."))
            continue
        end
        num_pairs = rand(sim.rng, 1:Int(floor(length(temp)/2)))
        sim_log(sim.io, sim.config.quiet_init, string("- Composition Function: ", i, ", Num Pairs: ", num_pairs))
        
        if 0 < num_pairs
            for j in 1:num_pairs
                lhs = sim.comps[i].model_map[temp[j*2-1]]
                rhs = sim.comps[i].model_map[temp[j*2-0]]
                xskew = (rand(sim.rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                yskew = (rand(sim.rng) - 0.5) * sim.config.max_skew_magnitude * 2.0
                inverted = rand(sim.rng) < 0.5
                spline = SimSpline(sim.config, sim.rng, rand(sim.rng, config.min_constraint_knots:config.max_constraint_knots))
                si = SimCouplingRegion(lhs, rhs, sim.config.constraint_margin, inverted, spline, xskew, yskew)
                sim_log(sim.io, sim.config.quiet_init, string("  - New Constraint Pair: ", si.lhs_dimension, ", ", si.rhs_dimension, ", Inverted: ", si.inverted))
                
                # find best unconstrained location
                best_lhs = 0.0
                best_rhs = 0.0
                best_lhs_x = -1.0
                best_rhs_x = -1.0
                best_zxy = 0.0
                debug_plot_x = []
                debug_plot_y = []
                debug_plot_z = fill(0.0, 1001, 1001)
                debug_plot_c = fill(0.0, 1001, 1001)
                for yy in 0:1/1000:1
                    for xx in 0:1/1000:1
                        # apply input skewing with wrapping
                        x = xx + (yy - 0.5) * xskew
                        if x < 0
                            x = x + 1
                        end
                        if x > 1
                            x = x - 1
                        end
                        y = yy + (x - 0.5) * yskew
                        if y < 0
                            y = y + 1
                        end
                        if y > 1
                            y = y - 1
                        end
                        # evaluate models at skewed location
                        zx, ux = model_query(sim.models[lhs], x)
                        zy, uy = model_query(sim.models[rhs], y)
                        zxzy = (zx + zy) / 2
                        # zxzy = zxzy / 0.7
                        # if zxzy > 1
                        #     zxzy = 2.0 - zxzy
                        # end

                        c = constraint_eval(si, ux, uy)
                        if !isnan(c)
                            if sim.config.enable_faults && 0 != sim.num_fail_modes
                                if sim.faults[lhs].enabled && zx < sim.faults[lhs].threshold
                                    zx = 0.0
                                end
                                if sim.faults[rhs].enabled && zy < sim.faults[rhs].threshold
                                    zy = 0.0
                                end
                            end
                            if zx > best_lhs
                                best_lhs = zx
                            end
                            if zy > best_rhs
                                best_rhs = zy
                            end
                            if zxzy > best_zxy
                                best_zxy = zxzy
                                best_lhs_x = x
                                best_rhs_x = y
                            end
                        end

                        debug_plot_z[Int(ceil(yy * 1000) + 1), Int(ceil(xx * 1000) + 1)] = zxzy
                        if !isnan(c)
                            debug_plot_c[Int(ceil(yy * 1000) + 1), Int(ceil(xx * 1000) + 1)] = zxzy
                        else
                            debug_plot_c[Int(ceil(yy * 1000) + 1), Int(ceil(xx * 1000) + 1)] = c
                        end
                    end
                    push!(debug_plot_x, yy)
                    push!(debug_plot_y, yy)
                end

                if config.save_debug_figs
                    sim_plot_heatmap(debug_plot_x, debug_plot_y, debug_plot_z,
                        string("Model ",lhs," Input"), string("Model ",rhs," Input"),
                        string("Composition of Model ",lhs," + Model ",rhs, " + Iso + Skew"),
                        debug_folder, string("2d_const_", i, "_", j, "_before.png"))

                    sim_plot_heatmap(debug_plot_x, debug_plot_y, debug_plot_c ./ best_zxy,
                        string("Model ",lhs," Input"), string("Model ",rhs," Input"),
                        string("Composition of Model ",lhs," + Model ",rhs," + Iso + Skew + Const"),
                        debug_folder, string("2d_const_", i, "_", j, "_constrained.png"))
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

                push!(sim.comps[i].coupling, si)
            end
        end
    end

    
    sim_log(sim.io, sim.config.quiet_init, string("...\nSim Initialization Complete"))

    close(sim.io)
    
    return sim
end