mutable struct Time
    T::Rational{Int}
    tϵ::Float64
end

mutable struct AsyncBlock{PointState <: StructVector}
    pointstate::PointState
    buffer::PointState
    T::Rational{Int}
    T_buffer::Rational{Int}
    Tmin_local::Rational{Int}
    dT::Rational{Int}
end

struct AsyncScheduler{PointState, dim}
    blocks::Array{AsyncBlock{PointState}, dim}
    gridsize::NTuple{dim, Int}
    time::Time
    pointstate::PointState
    precise_near_surface::Bool
end

gridsize(sch::AsyncScheduler) = sch.gridsize
currenttime(sch::AsyncScheduler) = (time = sch.time; time.tϵ * time.T)

function paint_timesteps(sch::AsyncScheduler)
    cells = Array{Float64}(undef, gridsize(sch) .- 1)
    for I in CartesianIndices(cells)
        blockindex = CartesianIndex(@. ($Tuple(I) - 1) >> BLOCK_UNIT + 1)
        cells[I] = sch.blocks[blockindex].dT * sch.time.tϵ
    end
    cells
end

function issynced(sch::AsyncScheduler)
    iter = (block.T for block in sch.blocks if !isempty(block.pointstate))
    x0 = first(iter)
    all(==(x0), iter)
end

function synced_pointstate(sch::AsyncScheduler)
    @assert issynced(sch)
    pointstate = similar(sch.pointstate, 0)
    for block in sch.blocks
        append!(pointstate, block.pointstate)
    end
    pointstate
end

function AsyncScheduler(grid::Grid, pointstate::PointState, tϵ::Real = 1; precise_near_surface = false) where {PointState <: StructVector}
    blocks = map(pointsinblock(grid, pointstate.x)) do pointindices
        ps = pointstate[pointindices]
        buf = copy(ps)
        AsyncBlock{PointState}(ps, buf, 0, 0, 0, 1)
    end
    AsyncScheduler(blocks, size(grid), Time(0, tϵ), similar(pointstate, 0), precise_near_surface)
end

function updatetimestep!(calculate_timestep::Function, sch::AsyncScheduler, grid::Grid; isincontact = nothing)
    time = sch.time
    blocks = sch.blocks

    nearsurface = falses(size(blocks))
    if isincontact !== nothing
        @inbounds Threads.@threads for i in eachindex(blocks)
            block = blocks[i]
            isincontact_in_block = false
            for x in block.pointstate.x
                if isincontact(x)
                    isincontact_in_block = true
                    break
                end
            end
            nearsurface[i] = isincontact_in_block
        end
        temp = copy(nearsurface)
        @inbounds for I in CartesianIndices(blocks)
            if temp[I]
                for J in neighboring_blocks(grid, I, 1)
                    nearsurface[J] = true
                end
            end
        end
    end

    # for non-empty blocks
    Threads.@threads for block in blocks
        (mod(time.T, block.dT) == 0 && !isempty(block.pointstate)) || continue
        limit = minimum(calculate_timestep, block.pointstate) / time.tϵ
        while limit < block.dT
            block.dT /= 2
        end
        while limit ≥ 2*block.dT && mod(time.T, 2*block.dT) == 0
            block.dT *= 2
        end
    end
    dTmin, dTmax = extrema(block.dT for block in blocks if !isempty(block.pointstate))

    # for empty blocks
    @inbounds Threads.@threads for block in blocks
        (mod(time.T, block.dT) == 0 && isempty(block.pointstate)) || continue
        while dTmax < block.dT
            block.dT /= 2
        end
        while dTmax ≥ 2*block.dT && mod(time.T, 2*block.dT) == 0
            block.dT *= 2
        end
    end

    # for nearsurface blocks
    @inbounds Threads.@threads for I in eachindex(blocks)
        block = blocks[I]
        mod(time.T, block.dT) == 0 || continue
        if nearsurface[I]
            @assert mod(time.T, dTmin) == 0
            block.dT = dTmin
            if mod(time.T, dTmax) == 0 && sch.precise_near_surface
                block.dT /= 2
            end
        end
    end
    dTmin, dTmax = extrema(block.dT for block in blocks)

    # most minimum T in local region
    @inbounds Threads.@threads for I in CartesianIndices(blocks)
        block = blocks[I]
        block.dT == dTmin && continue
        Tmin_local = 1//0
        for J in neighboring_blocks(grid, I, 1)
            block_nearby = blocks[J]
            Tmin_local = min(Tmin_local, block_nearby.T + block_nearby.dT)
        end
        block.Tmin_local = Tmin_local
    end

    sch
end

function advance!(microstep::Function, sch::AsyncScheduler, grid::Grid, dT::Rational)
    time = sch.time
    blocks = sch.blocks

    mask_equal = falses(size(blocks))
    mask_larger = falses(size(blocks))
    mask_smaller = falses(size(blocks))
    @inbounds for I in CartesianIndices(blocks)
        block = blocks[I]
        if block.dT == dT
            @assert block.T == time.T
            mask_equal[I] = true
            for J in neighboring_blocks(grid, I, 1)
                block_nearby = blocks[J]
                if block_nearby.dT > block.dT
                    @assert block.T == block_nearby.T_buffer
                    mask_larger[J] = true
                end
                if block_nearby.dT < block.dT
                    @assert block.T == block_nearby.T
                    mask_smaller[J] = true
                end
            end
        end
    end
    @assert !any(mask_equal .& mask_larger)
    @assert !any(mask_equal .& mask_smaller)
    @assert !any(mask_larger .& mask_smaller)

    @inbounds Threads.@threads for I in eachindex(blocks)
        block = blocks[I]
        if mask_equal[I]
            copy!(block.buffer, block.pointstate)
            block.T_buffer = block.T
        end
    end

    @inbounds for I in eachindex(blocks)
        block = blocks[I]
        if mask_equal[I]
            @assert block.T == time.T
            append!(sch.pointstate, block.pointstate)
        elseif mask_larger[I]
            @assert block.T_buffer == time.T
            append!(sch.pointstate, block.buffer)
        elseif mask_smaller[I]
            @assert block.T == time.T
            append!(sch.pointstate, block.pointstate)
        end
    end

    microstep(sch.pointstate, time.tϵ * dT)

    @inbounds Threads.@threads for I in eachindex(blocks)
        block = blocks[I]
        if mask_equal[I]
            empty!(block.pointstate)
            block.T += dT # advance block for pointstate
            @assert block.T == time.T + dT
        elseif mask_larger[I] && block.Tmin_local == time.T + dT
            empty!(block.buffer)
            block.T_buffer += dT # advance block for buffer
            @assert block.T_buffer == time.T + dT
        end
    end

    @inbounds for p in sch.pointstate
        I = whichblock(grid, p.x)
        I === nothing && continue
        block = blocks[I]
        if mask_equal[I]
            push!(block.pointstate, p)
        elseif mask_larger[I] && block.Tmin_local == time.T + dT
            push!(block.buffer, p)
        end
    end

    empty!(sch.pointstate)
end

function asyncstep!(microstep::Function, sch::AsyncScheduler, grid::Grid)
    time = sch.time
    dTs = sort(unique(block.dT for block in sch.blocks), rev = true)
    for dT in dTs
        if mod(time.T, dT) == 0
            advance!(microstep, sch, grid, dT)
        end
    end
    dTmin = dTs[end]
    dT = dTmin - mod(time.T, dTmin)
    time.T += dT
    time.tϵ * dT
end
