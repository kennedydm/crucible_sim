using Plots, Random, Interpolations
#import Base.Threads.@spawn


# SimSpline: Generic spline that maps an input value to an output value
mutable struct SimSpline
    interp
    #
    function SimSpline(rng::Xoshiro, N::Int)
        y = fill(0.0, N)
        y[1] = rand(rng) - rand(rng)
        for i in 2:N
            y[i] = y[i-1] * 0.5 + rand(rng) - rand(rng)
        end
        y = y .- minimum(y) # shift to positive
        y = y ./ maximum(y) # normalize
        x = 0:1/(N-1):1
        itp = cubic_spline_interpolation(x, y)
        ret = new()
        ret.interp = itp
        return ret
    end
end

function spline_eval(s::SimSpline, x::Float64)
    return Float64(clamp(s.interp(clamp(x, 0, 1)), 0, 1))
end


# SimModel: Holds the model implementation
mutable struct SimModel
    gen_spline :: SimSpline       # function that converts input x to output u.
    mdl_spline :: SimSpline       # function that converts input u to output value m(u).
    max_constrained :: Float64
    #
    function SimModel(rng::Xoshiro)
        ret = new()
        gen_knots = rand(rng, 10:20)
        mdl_knots = rand(rng, 10:20)
        ret.gen_spline = SimSpline(rng, gen_knots)
        ret.mdl_spline = SimSpline(rng, mdl_knots)
        ret.max_constrained = 1.0
        return ret
    end
end

function model_query(mdl::SimModel, x::Float64)
    u = spline_eval(mdl.gen_spline, x)
    return spline_eval(mdl.mdl_spline, u), u
end


# SimConstraintRegion: Defines a nonconvex constraint region between two dimensions
mutable struct SimConstraintRegion
    lhs_dimension       :: Int
    rhs_dimension       :: Int
    constraint_margin   :: Float64
    inverted            :: Bool
    spline              :: SimSpline
    #
    function SimConstraintRegion(lhs::Int, rhs::Int, margin::Float64, inverted::Bool, spline::SimSpline)
        ret = new()
        ret.lhs_dimension = lhs
        ret.rhs_dimension = rhs
        ret.constraint_margin = margin
        ret.inverted = inverted
        ret.spline = spline
        return ret
    end
end

function constraint_eval(cr::SimConstraintRegion, u0::Float64, u1::Float64)
    y = spline_eval(cr.spline, u0)
    margin = cr.constraint_margin
    if (!cr.inverted && u1 > y + margin) || (cr.inverted && u1 < y - margin)
        return NaN
    end
    return 1.0
end


# SimObjectiveFunction: Defines an objective function, mapping simulation inputs to response splines and scale factors
mutable struct SimObjectiveFunction
    num_models              :: Int
    model_map               :: Array{Int}
    scale_factors           :: Array{Float64}
    sum_scale_factors       :: Float64
    pareto_limit            :: Float64
    scale_spline            :: SimSpline
    #
    # num_constraint_pairs    :: Int
    constraints             :: Array{Any}
    #
    function SimObjectiveFunction(rng::Xoshiro, map_in::Array{Int})
        ret = new()
        ret.num_models = length(map_in)
        ret.model_map = map_in
        ret.scale_factors = rand(rng, ret.num_models)
        ret.sum_scale_factors = sum(ret.scale_factors)
        ret.pareto_limit = (0.8 + 0.2 * rand(rng)) * ret.sum_scale_factors
        ret.scale_spline = SimSpline(rng, rand(rng, 5:10))
        #
        ret.constraints = []
        #
        return ret
    end
end


# SimFault: Defines the location and enumeration of a failure mode
mutable struct SimFault
    enabled         :: Bool
    fault_id        :: Int
    fault_threshold :: Float64
    #
    function SimFault(id::Int, thresh::Float64)
        ret = new()
        ret.fault_id = id
        ret.enabled = 0 != id
        ret.fault_threshold = thresh
        return ret
    end
end



# SimConfig: Input structure defining the simulation configuration with defaults
mutable struct SimConfig
    structure_seed              :: Int
    num_dimensions              :: Int
    num_nodes                   :: Int
    #
    input_noise_sigma           :: Float64
    model_noise_sigma           :: Float64
    random_fault_freq           :: Float64
    constraint_margin           :: Float64
    #
    enable_input_noise          :: Bool
    enable_model_noise          :: Bool
    enable_constraints          :: Bool
    enable_faults               :: Bool
    enable_pareto               :: Bool
    enable_obj_scale_inputs     :: Bool
    enable_total_scale_input    :: Bool
    #
    quiet_init                  :: Bool
    #
    function SimConfig()
        ret = new()
        
        # defaults
        ret.structure_seed = 0
        ret.num_dimensions = 1
        ret.num_nodes = 1
        #
        ret.input_noise_sigma = 0.003
        ret.model_noise_sigma = 0.03
        ret.random_fault_freq = 0.05
        ret.constraint_margin = 0.05
        #
        ret.enable_input_noise = true
        ret.enable_model_noise = true
        ret.enable_constraints = true
        ret.enable_faults = true
        ret.enable_pareto = true
        ret.enable_obj_scale_inputs = true
        ret.enable_total_scale_input = true
        #
        ret.quiet_init = false
        
        return ret
    end
end


# SimStruct: Holds the all simulation structural information for execution.
mutable struct SimStruct
    rng         :: Xoshiro
    config      :: SimConfig
    
    # data
    models          :: Array{Any}
    objs            :: Array{Any}
    faults          :: Array{Any}
    scale_spline    :: SimSpline

    #
    num_fail_modes          :: Int
    num_inputs              :: Int
    num_obj_fun             :: Int
    
    #
    function SimStruct(config::SimConfig)
        ret = new()
        ret.models = []
        ret.objs = []
        ret.faults = []
        ret.config = config
        ret.num_fail_modes = 0
        ret.num_inputs = 0
        ret.num_obj_fun = 0
        ret.rng = Xoshiro(config.structure_seed)
        return ret
    end
end


# sim_log: Utility function for printing status messages
function sim_log(quiet::Bool, text::String)
    if !quiet
        println(text)
    end
end


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
        push!(sim.models, SimModel(sim.rng))
    end
    sim.num_inputs += num_dimensions
    
    
    sim_log(sim.config.quiet_init, string("...\nCreating Objective Functions"))
    
    # create objective functions
    max_obj_fun = floor(Int, sqrt(num_dimensions))

    # mapping of dimensions to objective functions
    temp = zeros(Int, num_dimensions)
    for i in 1:num_dimensions
        temp[i] = rand(sim.rng, 1:max_obj_fun)
    end

    unq = sort(unique(temp))
    num_obj_fun = length(unq)

    sim.objs = Array{Any}(undef, num_obj_fun)
    for i in 1:length(unq)
        idx = findall(x -> x == unq[i], temp)
        so = SimObjectiveFunction(sim.rng, idx)
        sim_log(sim.config.quiet_init, string("- New Obj Function: "))
        sim_log(sim.config.quiet_init, string("  - Num Models   : ", so.num_models))
        sim_log(sim.config.quiet_init, string("  - Model Mapping: ", so.model_map))
        sim_log(sim.config.quiet_init, string("  - Scale Factors: ", so.scale_factors))
        sim_log(sim.config.quiet_init, string("  - Sum Scale Factors: ", so.sum_scale_factors))
        sim_log(sim.config.quiet_init, string("  - Pareto Limit : ", so.pareto_limit))
        #
        sim.objs[i] = so
    end

    sim_log(sim.config.quiet_init, string("- Total number of Objective Functions: ", num_obj_fun))
    
    sim.num_obj_fun = num_obj_fun
    sim.num_inputs += num_obj_fun   # objective function scale factors


    sim_log(sim.config.quiet_init, string("...\nCreating Output Scale Factor"))
    sim.scale_spline = SimSpline(sim.rng, rand(sim.rng, 5:10))
    sim.num_inputs += 1

    if config.enable_faults
        sim_log(sim.config.quiet_init, string("...\nCreating Failure Modes"))
        
        sim.faults = Array{Any}(undef, num_dimensions)
        
        # mapping of dimensions to objective functions
        temp_mode = zeros(Int, num_dimensions)
        temp_thresh = zeros(Float64, num_dimensions)
        for i in 1:num_dimensions
            temp_mode[i] = floor(rand(sim.rng) * rand(sim.rng) * max_obj_fun)
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
        for i = 1:num_obj_fun
            temp = sortperm(rand(sim.rng, sim.objs[i].num_models))
            if 2 > length(temp)
                sim_log(sim.config.quiet_init, string("- Objective Function: ", i, ", skipping, not enough models."))
                continue
            end
            num_pairs = rand(sim.rng, 1:Int(floor(length(temp)/2)))
            sim_log(sim.config.quiet_init, string("- Objective Function: ", i, ", Num Pairs: ", num_pairs))
            
            if 0 < num_pairs
                for j in 1:num_pairs
                    lhs = sim.objs[i].model_map[temp[j*2-1]]
                    rhs = sim.objs[i].model_map[temp[j*2-0]]
                    inverted = rand(sim.rng) < 0.5
                    spline = SimSpline(sim.rng, rand(sim.rng, 10:20))
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

                    push!(sim.objs[i].constraints, si)
                end
            end
        end
    end

    
    sim_log(sim.config.quiet_init, string("...\nSim Initialization Complete"))
    
    return sim
end


# sim_eval: function that returns the simulation response for the given input values x and noise_seed
function sim_eval(sim::SimStruct, noise_seed::Int, x_in)

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

    for k in 1:length(sim.objs)
        obj = sim.objs[k]
        obj_scale_x = x[sim.num_inputs - k]
        
        y::Float64 = 0.0

        for i in 1:obj.num_models

            mdl = obj.model_map[i]
            z, u[mdl] = model_query(models[mdl], x[mdl])

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

            y = y + z * obj.scale_factors[i]
            if isnan(y)
                println("Error, NaN calculating obj: ", k, ", model: ", mdl, ", z: ", z, ", sf: ", obj.scale_factors[i])
                return NaN
            end

        end

        if sim.config.enable_obj_scale_inputs
            y *= spline_eval(obj.scale_spline, obj_scale_x)
        end

        if sim.config.enable_pareto
            if y > obj.pareto_limit
                y = 2 * obj.pareto_limit - y
            end
            mx += obj.pareto_limit
        else
            mx += obj.sum_scale_factors
        end

        # check constraints
        constraint = 1.0
        if sim.config.enable_constraints
            for i in 1:length(obj.constraints)
                lhs = obj.constraints[i].lhs_dimension
                rhs = obj.constraints[i].rhs_dimension
                constraint *= constraint_eval(obj.constraints[i], u[lhs], u[rhs])
                if isnan(constraint)
                    # sim_log(sim.config.quiet_init, string("obj: ", k, " failed constraint: ", i, ", lhs: ", lhs, ", rhs: ", rhs, ", x[",lhs,"]: ", x[lhs], ", x[",rhs,"]: ", x[rhs], ", u[",lhs,"]: ", u[lhs], ", u[",rhs,"]: ", u[rhs])
                    # sim_log(sim.config.quiet_init, string("obj model map: ", obj.model_map)
                    break
                end
            end
        end
        
        ret += y * constraint

    end

    if sim.config.enable_total_scale_input
        ret *= spline_eval(sim.scale_spline, tot_scale_x)
    end
    ret = ret / mx

    if !isnan(ret)
        if sim.config.enable_faults && rand(rng_noise) < sim.config.random_fault_freq
            return ret *= 0.0
        end
    end

    return ret
end


# main: entry point for the test set, creates simulation object and performs random search optimization.
function main()

    config = SimConfig()
    config.structure_seed = 0
    config.num_dimensions = 15
    config.num_nodes = 1

    # config.enable_constraints = false
    # config.enable_input_noise = false
    # config.enable_model_noise = false
    # config.enable_pareto = false
    # config.enable_faults = false
    # config.enable_obj_scale_inputs = false
    # config.enable_total_scale_input = false
    # config.quiet_init = true
    
    sim = sim_init(config)
    
    
    println("...\nExecuting...")

    best = 0.0
    bestx = zeros(sim.num_inputs)
    best_seed = 0
    results = [0.0]
    seed = 0

    rng = Xoshiro(0)
    time0 = time()

    # data structures for adaptive sampling based on failure regions
    attempts = zeros(Int, sim.num_inputs * 50)
    failures = zeros(Int, sim.num_inputs * 50)

    max_steps = 10
    for k in 1:max_steps
        for i in 1:100000
            # random search inputs
            x = rand(rng, sim.num_inputs)
            
            # update random search using adaptive sampling based on failure regions
            if 1 < k
                for j in 1:sim.num_inputs
                    for p in 1:20
                        xi = trunc(Int, x[j] * 50.0 + 1)
                        xj = (j - 1) * 50 + xi 
                        att = attempts[xj]
                        fai = failures[xj]
                        if att > 4000 && fai/att > 0.99
                            x[j] = rand(rng) # reroll
                            if rand(rng) < 0.9
                                continue
                            end
                        end
                        break
                    end
                end
            end

            # evaluate performance
            y = sim_eval(sim, seed, x)
            seed += 1

            # if result is feasible, update best known solution and regions explored
            if !isnan(y) 
                if best < 1e-15
                    best = y
                    bestx = x
                    best_seed = seed
                end
                if y > best + (1 - best) * 0.01
                    # confirm using Monte Carlo replicates before accepting this as the new best solution
                    s = 0.0
                    N = min(200, 30 + 5 * length(results))
                    for j in 1:N
                        yy = sim_eval(sim, seed, x)
                        seed += 1
                        if !isnan(yy)
                            s = s + yy
                        end
                    end
                    s = s / N
                    if s > best
                        push!(results, s)
                        best = s
                        bestx = x
                        best_seed = seed
                    end
                end
                #
                failed = y < 1e-15
                for j in 1:sim.num_inputs
                    xi = trunc(Int, x[j] * 50.0 + 1)
                    xj = (j - 1) * 50 + xi
                    attempts[xj] += 1
                    if failed
                        failures[xj] += 1
                    end
                end
            end
            #
            # if best > 0.0001
                # neighborhood search around best solution, cooling down over time
                x = bestx + randn(rng, sim.num_inputs) .* (0.2/k)
                y = 0.0
                for j in 1:5
                    y += sim_eval(sim, seed, x)
                    seed += 1
                end
                y /= 5
                if !isnan(y) 
                    if y > best + (1 - best) * 0.01
                        # confirm using Monte Carlo replicates before accepting this as the new best solution
                        s = 0.0
                        N = min(200, 30 + 5 * length(results))
                        for j in 1:N
                            yy = sim_eval(sim, seed, x)
                            seed += 1
                            if !isnan(yy)
                                s = s + yy
                            end
                        end
                        s = s / N
                        if s > best
                            push!(results, s)
                            best = s
                            bestx = x
                            best_seed = seed
                        end
                    end
                end
            # end
        end
        if best > (1 - sim.config.random_fault_freq)
            println("stopped at k=", k)
            break
        end
        # println(30 + 5 * length(results))
        time1 = time()
        dtime = time1 - time0
        time0 = time1
        remaining = (max_steps - k) * dtime
        println("step: ", k, "/", max_steps, ", best: ", best, ",  sec remaining: ", round(remaining), ", min: ", round(remaining * 10 / 60)/10)
    end

    h = scatter(results)
    savefig(h, "test_results.png")

    println(best)
    println(bestx)
    println("best_seed: ", best_seed)

    yfinal = 0.0
    ifinal = 0
    ffinal = 0

    for i in 1:10000
        y = sim_eval(sim, seed, bestx)
        seed += 1
        if isnan(y)
            ifinal += 1
        else
            if y < 0.01
                ffinal += 1
            end
            yfinal += y
        end
    end

    println("yfinal: ", yfinal / (1000 - ffinal))
    println("ifinal: ", ifinal, ", ", ifinal / 1000)
    println("ffinal: ", ffinal, ", ", ffinal / 1000)

    println("total steps: ", seed)

    println("Saving success region images (", sim.num_inputs, ")...")

    # println(attempts)
    # println(failures)

    # illustrate failure modes by plotting the success ratios in bins
    for i in 1:sim.num_inputs
        z = zeros(50)
        for j in 1:50
            xj = (i - 1) * 50 + j
            z[j] = 1 - failures[xj]/attempts[xj]
        end
        h = scatter(z)
        savefig(h, string("test_success_regions", i, ".png"))
    end
end



main()
println("Done.")