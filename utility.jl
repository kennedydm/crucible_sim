
# sim_log: Utility function for printing status messages
function sim_log(io::IOStream, quiet::Bool, text::String)
    write(io, text, '\n')
    if !quiet
        println(text)
    end
end


function sim_log_fence(io::IOStream, quiet::Bool)
    fence = "==============================================================================="
    sim_log(io, quiet, fence)
end


function sim_plot_spline(spline::SimSpline, xlbl::String, ylbl::String, ttle::String, folder::String, filename::String)
    # return
    inp = []
    resp = []    
    for i in 0:1000
        x = i/1000
        y = spline_eval(spline, x)
        push!(resp, y)
        push!(inp, x)
    end

    mkpath(folder)

    h = plot(inp, resp, label = "")
    xlabel!(xlbl)
    ylabel!(ylbl)
    title!(ttle)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end


function sim_plot_model(mdl::SimModel, ttle::String, folder::String, filename::String)
    # return
    inp = []
    resp = []    
    for i in 0:1000
        x = i/1000
        y, u = model_query(mdl, x)
        push!(resp, y)
        push!(inp, x)
    end

    mkpath(folder)

    h = plot(inp, resp, label = "")
    xlabel!("x")
    ylabel!("f(g(x))")
    title!(ttle)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end


function sim_plot_model_flat(mdl::SimModel, flat::SimFlatten, ttle::String, folder::String, filename::String)
    # return
    inp = []
    resp = []    
    resp_flat = []
    for i in 0:1000
        x = i/1000
        y, u = model_query(mdl, x)
        push!(resp, y)
        if x > flat.x0 && x < flat.x1 && y > flat.y0 && y < flat.y1
            y = flat.override
        end
        push!(resp_flat, y)
        push!(inp, x)
    end

    mkpath(folder)

    h = plot(inp, resp, label = "Baseline", line = :dot)
    plot!(inp, resp_flat, label = "With Flattening")
    xlabel!("x")
    ylabel!("f(g(x))")
    title!(ttle)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end



function sim_plot_model_invert(mdl::SimModel, invert::SimInvert, ttle::String, folder::String, filename::String)
    # return
    inp = []
    resp = []    
    resp_invert = []
    for i in 0:1000
        x = i/1000
        y, u = model_query(mdl, x)
        push!(resp, y)
        if x > invert.x0 && x < invert.x1 && y > invert.y0 && y < invert.y1
            y = invert.y0 + invert.y1 - y
        end
        push!(resp_invert, y)
        push!(inp, x)
    end

    mkpath(folder)

    h = plot(inp, resp, label = "Baseline", line = :dot)
    plot!(inp, resp_invert, label = "With Inversion")
    xlabel!("x")
    ylabel!("f(g(x))")
    title!(ttle)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end



function sim_plot_model_fault(mdl::SimModel, fault::SimFault, ttle::String, folder::String, filename::String)
    # return
    inp = []
    resp = []    
    resp_invert = []
    for i in 0:1000
        x = i/1000
        y, u = model_query(mdl, x)
        push!(resp, y)
        if y < fault.threshold
            y = y * fault.factor
        end
        push!(resp_invert, y)
        push!(inp, x)
    end

    mkpath(folder)

    h = plot(inp, resp, label = "Baseline", line = :dot)
    plot!(inp, resp_invert, label = "With Fault")
    xlabel!("x")
    ylabel!("f(g(x))")
    title!(ttle)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end



function sim_plot_heatmap(x, y, z, xlbl::String, ylbl::String, ttle::String, folder::String, filename::String)
    mkpath(folder)
    h = heatmap(x, y, z)
    xlabel!(xlbl)
    ylabel!(ylbl)
    title!(ttle)
    zlims!(0.0, 1.0)
    println("Saving Plot: ", filename)
    savefig(h, string(folder, "/", filename))
end