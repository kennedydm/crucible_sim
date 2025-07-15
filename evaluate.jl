
# sim_eval: function that returns the simulation response for the given input values x
function sim_eval(sim::SimStruct, x_in::Array{Float64}, path::Array{Int}, fidelity_base::Int)

    sim.num_iterations += 1;
    
    verbose = false
    # verbose = true

    noise_seed :: Int = sim.config.noise_seed + sim.num_iterations
    rng_noise = Xoshiro(noise_seed % 1000000)

    # determine adversarial factor
    sim.runtime_adv_factor = 1.0
    adv_failure_factor = 1.0
    if sim.config.enable_adversarial
        sim.runtime_adv_factor = sim.adversarial_fitness * (1.0 + (spline_eval(sim.adversarial_spline, sim.adversarial_fitness) - 0.5) * 0.5)

        if sim.config.enable_adversarial_failure
            adv_failure_factor = (1 + sim.config.adversarial_failure_factor * sim.runtime_adv_factor)
        end
    end

    
    fidelity = fidelity_base
    if fidelity < 1
        fidelity = 1
    end
    fidelity = Int(round(Float64(fidelity) ^ sim.config.fidelity_power))

    # re-arrange inputs using input mapping
    x = copy(x_in)
    if sim.config.enable_input_map        
        # check for dynamic re-mapping event
        if sim.config.enable_dynamic && sim.config.enable_dynamic_input_map
            sim.next_dyn_input_remap -= 1
            if sim.next_dyn_input_remap <= 0
                # repeatable dynamic mapping seed
                temp_seed = sim.config.structure_seed + sim.num_iterations
                temp_rng = Xoshiro(temp_seed % 1000000)
                # new input mapping
                temp_map = sortperm(rand(temp_rng, sim.num_inputs)) # random permutation
                # swap map values
                # println("Swapping inputs: ", sim.input_map[temp_map[1]], ", ", sim.input_map[temp_map[2]])
                temp = sim.input_map[temp_map[1]]
                sim.input_map[temp_map[1]] = sim.input_map[temp_map[2]]
                sim.input_map[temp_map[2]] = temp
                # determine next event time
                sim.next_dyn_input_remap = rand(temp_rng, sim.config.dyn_input_map_freq_min:sim.config.dyn_input_map_freq_max)
            end
        end

        # re-map inputs
        for i in 1:sim.num_inputs
            x[i] = x_in[sim.input_map[i]]
        end
    end

    # base and adversarial input shifting
    # add base offsets
    if sim.config.enable_input_shift
        # check for dynamic input shifting
        if sim.config.enable_dynamic && sim.config.enable_dynamic_input_shift
            sim.next_dyn_input_shift -= 1
            if sim.next_dyn_input_shift <= 0
                # repeatable dynamic mapping seed
                temp_seed = sim.config.structure_seed + sim.num_iterations
                temp_rng = Xoshiro(temp_seed % 1000000)                
                # create new input offsets
                sim.offset_inputs = sim.offset_inputs .+ ((rand(temp_rng, sim.num_inputs) .- 0.5) .* 2.0) .* sim.config.dyn_input_shift_mag
                # determine next event time
                sim.next_dyn_input_shift = rand(temp_rng, sim.config.dyn_input_shift_freq_min:sim.config.dyn_input_shift_freq_max)
            end
        end

        x = x .+ sim.offset_inputs
        # add adversarial offsets
        if sim.config.enable_adversarial && sim.config.enable_adversarial_offset
            x = x .+ sim.offset_adversarial .* sim.runtime_adv_factor
        end
    end

    # base and adversarial input noise
    input_noise_sigma = sim.config.input_noise_sigma
    if sim.config.enable_adversarial && sim.config.enable_adversarial_noise
        input_noise_sigma *= (1 + sim.config.adversarial_noise_factor * sim.runtime_adv_factor)
    end
    if sim.config.enable_input_noise
        for i in 1:sim.num_inputs
            x[i] = x[i] + sum(randn(rng_noise, fidelity)) * input_noise_sigma / fidelity
        end
    end

    # wrap inputs
    for i in 1:sim.num_inputs
        x[i] = sim_fract(x[i])
    end
    
    tot_scale_x = x[sim.num_inputs]
    
    ret :: Float64 = 0.0
    constraint = 1.0


    #--------------------------------------------------------------------------
    # check for random wrong answer
    if sim.config.enable_random_fitness
        random_fitness_factor = 1.0
        if sim.config.enable_adversarial_incorrect
            random_fitness_factor *= (1 + sim.config.adversarial_incorrect_factor * sim.runtime_adv_factor)
        end
        if rand(rng_noise) < sim.config.random_fitness_rate * random_fitness_factor
            ret = rand(rng_noise)
            update_adversarial_fitness(sim, ret)
            return ret
        end
    end

    # check for random infeasibility
    if sim.config.enable_faults
        if rand(rng_noise) < sim.config.random_infeasible_rate * adv_failure_factor
            update_adversarial_fitness(sim, 0.0)
            return NaN
        end
    end

    # check for random fault
    if sim.config.enable_faults
        if rand(rng_noise) < sim.config.random_fault_rate * adv_failure_factor
            update_adversarial_fitness(sim, 0.0)
            return 0.0
        end
    end
    #--------------------------------------------------------------------------

    
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
                update_adversarial_fitness(sim, 0.0)
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
                update_adversarial_fitness(sim, 0.0)
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
            update_adversarial_fitness(sim, 0.0)
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

    
    # nan check
    if isnan(ret)
        update_adversarial_fitness(sim, 0.0)
        return NaN
    end
    
    # clamp response before returning
    ret = clamp(ret, 0, 1)

    update_adversarial_fitness(sim, ret)
    return ret
end


function update_adversarial_fitness(sim::SimStruct, fitness::Float64)
    sim.adversarial_fitness = sim.adversarial_fitness * sim.config.adversarial_feedback + fitness * (1 - sim.config.adversarial_feedback)
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
        model_noise_sigma = sim.config.model_noise_sigma
        if sim.config.enable_adversarial && sim.config.enable_adversarial_noise
            model_noise_sigma *= (1 + sim.config.adversarial_noise_factor * sim.runtime_adv_factor)
        end
        z = abs(z + sum(randn(rng_noise, fidelity)) * model_noise_sigma / fidelity)
    end

    return z, u, false

end