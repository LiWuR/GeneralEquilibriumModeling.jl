# ================================================================
# commodity_space_v3.jl
#
# General structured-commodity infrastructure for GEMB.
#
# STEP 2 of the CommodityRef generalization makes CommoditySpace
# accept both simple Symbol commodities and structured CommoditySpec
# objects through one canonical internal representation.
#
# Public types:
#
#   CommoditySpec
#   CommodityRef
#   CommoditySpace
#
# This file intentionally contains no intertemporal semantics:
#
#   - no required :period axis;
#   - no positive-integer period rule;
#   - no RelativePeriod resolution;
#   - no agent construction;
#   - no equilibrium construction.
#
# Intertemporal code may extend CommodityRef validation and resolution
# without redefining CommodityRef itself.
# ================================================================


# ----------------------------------------------------------------
# 1. General commodity specification
# ----------------------------------------------------------------

"""
    CommoditySpec(
        name;
        axes=NamedTuple(),
        price_lower_bound=0.0,
        price_upper_bound=Inf,
    )

Describe one structured commodity group.

`axes` is a named tuple whose entries define zero or more indexing axes and
their allowed values. No particular axis name is required.

Axis values may be supplied as scalar labels or collections. Every axis is
materialized internally as a one-dimensional vector. Axis order is part of the
specification and determines canonical commodity expansion order.

Examples:

    CommoditySpec(:labor)

    CommoditySpec(
        :product;
        axes=(type=1:3,),
    )

    CommoditySpec(
        :product;
        axes=(
            region=[:east, :west],
            period=1:5,
        ),
    )
"""
struct CommoditySpec
    name::Symbol
    axes::NamedTuple
    price_lower_bound::Float64
    price_upper_bound::Float64
end


function _is_commodity_axis_scalar(raw_values)
    return raw_values isa Number ||
           raw_values isa Symbol ||
           raw_values isa AbstractString ||
           raw_values isa Char
end


function _materialize_commodity_axis(
    axis_name::Symbol,
    raw_values,
)
    values_vector = if _is_commodity_axis_scalar(raw_values)
        [raw_values]
    else
        try
            vec(collect(raw_values))
        catch err
            if err isa MethodError
                [raw_values]
            else
                rethrow()
            end
        end
    end

    isempty(values_vector) && throw(ArgumentError(
        "Axis $(axis_name) cannot be empty.",
    ))

    length(unique(values_vector)) == length(values_vector) ||
        throw(ArgumentError(
            "Axis $(axis_name) contains duplicate values.",
        ))

    return values_vector
end


function CommoditySpec(
    name::Symbol;
    axes::NamedTuple=NamedTuple(),
    price_lower_bound::Real=0.0,
    price_upper_bound::Real=Inf,
)
    lower = Float64(price_lower_bound)
    upper = Float64(price_upper_bound)

    isnan(lower) && throw(ArgumentError(
        "price_lower_bound cannot be NaN.",
    ))
    isnan(upper) && throw(ArgumentError(
        "price_upper_bound cannot be NaN.",
    ))
    lower < upper || throw(ArgumentError(
        "price_lower_bound must be strictly smaller than price_upper_bound.",
    ))

    axis_names = keys(axes)

    materialized_values = Tuple(
        _materialize_commodity_axis(
            axis_name,
            getproperty(axes, axis_name),
        )
        for axis_name in axis_names
    )

    materialized_axes =
        NamedTuple{axis_names}(materialized_values)

    return CommoditySpec(
        name,
        materialized_axes,
        lower,
        upper,
    )
end


# ----------------------------------------------------------------
# 2. General commodity reference
# ----------------------------------------------------------------

"""
    CommodityRef(name; selectors...)

Select one or more commodities from a structured commodity group.

Any omitted axis means "all values on that axis".

Examples:

    CommodityRef(:product; type=2, period=3)
    CommodityRef(:product; region=:east)
    CommodityRef(:product; type=1:3)
    CommodityRef(:product)

A selector may be a scalar, a range, a vector, a tuple, a set, or `Colon()`.

`CommodityRef` itself contains no intertemporal logic. The intertemporal layer
may extend selector validation for objects such as `RelativePeriod`.
"""
struct CommodityRef
    name::Symbol
    selectors::NamedTuple
end


# Extension hook. The general commodity layer accepts arbitrary scalar
# selector values. Specialized layers may add methods for specialized
# selector objects without redefining CommodityRef.
_validate_commodity_ref_selector(
    ::Symbol,
    selector,
) = nothing


function CommodityRef(
    name::Symbol;
    kwargs...,
)
    selectors = (; kwargs...)

    for (axis_name, selector) in pairs(selectors)
        _validate_commodity_ref_selector(
            axis_name,
            selector,
        )
    end

    return CommodityRef(
        name,
        selectors,
    )
end


# ----------------------------------------------------------------
# 3. CommoditySpace
# ----------------------------------------------------------------

"""
    CommoditySpace(specs)

Expand simple or structured commodity declarations into a canonical flat
commodity space.

Each entry in `specs` may be either:

- a `Symbol`, interpreted as `CommoditySpec(symbol)`;
- a `CommoditySpec`.

This keeps simple models concise while allowing simple and structured
commodities to share exactly the same indexing and resolution machinery.

The order of concrete commodities is deterministic:

1. commodity groups follow the order supplied in `specs`;
2. within each group, axes follow the order declared by `CommoditySpec.axes`;
3. earlier axes change more slowly.

Examples:

    CommoditySpace([:product, :labor])

    CommoditySpace([
        :labor,
        CommoditySpec(
            :product;
            axes=(type=1:3,),
        ),
    ])

`CommoditySpace` stores the flat commodity names required by GEM, structured
coordinates, structured-key to integer-index lookup, and expanded price bounds.
"""
struct CommoditySpace
    specs::Vector{CommoditySpec}
    spec_by_name::Dict{Symbol,CommoditySpec}
    commodity_names::Vector{Symbol}
    coordinates::Vector{NamedTuple}
    index_by_key::Dict{Tuple{Symbol,Tuple},Int}
    price_lower_bounds::Vector{Float64}
    price_upper_bounds::Vector{Float64}
end


function _commodity_space_axis_combinations(
    axes::NamedTuple,
)
    axis_names = keys(axes)
    axis_values = values(axes)

    combinations = NamedTuple[]
    current = Any[]

    function visit_axis(position::Int)
        if position > length(axis_names)
            push!(
                combinations,
                NamedTuple{axis_names}(Tuple(current)),
            )
            return
        end

        for value in axis_values[position]
            push!(current, value)
            visit_axis(position + 1)
            pop!(current)
        end
    end

    visit_axis(1)

    return combinations
end


function _commodity_space_flat_name(
    commodity_name::Symbol,
    coordinate::NamedTuple,
)
    isempty(coordinate) && return commodity_name

    parts = String[
        string(commodity_name),
    ]

    for value in values(coordinate)
        push!(
            parts,
            string(value),
        )
    end

    return Symbol(
        join(parts, "_"),
    )
end


function _commodity_space_key(
    commodity_name::Symbol,
    coordinate::NamedTuple,
)
    return (
        commodity_name,
        Tuple(values(coordinate)),
    )
end


function _normalize_commodity_spec(
    spec::CommoditySpec,
)
    return spec
end


function _normalize_commodity_spec(
    name::Symbol,
)
    return CommoditySpec(name)
end


function _normalize_commodity_spec(
    spec,
)
    throw(ArgumentError(
        "CommoditySpace entries must be Symbol or CommoditySpec; " *
        "received $(typeof(spec)).",
    ))
end


function CommoditySpace(
    specs::AbstractVector,
)
    isempty(specs) && throw(ArgumentError(
        "At least one commodity declaration is required.",
    ))

    spec_vector = CommoditySpec[
        _normalize_commodity_spec(spec)
        for spec in specs
    ]

    names = [
        spec.name
        for spec in spec_vector
    ]

    length(unique(names)) == length(names) || throw(ArgumentError(
        "CommoditySpec names must be unique.",
    ))

    spec_by_name = Dict(
        spec.name => spec
        for spec in spec_vector
    )

    commodity_names = Symbol[]
    coordinates = NamedTuple[]
    index_by_key = Dict{Tuple{Symbol,Tuple},Int}()
    price_lower_bounds = Float64[]
    price_upper_bounds = Float64[]

    next_index = 1

    for spec in spec_vector
        for coordinate in _commodity_space_axis_combinations(spec.axes)
            key = _commodity_space_key(
                spec.name,
                coordinate,
            )

            haskey(index_by_key, key) && throw(ArgumentError(
                "Duplicate structured commodity generated for $(spec.name).",
            ))

            flat_name = _commodity_space_flat_name(
                spec.name,
                coordinate,
            )

            flat_name in commodity_names && throw(ArgumentError(
                "Structured commodity expansion generated duplicate flat " *
                "commodity name $(repr(flat_name)).",
            ))

            push!(
                commodity_names,
                flat_name,
            )
            push!(
                coordinates,
                coordinate,
            )
            push!(
                price_lower_bounds,
                spec.price_lower_bound,
            )
            push!(
                price_upper_bounds,
                spec.price_upper_bound,
            )

            index_by_key[key] = next_index
            next_index += 1
        end
    end

    return CommoditySpace(
        spec_vector,
        spec_by_name,
        commodity_names,
        coordinates,
        index_by_key,
        price_lower_bounds,
        price_upper_bounds,
    )
end


# ----------------------------------------------------------------
# 4. Absolute CommodityRef resolution
# ----------------------------------------------------------------

function _commodity_space_selector_values(
    selector,
)
    if selector isa Colon
        return nothing
    elseif selector isa AbstractRange ||
           selector isa AbstractVector ||
           selector isa Tuple ||
           selector isa Set
        values_vector = collect(selector)

        isempty(values_vector) && throw(ArgumentError(
            "CommodityRef selectors cannot be empty.",
        ))

        length(unique(values_vector)) == length(values_vector) ||
            throw(ArgumentError(
                "CommodityRef selectors cannot contain duplicate values.",
            ))

        return values_vector
    else
        return [selector]
    end
end


function _commodity_space_resolve_axis_selection(
    axis_name::Symbol,
    axis_values,
    selector,
)
    selector isa Colon && return collect(axis_values)

    requested_values =
        _commodity_space_selector_values(
            selector,
        )

    requested_values === nothing &&
        return collect(axis_values)

    for requested in requested_values
        any(
            value -> isequal(value, requested),
            axis_values,
        ) || throw(ArgumentError(
            "Selector value $(requested) is not present on axis $(axis_name).",
        ))
    end

    # Canonical order follows CommoditySpec, not selector input order.
    return [
        value
        for value in axis_values
        if any(
            requested -> isequal(value, requested),
            requested_values,
        )
    ]
end


"""
    _resolve_commodity_ref(space::CommoditySpace, ref::CommodityRef)

Resolve one absolute `CommodityRef` to global integer commodity indices.

Omitted axes select all values. Returned indices follow the canonical order of
`CommoditySpace`.

This general resolver intentionally has no `base_period` keyword and does not
interpret `RelativePeriod`. Intertemporal relative references remain the
responsibility of the intertemporal layer.
"""
function _resolve_commodity_ref(
    space::CommoditySpace,
    ref::CommodityRef,
)
    haskey(
        space.spec_by_name,
        ref.name,
    ) || throw(ArgumentError(
        "Unknown commodity group: $(ref.name).",
    ))

    spec = space.spec_by_name[ref.name]
    axis_names = keys(spec.axes)
    selector_names = keys(ref.selectors)

    for selector_name in selector_names
        selector_name in axis_names || throw(ArgumentError(
            "Commodity $(ref.name) has no axis named $(selector_name).",
        ))
    end

    selected_axis_values = Any[]

    for axis_name in axis_names
        axis_values =
            getproperty(
                spec.axes,
                axis_name,
            )

        if axis_name in selector_names
            selector =
                getproperty(
                    ref.selectors,
                    axis_name,
                )

            push!(
                selected_axis_values,
                _commodity_space_resolve_axis_selection(
                    axis_name,
                    axis_values,
                    selector,
                ),
            )
        else
            push!(
                selected_axis_values,
                collect(axis_values),
            )
        end
    end

    selected_axes =
        NamedTuple{axis_names}(
            Tuple(selected_axis_values),
        )

    resolved = Int[]

    for coordinate in _commodity_space_axis_combinations(selected_axes)
        key = _commodity_space_key(
            ref.name,
            coordinate,
        )

        haskey(
            space.index_by_key,
            key,
        ) || throw(ArgumentError(
            "CommodityRef resolved to an undefined commodity.",
        ))

        push!(
            resolved,
            space.index_by_key[key],
        )
    end

    return resolved
end


function _resolve_commodity_refs(
    space::CommoditySpace,
    refs::AbstractVector{<:CommodityRef};
    allow_duplicates::Bool=false,
)
    resolved = Int[]

    for ref in refs
        append!(
            resolved,
            _resolve_commodity_ref(
                space,
                ref,
            ),
        )
    end

    if !allow_duplicates &&
       length(unique(resolved)) != length(resolved)
        throw(ArgumentError(
            "CommodityRef objects select overlapping commodities.",
        ))
    end

    return resolved
end
