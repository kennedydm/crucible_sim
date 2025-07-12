
# SimFault: Defines the location and enumeration of a failure mode
mutable struct SimFault
    enabled         :: Bool
    fault_threshold :: Float64
    #
    function SimFault(id::Int, thresh::Float64)
        ret = new()
        ret.enabled = 0 != id
        ret.fault_threshold = thresh
        return ret
    end
end