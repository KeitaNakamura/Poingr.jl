var documenterSearchIndex = {"docs":
[{"location":"contact_mechanics/","page":"ContactMechanics","title":"ContactMechanics","text":"DocTestSetup = :(using Poingr)","category":"page"},{"location":"contact_mechanics/#Contact-mechanics","page":"ContactMechanics","title":"Contact mechanics","text":"","category":"section"},{"location":"contact_mechanics/","page":"ContactMechanics","title":"ContactMechanics","text":"Order = [:type, :function]\nPages = [\"contact_mechanics.md\"]","category":"page"},{"location":"contact_mechanics/","page":"ContactMechanics","title":"ContactMechanics","text":"Modules = [Poingr]\nOrder   = [:type, :function]\nPages   = [\"contact_mechanics.jl\"]","category":"page"},{"location":"contact_mechanics/#Poingr.Contact","page":"ContactMechanics","title":"Poingr.Contact","text":"Contact(:sticky)\nContact(:slip; sep)\nContact(:friction, coef; sep)\n\nContact condition handling contact mechanics in MPM. Following conditions are available:\n\n:sticky: Continuum body is sticked on the boundary surface.\n:slip: Continuum body is slipped on the boundary surface.\n:friction: Continuum body is slipped with frictional coefficient coef on the boundary surface.\n\nIf sep is true, continuum body can leave from the boundary surface.\n\nExamples\n\njulia> Contact(:sticky)\nContact(:sticky)\n\njulia> Contact(:slip, sep = true)\nContact(:slip; sep = true)\n\njulia> Contact(:friction, 0.3, sep = true)\nContact(:friction, 0.3; sep = true)\n\n\n\n(::Contact)(v::Vec, n::Vec)\n\nCompute velocity v caused by contact. The other quantities, which are equivalent to velocity such as momentum and force, are also available. n is the normal unit vector.\n\nExamples\n\njulia> contact = Contact(:slip, sep = false);\n\njulia> v = Vec(1.0, -1.0); n = Vec(0.0, -1.0);\n\njulia> v + contact(v, n)\n2-element Vec{2, Float64}:\n 1.0\n 0.0\n\n\n\n\n\n","category":"type"},{"location":"VTK_outputs/","page":"VTK outputs","title":"VTK outputs","text":"DocTestSetup = :(using Poingr)","category":"page"},{"location":"VTK_outputs/#Poingr.VTKOutputs","page":"VTK outputs","title":"Poingr.VTKOutputs","text":"","category":"section"},{"location":"VTK_outputs/","page":"VTK outputs","title":"VTK outputs","text":"Order = [:type, :function]\nPages = [\"VTK_outputs.md\"]","category":"page"},{"location":"VTK_outputs/","page":"VTK outputs","title":"VTK outputs","text":"Modules = [Poingr]\nOrder   = [:type, :function]\nPages   = [\"vtk.jl\"]","category":"page"},{"location":"VTK_outputs/#Poingr.vtk_points-Tuple{Any, AbstractVector{var\"#s412\"} where var\"#s412\"<:(Vec{dim, T} where {dim, T})}","page":"VTK outputs","title":"Poingr.vtk_points","text":"vtk_points(filename::AbstractString, points::AbstractVector{<: Vec})\n\nCreate VTK file to visualize points. This should be used instead of calling vtk_grid in WriteVTK package.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:10.0, 0.0:1.0:10.0);\n\njulia> pointstate = generate_pointstate((x, y) -> (x-5)^2 + (y-5)^2 < 3^2, grid, n = 4);\n\njulia> vtkfile = vtk_points(\"vtkfile\", pointstate.x)\nVTK file 'vtkfile.vtu' (UnstructuredGrid file, open)\n\njulia> vtk_save(vtkfile)\n1-element Vector{String}:\n \"vtkfile.vtu\"\n\n\n\n\n\n","category":"method"},{"location":"VTK_outputs/#WriteVTK.vtk_grid-Tuple{AbstractString, Grid}","page":"VTK outputs","title":"WriteVTK.vtk_grid","text":"vtk_grid(filename::AbstractString, grid::Grid)\n\nCreate a structured VTK grid from a Grid.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:10.0, 0.0:1.0:10.0);\n\njulia> vtkfile = vtk_grid(\"vtkfile\", grid)\nVTK file 'vtkfile.vtr' (RectilinearGrid file, open)\n\njulia> vtk_save(vtkfile)\n1-element Vector{String}:\n \"vtkfile.vtr\"\n\n\n\n\n\n","category":"method"},{"location":"grid/","page":"Grid","title":"Grid","text":"DocTestSetup = :(using Poingr)","category":"page"},{"location":"grid/#Grid","page":"Grid","title":"Grid","text":"","category":"section"},{"location":"grid/","page":"Grid","title":"Grid","text":"Order = [:type, :function]\nPages = [\"grid.md\"]","category":"page"},{"location":"grid/","page":"Grid","title":"Grid","text":"Modules = [Poingr]\nOrder   = [:type, :function]\nPages   = [\"grid.jl\"]","category":"page"},{"location":"grid/#Poingr.Grid","page":"Grid","title":"Poingr.Grid","text":"Grid([::Type{NodeState}], [::ShapeFunction], axes::AbstractVector...)\n\nConstruct Grid by axes.\n\nExamples\n\njulia> Grid(range(0, 3, step = 1.0), range(1, 4, step = 1.0))\n4×4 Grid{2, Float64, Nothing, Nothing, Poingr.SpArray{Nothing, 2, StructArrays.StructVector{Nothing, NamedTuple{(), Tuple{}}, Int64}}}:\n [0.0, 1.0]  [0.0, 2.0]  [0.0, 3.0]  [0.0, 4.0]\n [1.0, 1.0]  [1.0, 2.0]  [1.0, 3.0]  [1.0, 4.0]\n [2.0, 1.0]  [2.0, 2.0]  [2.0, 3.0]  [2.0, 4.0]\n [3.0, 1.0]  [3.0, 2.0]  [3.0, 3.0]  [3.0, 4.0]\n\n\n\n\n\n","category":"type"},{"location":"grid/#Poingr.neighboring_cells-Union{Tuple{dim}, Tuple{Grid{dim, T, F, Node, State} where {T, F<:Union{Nothing, Poingr.ShapeFunction}, Node, State<:(Poingr.SpArray{Node, dim, V} where V<:AbstractVector{Node})}, CartesianIndex{dim}, Int64}} where dim","page":"Grid","title":"Poingr.neighboring_cells","text":"Poingr.neighboring_cells(grid, x::Vec, h::Int)\nPoingr.neighboring_cells(grid, cellindex::CartesianIndex, h::Int)\n\nReturn CartesianIndices storing neighboring cell indices around x. h is number of outer cells around cell where x locates. In 1D, for example, the searching range becomes x ± h*dx.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:5.0, 0.0:1.0:5.0)\n6×6 Grid{2, Float64, Nothing, Nothing, Poingr.SpArray{Nothing, 2, StructArrays.StructVector{Nothing, NamedTuple{(), Tuple{}}, Int64}}}:\n [0.0, 0.0]  [0.0, 1.0]  [0.0, 2.0]  [0.0, 3.0]  [0.0, 4.0]  [0.0, 5.0]\n [1.0, 0.0]  [1.0, 1.0]  [1.0, 2.0]  [1.0, 3.0]  [1.0, 4.0]  [1.0, 5.0]\n [2.0, 0.0]  [2.0, 1.0]  [2.0, 2.0]  [2.0, 3.0]  [2.0, 4.0]  [2.0, 5.0]\n [3.0, 0.0]  [3.0, 1.0]  [3.0, 2.0]  [3.0, 3.0]  [3.0, 4.0]  [3.0, 5.0]\n [4.0, 0.0]  [4.0, 1.0]  [4.0, 2.0]  [4.0, 3.0]  [4.0, 4.0]  [4.0, 5.0]\n [5.0, 0.0]  [5.0, 1.0]  [5.0, 2.0]  [5.0, 3.0]  [5.0, 4.0]  [5.0, 5.0]\n\njulia> x = Vec(1.5, 1.5);\n\njulia> Poingr.neighboring_cells(grid, x, 1)\n3×3 CartesianIndices{2, Tuple{UnitRange{Int64}, UnitRange{Int64}}}:\n CartesianIndex(1, 1)  CartesianIndex(1, 2)  CartesianIndex(1, 3)\n CartesianIndex(2, 1)  CartesianIndex(2, 2)  CartesianIndex(2, 3)\n CartesianIndex(3, 1)  CartesianIndex(3, 2)  CartesianIndex(3, 3)\n\njulia> Poingr.neighboring_cells(grid, Poingr.whichcell(grid, x), 1) == ans\ntrue\n\n\n\n\n\n","category":"method"},{"location":"grid/#Poingr.neighboring_nodes-Union{Tuple{dim}, Tuple{Grid{dim, T, F, Node, State} where {T, F<:Union{Nothing, Poingr.ShapeFunction}, Node, State<:(Poingr.SpArray{Node, dim, V} where V<:AbstractVector{Node})}, Vec{dim, T} where T, Any}} where dim","page":"Grid","title":"Poingr.neighboring_nodes","text":"Poingr.neighboring_nodes(grid, x::Vec, h)\n\nReturn CartesianIndices storing neighboring node indices around x. h is a range for searching and its unit is gridsteps dx. In 1D, for example, the searching range becomes x ± h*dx.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:5.0)\n6-element Grid{1, Float64, Nothing, Nothing, Poingr.SpArray{Nothing, 1, StructArrays.StructVector{Nothing, NamedTuple{(), Tuple{}}, Int64}}}:\n [0.0]\n [1.0]\n [2.0]\n [3.0]\n [4.0]\n [5.0]\n\njulia> Poingr.neighboring_nodes(grid, Vec(1.5), 1)\n2-element CartesianIndices{1, Tuple{UnitRange{Int64}}}:\n CartesianIndex(2,)\n CartesianIndex(3,)\n\njulia> Poingr.neighboring_nodes(grid, Vec(1.5), 2)\n4-element CartesianIndices{1, Tuple{UnitRange{Int64}}}:\n CartesianIndex(1,)\n CartesianIndex(2,)\n CartesianIndex(3,)\n CartesianIndex(4,)\n\n\n\n\n\n","category":"method"},{"location":"grid/#Poingr.whichblock-Tuple{Grid, Vec{dim, T} where {dim, T}}","page":"Grid","title":"Poingr.whichblock","text":"Poingr.whichblock(grid, x::Vec)\n\nReturn block index where x locates. The unit block size is 2^3 cells.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:10.0, 0.0:1.0:10.0)\n11×11 Grid{2, Float64, Nothing, Nothing, Poingr.SpArray{Nothing, 2, StructArrays.StructVector{Nothing, NamedTuple{(), Tuple{}}, Int64}}}:\n [0.0, 0.0]   [0.0, 1.0]   [0.0, 2.0]   …  [0.0, 9.0]   [0.0, 10.0]\n [1.0, 0.0]   [1.0, 1.0]   [1.0, 2.0]      [1.0, 9.0]   [1.0, 10.0]\n [2.0, 0.0]   [2.0, 1.0]   [2.0, 2.0]      [2.0, 9.0]   [2.0, 10.0]\n [3.0, 0.0]   [3.0, 1.0]   [3.0, 2.0]      [3.0, 9.0]   [3.0, 10.0]\n [4.0, 0.0]   [4.0, 1.0]   [4.0, 2.0]      [4.0, 9.0]   [4.0, 10.0]\n [5.0, 0.0]   [5.0, 1.0]   [5.0, 2.0]   …  [5.0, 9.0]   [5.0, 10.0]\n [6.0, 0.0]   [6.0, 1.0]   [6.0, 2.0]      [6.0, 9.0]   [6.0, 10.0]\n [7.0, 0.0]   [7.0, 1.0]   [7.0, 2.0]      [7.0, 9.0]   [7.0, 10.0]\n [8.0, 0.0]   [8.0, 1.0]   [8.0, 2.0]      [8.0, 9.0]   [8.0, 10.0]\n [9.0, 0.0]   [9.0, 1.0]   [9.0, 2.0]      [9.0, 9.0]   [9.0, 10.0]\n [10.0, 0.0]  [10.0, 1.0]  [10.0, 2.0]  …  [10.0, 9.0]  [10.0, 10.0]\n\njulia> Poingr.whichblock(grid, Vec(8.5, 1.5))\nCartesianIndex(2, 1)\n\n\n\n\n\n","category":"method"},{"location":"grid/#Poingr.whichcell-Union{Tuple{dim}, Tuple{Grid{dim, T, F, Node, State} where {T, F<:Union{Nothing, Poingr.ShapeFunction}, Node, State<:(Poingr.SpArray{Node, dim, V} where V<:AbstractVector{Node})}, Vec{dim, T} where T}} where dim","page":"Grid","title":"Poingr.whichcell","text":"Poingr.whichcell(grid, x::Vec)\n\nReturn cell index where x locates.\n\nExamples\n\njulia> grid = Grid(0.0:1.0:5.0, 0.0:1.0:5.0)\n6×6 Grid{2, Float64, Nothing, Nothing, Poingr.SpArray{Nothing, 2, StructArrays.StructVector{Nothing, NamedTuple{(), Tuple{}}, Int64}}}:\n [0.0, 0.0]  [0.0, 1.0]  [0.0, 2.0]  [0.0, 3.0]  [0.0, 4.0]  [0.0, 5.0]\n [1.0, 0.0]  [1.0, 1.0]  [1.0, 2.0]  [1.0, 3.0]  [1.0, 4.0]  [1.0, 5.0]\n [2.0, 0.0]  [2.0, 1.0]  [2.0, 2.0]  [2.0, 3.0]  [2.0, 4.0]  [2.0, 5.0]\n [3.0, 0.0]  [3.0, 1.0]  [3.0, 2.0]  [3.0, 3.0]  [3.0, 4.0]  [3.0, 5.0]\n [4.0, 0.0]  [4.0, 1.0]  [4.0, 2.0]  [4.0, 3.0]  [4.0, 4.0]  [4.0, 5.0]\n [5.0, 0.0]  [5.0, 1.0]  [5.0, 2.0]  [5.0, 3.0]  [5.0, 4.0]  [5.0, 5.0]\n\njulia> Poingr.whichcell(grid, Vec(1.5, 1.5))\nCartesianIndex(2, 2)\n\n\n\n\n\n","category":"method"},{"location":"logger/","page":"Loggers","title":"Loggers","text":"DocTestSetup = :(using Poingr)","category":"page"},{"location":"logger/#Logger","page":"Loggers","title":"Logger","text":"","category":"section"},{"location":"logger/","page":"Loggers","title":"Loggers","text":"Order = [:type, :function]\nPages = [\"logger.md\"]","category":"page"},{"location":"logger/","page":"Loggers","title":"Loggers","text":"Modules = [Poingr]\nOrder   = [:type, :function]\nPages   = [\"logger.jl\"]","category":"page"},{"location":"logger/#Poingr.Logger","page":"Loggers","title":"Poingr.Logger","text":"Logger(logpoints::AbstractVector; progress = false)\n\nConstruct logger which handle with time event in the calculation. The workflow using Logger can be written as follows:\n\nfunction workflow()\n    logpoints = 0:0.5:5\n    logger = Logger(logpoints)\n    t = 0.0\n    dt = 0.2\n    timestamps = Float64[]\n\n    while !isfinised(logger, t)\n        #\n        # 1. Calculations...\n        #\n\n        # 2. Update time step and logger\n        update!(logger, t += dt)\n\n        #\n        # 3. Save data at log point\n        #\n        if islogpoint(logger)\n\n            # linear index is available for numbering data\n            i = logindex(logger)\n\n            push!(timestamps, t)\n        end\n    end\n\n    timestamps\nend\n\nworkflow()\n\n# output\n\n11-element Vector{Float64}:\n 0.2\n 0.6000000000000001\n 1.0\n 1.5999999999999999\n 2.1999999999999997\n 2.6\n 3.0000000000000004\n 3.600000000000001\n 4.000000000000001\n 4.600000000000001\n 5.000000000000002\n\nAs shown above example, islogpoint(logger) is true when time t become first greater than or equalt to logpoints.\n\n\n\n\n\n","category":"type"},{"location":"shape_functions/","page":"Shape functions","title":"Shape functions","text":"DocTestSetup = :(using Poingr)","category":"page"},{"location":"shape_functions/#Shape-functions","page":"Shape functions","title":"Shape functions","text":"","category":"section"},{"location":"shape_functions/","page":"Shape functions","title":"Shape functions","text":"Order = [:type, :function]\nPages = [\"shape_functions.md\"]","category":"page"},{"location":"shape_functions/","page":"Shape functions","title":"Shape functions","text":"Modules = [Poingr]\nOrder   = [:type, :function]\nPages   = [\"ShapeFunctions/shapefunction.jl\",\n           \"ShapeFunctions/bspline.jl\",\n           \"ShapeFunctions/wls.jl\"]","category":"page"},{"location":"shape_functions/#Poingr.ShapeValues-Union{Tuple{Poingr.ShapeFunction}, Tuple{dim}} where dim","page":"Shape functions","title":"Poingr.ShapeValues","text":"Poingr.ShapeValues{dim}(::ShapeFunction)\nPoingr.ShapeValues{dim, T}(::ShapeFunction)\n\nConstruct object storing value of ShapeFunction.\n\nExamples\n\njulia> sv = Poingr.ShapeValues{2}(QuadraticBSpline());\n\njulia> update!(sv, Grid(0:3, 0:3), Vec(1, 1));\n\njulia> sum(sv.N)\n1.0\n\njulia> sum(sv.∇N)\n2-element Vec{2, Float64}:\n 5.551115123125783e-17\n 5.551115123125783e-17\n\n\n\n\n\n","category":"method"},{"location":"shape_functions/#Poingr.BSpline","page":"Shape functions","title":"Poingr.BSpline","text":"BSpline{order}()\nLinearBSpline()\nQuadraticBSpline()\nCubicBSpline()\n\nCreate B-spline shape function.\n\nExamples\n\njulia> f = LinearBSpline()\nLinearBSpline()\n\njulia> Poingr.value(f, Vec(0.5, 0.5))\n0.25\n\n\n\n\n\n","category":"type"},{"location":"#Poingr","page":"Home","title":"Poingr","text":"","category":"section"}]
}
