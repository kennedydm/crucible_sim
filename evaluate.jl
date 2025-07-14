
# sim_eval: function that returns the simulation response for the given input values x
function sim_eval(sim::SimStruct, x_in::Array{Float64}, path::Array{Int}, fidelity_base::Int)

    sim.num_iterations += 1;
    
    verbose = false
    # verbose = true

    noise_seed :: Int = sim.config.noise_seed + sim.num_iterations
    rng_noise = Xoshiro(noise_seed % 1000000)


    #--------------------------------------------------------------------------
    # check for random infeasibility
    if sim.config.enable_faults
        if rand(rng_noise) < sim.config.random_infeasible_rate
            return NaN
        end
    end

    # check for random fault
    if sim.config.enable_faults
        if rand(rng_noise) < sim.config.random_fault_rate
            return 0.0
        end
    end
    #--------------------------------------------------------------------------


    fidelity = fidelity_base
    if fidelity < 1
        fidelity = 1
    end
    fidelity = Int(round(Float64(fidelity) ^ sim.config.fidelity_power))

    x = copy(x_in)
    input_noise_sigma = sim.config.input_noise_sigma
    if sim.config.enable_input_noise
        for i in 1:sim.num_inputs
            x[i] = clamp(x[i] + sum(randn(rng_noise, fidelity)) * input_noise_sigma / fidelity, 0, 1)
        end
    end
    
    tot_scale_x = x[sim.num_inputs]
    
    ret :: Float64 = 0.0
    constraint = 1.0

    
    # for each composition function
    #--------------------------------------------------------------------------
    for k in 1:length(sim.comps)
        comp = sim.comps[k]
        comp_scale_x = x[sim.num_inputs - k]
        
        # composition function aggregate fitness
        y = 0.0
        sum_scale_factors = 0.0

        visited = fill(false, length(sim.models))

        for pair in 1:length(comp.coupling)
            lhs = comp.coupling[pair].lhs
            rhs = comp.coupling[pair].rhs
            visited[lhs] = true
            visited[rhs] = true
            if verbose
                println("visited: ", lhs)
                println("visited: ", rhs)
            end

            design_x = x[lhs]
            design_y = x[rhs]

            # determine input skew
            #------------------------------------------------------------------
            if sim.config.enable_skewing
                # apply input skewing with wrapping
                temp_x = design_x + (design_y - 0.5) * comp.coupling[pair].xskew
                if temp_x < 0
                    temp_x += 1
                end
                if temp_x > 1
                    temp_x -= 1
                end
                
                temp_y = design_y + (temp_x - 0.5) * comp.coupling[pair].yskew
                if temp_y < 0
                    temp_y += 1
                end
                if temp_y > 1
                    temp_y -= 1
                end
                
                design_x = temp_x
                design_y = temp_y
            end


            # evaluate lhs
            z0, u0, failed0 = model_eval(sim, lhs, design_x, rng_noise, fidelity)
            
            # evaluate rhs
            z1, u1, failed1 = model_eval(sim, rhs, design_y, rng_noise, fidelity)
            
            # check for executive failure
            if failed0 || failed1
                if verbose
                    println("Executive Failure")
                end
                return 0.0
            end

            # add to response
            y += z0 + z1
            
            # check for feasibility
            if sim.config.enable_constraints
                constraint *= constraint_eval(comp.coupling[pair], u0, u1)
                sim.num_function_evals += 1
            end
        end


        # repeat for non-visited models
        #--------------------------------------------------------------------------
        for i in 1:comp.num_models
            mdl = comp.model_map[i]
            sum_scale_factors += sim.models[mdl].scale_factor
    
            if visited[mdl]
                continue
            end
            visited[mdl] = true
            
            if verbose
                println("visited: ", mdl)
            end

            # evaluate model
            z, u, failed = model_eval(sim, mdl, x[mdl], rng_noise, fidelity)

            # check for executive failure
            if failed
                if verbose
                    println("Executive Failure")
                end
                return 0.0
            end

            # add to response
            y += z
            
        end

        # normalize y to sum of scale factors
        y /= sum_scale_factors


        # apply comp scale factor
        if sim.config.enable_comp_scale_inputs
            y *= spline_eval(comp.scale_spline, comp_scale_x)
            sim.num_function_evals += 1
        end


        # apply comp iso-optimal inversion
        if sim.config.enable_iso_optimal
            y /= comp.iso_optimal_limit
            if y > 1.0
                y = 2.0 - y
            end
        end


        # return NaN if infeasible
        if sim.config.enable_constraints && y < 1 - sim.config.constraint_optimal_margin && isnan(constraint)
            return NaN
        end
        

        # add to fitness response
        ret += y

    end

    
    # scale total output
    if sim.config.enable_total_scale_input
        ret *= spline_eval(sim.scale_spline, tot_scale_x)
        sim.num_function_evals += 1
    end
    
    
    
    # apply global iso-optimal

    
    # clamp response before returning
    ret = clamp(ret, 0, 1)

    return ret
end


function model_eval(sim::SimStruct, mdl::Int, design_x::Float64, rng_noise::Xoshiro, fidelity::Int)

    dyn_iter = 0
    if sim.config.enable_dynamic && sim.config.enable_dynamic_spline
        dyn_iter = sim.num_iterations
    end

    # model response
    z, u = model_query(sim.models[mdl], design_x, dyn_iter)
    sim.num_function_evals += 2

    # apply faults
    if sim.config.enable_faults && 0 != sim.num_fail_modes && sim.faults[mdl].enabled && z < sim.faults[mdl].threshold
        factor = sim.faults[mdl].factor
        if factor < 0.01
            return 0.0, 0.0, true
        else
            z *= factor
        end
    end

    # model level scaling
    z *= sim.models[mdl].scale_factor

    # - model output noise
    if sim.config.enable_model_noise
        z = abs(z + sum(randn(rng_noise, fidelity)) * sim.config.model_noise_sigma / fidelity)
    end

    return z, u, false

end