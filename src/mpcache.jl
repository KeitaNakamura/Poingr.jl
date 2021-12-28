struct MPCache{dim, T, Tmp <: MPValues{dim, T}}
    mpvalues::Vector{Tmp}
    gridsize::NTuple{dim, Int}
    npoints::Base.RefValue{Int}
    pointsinblock::Array{Vector{Int}, dim}
    spat::Array{Bool, dim}
end

function MPCache(grid::Grid{dim, T}, xₚ::AbstractVector{<: Vec{dim}}) where {dim, T}
    check_interpolation(grid)
    npoints = length(xₚ)
    mpvalues = [MPValues{dim, T}(grid.interpolation) for _ in 1:npoints]
    MPCache(mpvalues, size(grid), Ref(npoints), pointsinblock(grid, xₚ), fill(false, size(grid)))
end

function MPCache(grid::Grid, pointstate::AbstractVector)
    MPCache(grid, pointstate.x)
end

gridsize(cache::MPCache) = cache.gridsize
npoints(cache::MPCache) = cache.npoints[]
pointsinblock(cache::MPCache) = cache.pointsinblock

function reorder_pointstate!(pointstate::AbstractVector, ptsinblk::Array)
    @assert length(pointstate) == sum(length, ptsinblk)
    inds = Vector{Int}(undef, length(pointstate))
    cnt = 1
    for blocks in threadsafe_blocks(@. $size(ptsinblk) << BLOCK_UNIT + 1)
        @inbounds for blockindex in blocks
            block = ptsinblk[blockindex]
            for i in eachindex(block)
                inds[cnt] = block[i]
                block[i] = cnt
                cnt += 1
            end
        end
    end
    @inbounds @. pointstate = pointstate[inds]
    pointstate
end
reorder_pointstate!(pointstate::AbstractVector, grid::Grid) = reorder_pointstate!(pointstate, pointsinblock(grid, pointstate.x))
reorder_pointstate!(pointstate::AbstractVector, cache::MPCache) = reorder_pointstate!(pointstate, pointsinblock(cache))

function allocate!(f, x::Vector, n::Integer)
    len = length(x)
    if n > len # growend
        resize!(x, n)
        @simd for i in len+1:n
            @inbounds x[i] = f(i)
        end
    end
    x
end

function pointsinblock!(ptsinblk::AbstractArray{Vector{Int}}, grid::Grid, xₚ::AbstractVector)
    empty!.(ptsinblk)
    @inbounds for p in 1:length(xₚ)
        I = whichblock(grid, xₚ[p])
        I === nothing && continue
        push!(ptsinblk[I], p)
    end
    ptsinblk
end

function pointsinblock(grid::Grid, xₚ::AbstractVector)
    ptsinblk = Array{Vector{Int}}(undef, blocksize(grid))
    @inbounds @simd for i in eachindex(ptsinblk)
        ptsinblk[i] = Int[]
    end
    pointsinblock!(ptsinblk, grid, xₚ)
end

function sparsity_pattern!(spat::Array{Bool}, grid::Grid, xₚ::AbstractVector, hₚ::AbstractVector, ptsinblk::AbstractArray{Vector{Int}})
    @assert size(spat) == size(grid)
    fill!(spat, false)
    for blocks in threadsafe_blocks(size(grid))
        Threads.@threads for blockindex in blocks
            for p in ptsinblk[blockindex]
                inds = neighboring_nodes(grid, xₚ[p], hₚ[p])
                @inbounds spat[inds] .= true
            end
        end
    end
    @inbounds Threads.@threads for i in eachindex(spat)
        if isinbound(grid, i) # using linear index is ok for `isinbound`
            spat[i] = false
        end
    end
    spat
end

function sparsity_pattern!(spat::Array{Bool}, grid::Grid, pointstate, ptsinblk::AbstractArray{Vector{Int}})
    hₚ = Fill(active_length(grid.interpolation), length(pointstate))
    sparsity_pattern!(spat, grid, pointstate.x, hₚ, ptsinblk)
    spat
end

function sparsity_pattern!(spat::Array{Bool}, grid::Grid{<: Any, <: Any, <: Union{GIMP, WLS{<: Any, GIMP}}}, pointstate, ptsinblk::AbstractArray{Vector{Int}})
    hₚ = LazyDotArray(rₚ -> active_length(grid.interpolation, rₚ ./ gridsteps(grid)), pointstate.r)
    sparsity_pattern!(spat, grid, pointstate.x, hₚ, ptsinblk)
    spat
end

function update_mpvalues!(mpvalues::Vector{<: MPValues}, grid::Grid, pointstate, spat::AbstractArray{Bool}, p::Int)
    update!(mpvalues[p], grid, pointstate.x[p], spat)
end

function update_mpvalues!(mpvalues::Vector{<: Union{GIMPValues, WLSValues{<: Any, GIMP}}}, grid::Grid, pointstate, spat::AbstractArray{Bool}, p::Int)
    update!(mpvalues[p], grid, pointstate.x[p], pointstate.r[p], spat)
end

function update!(cache::MPCache, grid::Grid, pointstate)
    @assert size(grid) == gridsize(cache)

    mpvalues = cache.mpvalues
    pointsinblock = cache.pointsinblock
    spat = cache.spat

    cache.npoints[] = length(pointstate)
    allocate!(i -> eltype(mpvalues)(), mpvalues, length(pointstate))

    pointsinblock!(pointsinblock, grid, pointstate.x)
    sparsity_pattern!(spat, grid, pointstate, pointsinblock)

    Threads.@threads for p in 1:length(pointstate)
        @inbounds update_mpvalues!(mpvalues, grid, pointstate, spat, p)
    end

    gridstate = grid.state
    copyto!(gridstate.spat, spat)
    reinit!(gridstate)

    cache
end

##################
# point_to_grid! #
##################

function _point_to_grid!(p2g, gridstates::Tuple{Vararg{AbstractArray}}, mpvalues::MPValues, p::Int)
    @inbounds @simd for i in 1:length(mpvalues)
        mp = mpvalues[i]
        I = mp.index
        res = p2g(mp, p, I)
        broadcast_tuple(add!, gridstates, I, res)
    end
end

function point_to_grid!(p2g, gridstates::Tuple{Vararg{AbstractArray}}, cache::MPCache, pointmask::Union{AbstractVector{Bool}, Nothing} = nothing)
    @assert all(==(gridsize(cache)), size.(gridstates))
    map(fillzero!, gridstates)
    pointmask !== nothing && @assert length(pointmask) == npoints(cache)
    for blocks in threadsafe_blocks(gridsize(cache))
        Threads.@threads for blockindex in blocks
            @inbounds for p in pointsinblock(cache)[blockindex]
                pointmask !== nothing && !pointmask[p] && continue
                _point_to_grid!(p2g, gridstates, cache.mpvalues[p], p)
            end
        end
    end
    gridstates
end

function point_to_grid!(p2g, gridstate::AbstractArray, cache::MPCache, pointmask::Union{AbstractVector{Bool}, Nothing} = nothing)
    point_to_grid!((gridstate,), cache, pointmask) do mp, p, I
        @_inline_meta
        @_propagate_inbounds_meta
        (p2g(mp, p, I),)
    end
end

@inline function stress_to_force(coordinate_system::Symbol, N, ∇N, x::Vec{2}, σ::SymmetricSecondOrderTensor{3})
    f = Tensor2D(σ) ⋅ ∇N
    if coordinate_system == :axisymmetric
        @inbounds f += Vec(1,0)*σ[3,3]*N/x[1]
    end
    f
end
@inline function stress_to_force(::Symbol, N, ∇N, x::Vec{3}, σ::SymmetricSecondOrderTensor{3})
    σ ⋅ ∇N
end

for (InterpolationType, InterpolationValuesType) in ((BSpline, BSplineValues),
                                             (GIMP, GIMPValues))
    @eval function default_normal_point_to_grid!(
            grid::Grid{<: Any, <: Any, <: $InterpolationType},
            pointstate,
            cache::MPCache{<: Any, <: Any, <: $InterpolationValuesType}
        )
        point_to_grid!((grid.state.m, grid.state.v, grid.state.f), cache) do mp, p, i
            @_inline_meta
            @_propagate_inbounds_meta
            N = mp.N
            ∇N = mp.∇N
            xₚ = pointstate.x[p]
            mₚ = pointstate.m[p]
            Vₚ = pointstate.V[p]
            vₚ = pointstate.v[p]
            σₚ = pointstate.σ[p]
            bₚ = pointstate.b[p]
            xᵢ = grid[i]
            m = mₚ * N
            v = m * vₚ
            f = -Vₚ * stress_to_force(grid.coordinate_system, N, ∇N, xₚ, σₚ) + m * bₚ
            m, v, f
        end
        @dot_threads grid.state.v /= grid.state.m
        @. grid.state.v_n = grid.state.v
        grid
    end
end

function default_normal_point_to_grid!(
        grid::Grid{<: Any, <: Any, <: WLS},
        pointstate,
        cache::MPCache{<: Any, <: Any, <: WLSValues}
    )
    P = basis_function(grid.interpolation)
    point_to_grid!((grid.state.m, grid.state.v, grid.state.f), cache) do mp, p, i
        @_inline_meta
        @_propagate_inbounds_meta
        N = mp.N
        ∇N = mp.∇N
        xₚ = pointstate.x[p]
        mₚ = pointstate.m[p]
        Vₚ = pointstate.V[p]
        Cₚ = pointstate.C[p]
        σₚ = pointstate.σ[p]
        bₚ = pointstate.b[p]
        xᵢ = grid[i]
        m = mₚ * N
        v = m * Cₚ ⋅ value(P, xᵢ - xₚ)
        f = -Vₚ * stress_to_force(grid.coordinate_system, N, ∇N, xₚ, σₚ) + m * bₚ
        m, v, f
    end
    @dot_threads grid.state.v /= grid.state.m
    grid
end

function default_affine_point_to_grid!(grid::Grid{dim}, pointstate, cache::MPCache{dim}) where {dim}
    point_to_grid!((grid.state.m, grid.state.v, grid.state.f), cache) do mp, p, i
        @_inline_meta
        @_propagate_inbounds_meta
        N = mp.N
        ∇N = mp.∇N
        xₚ  = pointstate.x[p]
        mₚ  = pointstate.m[p]
        Vₚ  = pointstate.V[p]
        vₚ  = pointstate.v[p]
        ∇vₚ = pointstate.∇v[p]
        σₚ  = pointstate.σ[p]
        bₚ  = pointstate.b[p]
        xᵢ  = grid[i]
        m = mₚ * N
        v = m * (vₚ + @Tensor(∇vₚ[1:dim, 1:dim]) ⋅ (xᵢ - xₚ))
        f = -Vₚ * stress_to_force(grid.coordinate_system, N, ∇N, xₚ, σₚ) + m * bₚ
        m, v, f
    end
    @dot_threads grid.state.v /= grid.state.m
    grid
end

function default_point_to_grid!( grid::Grid, pointstate, cache::MPCache)
    default_normal_point_to_grid!(grid, pointstate, cache)
end

function default_point_to_grid!(
        grid::Grid{<: Any, <: Any, <: WLS{PolynomialBasis{1}}},
        pointstate,
        cache::MPCache{<: Any, <: Any, <: WLSValues{PolynomialBasis{1}}}
    )
    default_affine_point_to_grid!(grid, pointstate, cache)
end

##################
# grid_to_point! #
##################

function grid_to_point(g2p, mpvalues::MPValues)
    mp = mpvalues[1]
    vals = g2p(mp, mp.index)
    @inbounds @simd for i in 2:length(mpvalues)
        mp = mpvalues[i]
        res = g2p(mp, mp.index)
        vals = broadcast_tuple(+, vals, res)
    end
    vals
end

function grid_to_point!(g2p, pointstates::Tuple{Vararg{AbstractVector}}, cache::MPCache, pointmask::Union{AbstractVector{Bool}, Nothing} = nothing)
    @assert all(==(npoints(cache)), length.(pointstates))
    results = grid_to_point(g2p, cache, pointmask)
    @assert length(results) == npoints(cache)
    Threads.@threads for p in 1:npoints(cache)
        @inbounds broadcast_tuple(setindex!, pointstates, results[p], p)
    end
end

function grid_to_point(g2p, cache::MPCache, pointmask::Union{AbstractVector{Bool}, Nothing} = nothing)
    pointmask !== nothing && @assert length(pointmask) == npoints(cache)
    LazyDotArray(1:npoints(cache)) do p
        pointmask !== nothing && !pointmask[p] && return @inbounds broadcast_tuple(getindex, pointstates, p)
        grid_to_point(cache.mpvalues[p]) do mp, I
            @_inline_meta
            @_propagate_inbounds_meta
            g2p(mp, I, p)
        end
    end
end

function grid_to_point!(g2p, pointstate::AbstractVector, cache::MPCache, pointmask::Union{AbstractVector{Bool}, Nothing} = nothing)
    grid_to_point!((pointstate,), cache, pointmask) do mp, I, p
        @_inline_meta
        @_propagate_inbounds_meta
        (g2p(mp, I, p),)
    end
end

@inline function velocity_gradient(coordinate_system::Symbol, x::Vec{2}, v::Vec{2}, ∇v::SecondOrderTensor{2})
    ∇v = Poingr.Tensor3D(∇v)
    if coordinate_system == :axisymmetric
        @inbounds ∇v += @Mat([0 0 0; 0 0 0; 0 0 v[1]/x[1]])
    end
    ∇v
end
@inline function velocity_gradient(::Symbol, x::Vec{3}, v::Vec{3}, ∇v::SecondOrderTensor{3})
    ∇v
end

for (InterpolationType, InterpolationValuesType) in ((BSpline, BSplineValues),
                                             (GIMP, GIMPValues))
    @eval function default_normal_grid_to_point!(
            pointstate,
            grid::Grid{<: Any, <: Any, <: $InterpolationType},
            cache::MPCache{<: Any, <: Any, <: $InterpolationValuesType},
            dt::Real
        )
        pointvalues = grid_to_point(cache) do mp, i, p
            @_inline_meta
            @_propagate_inbounds_meta
            N = mp.N
            ∇N = mp.∇N
            dvᵢ = grid.state.v[i] - grid.state.v_n[i]
            vᵢ = grid.state.v[i]
            N*dvᵢ, N*vᵢ, vᵢ⊗∇N
        end
        @inbounds Threads.@threads for p in 1:npoints(cache)
            dvₚ, vₚ, ∇vₚ = pointvalues[p]
            pointstate.∇v[p] = velocity_gradient(grid.coordinate_system, pointstate.x[p], vₚ, ∇vₚ)
            pointstate.v[p] += dvₚ
            pointstate.x[p] += vₚ * dt
        end
        pointstate
    end
end

function default_normal_grid_to_point!(
        pointstate,
        grid::Grid{dim, <: Any, <: WLS},
        cache::MPCache{dim, <: Any, <: WLSValues},
        dt::Real
    ) where {dim}
    P = basis_function(grid.interpolation)
    p0 = value(P, zero(Vec{dim, Int}))
    ∇p0 = gradient(P, zero(Vec{dim, Int}))
    grid_to_point!(pointstate.C, cache) do mp, i, p
        @_inline_meta
        @_propagate_inbounds_meta
        w = mp.w
        M⁻¹ = mp.M⁻¹
        grid.state.v[i] ⊗ (w * M⁻¹ ⋅ value(P, grid[i] - pointstate.x[p]))
    end
    @inbounds Threads.@threads for p in 1:length(pointstate)
        Cₚ = pointstate.C[p]
        xₚ = pointstate.x[p]
        vₚ = Cₚ ⋅ p0
        pointstate.v[p] = vₚ
        pointstate.∇v[p] = velocity_gradient(grid.coordinate_system, xₚ, vₚ, Cₚ ⋅ ∇p0)
        pointstate.x[p] = xₚ + vₚ * dt
    end
    pointstate
end

function default_affine_grid_to_point!(pointstate, grid::Grid, cache::MPCache, dt::Real)
    pointvalues = grid_to_point(cache) do mp, i, p
        @_inline_meta
        @_propagate_inbounds_meta
        N = mp.N
        ∇N = mp.∇N
        vᵢ = grid.state.v[i]
        vᵢ*N, vᵢ⊗∇N
    end
    @inbounds Threads.@threads for p in 1:npoints(cache)
        vₚ, ∇vₚ = pointvalues[p]
        xₚ = pointstate.x[p]
        pointstate.v[p] = vₚ
        pointstate.∇v[p] = velocity_gradient(grid.coordinate_system, xₚ, vₚ, ∇vₚ)
        pointstate.x[p] = xₚ + vₚ * dt
    end
    pointstate
end

function default_grid_to_point!(pointstate, grid::Grid, cache::MPCache, dt::Real)
    default_normal_grid_to_point!(pointstate, grid, cache, dt)
end

function default_grid_to_point!(
        pointstate,
        grid::Grid{<: Any, <: Any, <: WLS{PolynomialBasis{1}}},
        cache::MPCache{<: Any, <: Any, <: WLSValues{PolynomialBasis{1}}},
        dt::Real
    )
    default_affine_grid_to_point!(pointstate, grid, cache, dt)
end

@generated function safe_inv(x::Mat{dim, dim, T, L}) where {dim, T, L}
    exps = fill(:z, L-1)
    quote
        @_inline_meta
        z = zero(T)
        isapproxzero(det(x)) ? Mat{dim, dim}(inv(x[1]), $(exps...)) : inv(x)
        # Tensorial.rank(x) != dim ? Mat{dim, dim}(inv(x[1]), $(exps...)) : inv(x) # this is very slow but stable
    end
end

function smooth_pointstate!(vals::AbstractVector, Vₚ::AbstractVector, grid::Grid, cache::MPCache)
    @assert length(vals) == length(Vₚ) == npoints(cache)
    basis = PolynomialBasis{1}()
    point_to_grid!((grid.state.poly_coef, grid.state.poly_mat), cache) do mp, p, i
        @_inline_meta
        @_propagate_inbounds_meta
        P = value(basis, mp.x - grid[i])
        VP = (mp.N * Vₚ[p]) * P
        VP * vals[p], VP ⊗ P
    end
    @dot_threads grid.state.poly_coef = safe_inv(grid.state.poly_mat) ⋅ grid.state.poly_coef
    grid_to_point!(vals, cache) do mp, i, p
        @_inline_meta
        @_propagate_inbounds_meta
        P = value(basis, mp.x - grid[i])
        mp.N * (P ⋅ grid.state.poly_coef[i])
    end
end
