
# SimFault: Defines the location and enumeration of a failure mode
mutable struct SimFault
    threshold   :: Float64
    id          :: Int
    enabled     :: Bool
    #
    function SimFault(id::Int, thresh::Float64)
        ret = new()
        ret.enabled = 0 != id
        ret.id = 0
        if ret.enabled
            ret.id = id
        end
        ret.threshold = thresh
        return ret
    end
end



# SimFlatten: Defines the location and enumeration of a flattening artifact
mutable struct SimFlatten
    x0              :: Float64
    y0              :: Float64
    x1              :: Float64
    y1              :: Float64
    override        :: Float64
    enabled         :: Bool
    #
    function SimFlatten(enabled::Bool, rng::Xoshiro)
        ret = new()
        ret.enabled = enabled
        if enabled
            x0 = rand(rng)
            x1 = rand(rng)
            y0 = 0.15 + 0.7 * rand(rng)
            y1 = 0.15 + 0.7 * rand(rng)
            if x0 > x1
                temp = x0
                x0 = x1
                x1 = temp
            end
            if y0 > y1
                temp = y0
                y0 = y1
                y1 = temp
            end
            ret.x0 = x0
            ret.y0 = y0
            ret.x1 = x1
            ret.y1 = y1
            ret.override = y0 + (y1 - y0) * rand(rng)
        end
        return ret
    end
end


# SimFlatten: Defines the location and enumeration of a flattening artifact
mutable struct SimInvert
    x0              :: Float64
    y0              :: Float64
    x1              :: Float64
    y1              :: Float64
    enabled         :: Bool
    #
    function SimInvert(enabled::Bool, rng::Xoshiro)
        ret = new()
        ret.enabled = enabled
        if enabled
            x0 = rand(rng)
            x1 = rand(rng)
            y0 = 0.15 + 0.7 * rand(rng)
            y1 = 0.15 + 0.7 * rand(rng)
            if x0 > x1
                temp = x0
                x0 = x1
                x1 = temp
            end
            if y0 > y1
                temp = y0
                y0 = y1
                y1 = temp
            end
            ret.x0 = x0
            ret.y0 = y0
            ret.x1 = x1
            ret.y1 = y1
        end
        return ret
    end
end