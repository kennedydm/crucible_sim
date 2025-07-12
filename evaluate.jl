
# sim_eval: function that returns the simulation response for the given input values x
function sim_eval(sim::SimStruct, x_in)

    sim.num_iterations += 1;

    noise_seed :: Int = sim.config.noise_seed + sim.num_iterations
    rng_noise = Xoshiro(noise_seed % 1000000)

    x = copy(x_in)
    input_noise_sigma = sim.config.input_noise_sigma
    if sim.config.enable_input_noise
        for i in 1:sim.num_inputs
            x[i] = clamp(x[i] + randn(rng_noise) * input_noise_sigma, 0, 1)
        end
    end

    
    tot_scale_x = x[sim.num_inputs]
    
    ret :: Float64 = 0.0

    models = sim.models
    if sim.config.enable_faults
        faults = sim.faults
    end

    u = zeros(length(models))
    mx = 0.0

    for k in 1:length(sim.comps)
        comp = sim.comps[k]
        comp_scale_x = x[sim.num_inputs - k]
        
        y::Float64 = 0.0

        for i in 1:comp.num_models

            mdl = comp.model_map[i]
            z, u[mdl] = model_query(models[mdl], x[mdl])
            sim.num_function_evals += 2

            if sim.config.enable_constraints
                z /= models[mdl].max_constrained
            end

            if sim.config.enable_model_noise
                z = abs(z + randn(rng_noise) * sim.config.model_noise_sigma)
            end

            if sim.config.enable_faults && 0 != sim.num_fail_modes && faults[mdl].enabled && z < faults[mdl].fault_threshold
                return 0.0
                # faulted = true
                # break
            end

            y = y + z * comp.scale_factors[i]
            if isnan(y)
                println("Error, NaN calculating comp: ", k, ", model: ", mdl, ", z: ", z, ", sf: ", comp.scale_factors[i])
                return NaN
            end

        end

        if sim.config.enable_comp_scale_inputs
            y *= spline_eval(comp.scale_spline, comp_scale_x)
            sim.num_function_evals += 1
        end

        if sim.config.enable_iso_optimal
            if y > comp.iso_optimal_limit
                y = 2 * comp.iso_optimal_limit - y
            end
            mx += comp.iso_optimal_limit
        else
            mx += comp.sum_scale_factors
        end

        # check constraints
        constraint = 1.0
        if sim.config.enable_constraints
            for i in 1:length(comp.constraints)
                lhs = comp.constraints[i].lhs_dimension
                rhs = comp.constraints[i].rhs_dimension
                constraint *= constraint_eval(comp.constraints[i], u[lhs], u[rhs])
                sim.num_function_evals += 1
                if isnan(constraint)
                    # sim_log(sim.config.quiet_init, string("comp: ", k, " failed constraint: ", i, ", lhs: ", lhs, ", rhs: ", rhs, ", x[",lhs,"]: ", x[lhs], ", x[",rhs,"]: ", x[rhs], ", u[",lhs,"]: ", u[lhs], ", u[",rhs,"]: ", u[rhs])
                    # sim_log(sim.config.quiet_init, string("comp model map: ", comp.model_map)
                    break
                end
            end
        end
        
        ret += y * constraint

    end

    if sim.config.enable_total_scale_input
        ret *= spline_eval(sim.scale_spline, tot_scale_x)
        sim.num_function_evals += 1
    end
    ret = ret / mx

    if !isnan(ret)
        if sim.config.enable_faults && rand(rng_noise) < sim.config.random_fault_freq
            return ret *= 0.0
        end
    end

    return ret
end
