# sim_log: Utility function for printing status messages
function sim_log(quiet::Bool, text::String)
    if !quiet
        println(text)
    end
end