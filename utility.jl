
# sim_log: Utility function for printing status messages
function sim_log(io::IOStream, quiet::Bool, text::String)
    write(io, text, '\n')
    if !quiet
        println(text)
    end
end


function sim_plot_spline(spline::SimSpline, xlbl::String, ylbl::String, ttle::String, folder::String, filename::String)
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
