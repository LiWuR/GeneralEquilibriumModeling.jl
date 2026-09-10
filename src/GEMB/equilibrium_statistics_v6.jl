# ================================================================
# equilibrium_statistics_v6.jl
#
# GEMB equilibrium-statistics layer.
#
# V6 provides:
#
#   net_supply_matrix
#   net_supply_value_matrix
#   agent_net_supply_values
#   equilibrium_statistics
#   print_equilibrium_statistics
#
# This remains a pure post-solve statistics layer:
#   - GEM is not modified.
#   - GEMBModel is not modified.
#   - solve(::GEMBModel) is not modified.
#   - no agent behavior is re-evaluated.
#
# Matrix convention:
#
#   rows    -> model commodities, in model.commodity_names order
#   columns -> model agents, in model.agents order
#
# Positive entries denote net supply and negative entries denote net demand.
# ================================================================


const _EQUILIBRIUM_STATISTICS_ATOL = 1.0e-10
const _EQUILIBRIUM_STATISTICS_RTOL = 1.0e-8


function _check_net_supply_matrix_consistency(
    N::AbstractMatrix,
    result::GEM.EquilibriumResult;
    atol::Real=_EQUILIBRIUM_STATISTICS_ATOL,
    rtol::Real=_EQUILIBRIUM_STATISTICS_RTOL,
)
    hasproperty(
        result,
        :total_net_supply,
    ) || return nothing

    total_net_supply =
        result.total_net_supply

    length(total_net_supply) == size(N, 1) || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(total_net_supply)) " *
            "total-net-supply values, but the net-supply matrix has " *
            "$(size(N, 1)) commodity rows.",
        ),
    )

    matrix_total =
        vec(
            sum(
                N;
                dims=2,
            ),
        )

    isapprox(
        matrix_total,
        total_net_supply;
        atol=atol,
        rtol=rtol,
    ) || throw(
        ArgumentError(
            "Net-supply matrix is inconsistent with result.total_net_supply. " *
            "The matrix column sum is $(matrix_total), while the stored total " *
            "net supply is $(total_net_supply).",
        ),
    )

    return nothing
end


"""
    net_supply_matrix(model::GEMBModel, result::GEM.EquilibriumResult)

Construct the global commodity-by-agent net-supply matrix from an existing
GEM equilibrium result.

Rows follow `model.commodity_names`; columns follow `model.agents`.
For agent `j`, the local vector `result.agent_net_supplies[j]` is scattered
to the corresponding global commodity rows using
`GEM.agent_commodity_indices(model.agents[j])`.

Positive entries denote net supply and negative entries denote net demand.

No agent behavior is re-evaluated. The function only reorganizes net-supply
values already stored in `result`.

If `result.total_net_supply` is available, the function also verifies that
the row-wise sum across agents reproduces that stored total within numerical
tolerance.
"""
function net_supply_matrix(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    agent_net_supplies =
        result.agent_net_supplies

    n_commodities =
        length(
            model.commodity_names,
        )

    n_agents =
        length(
            model.agents,
        )

    length(agent_net_supplies) == n_agents || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(agent_net_supplies)) " *
            "agent net-supply vectors, but GEMBModel contains " *
            "$(n_agents) agents.",
        ),
    )

    T =
        isempty(agent_net_supplies) ?
        Float64 :
        promote_type(
            (
                eltype(local_net_supply)
                for local_net_supply in agent_net_supplies
            )...,
        )

    N =
        zeros(
            T,
            n_commodities,
            n_agents,
        )

    for j in eachindex(model.agents)
        commodity_indices =
            GEM.agent_commodity_indices(
                model.agents[j],
            )

        local_net_supply =
            agent_net_supplies[j]

        length(commodity_indices) == length(local_net_supply) || throw(
            DimensionMismatch(
                "Agent $(repr(model.agent_refs[j])) uses " *
                "$(length(commodity_indices)) commodity indices, but its " *
                "equilibrium net-supply vector has length " *
                "$(length(local_net_supply)).",
            ),
        )

        for k in eachindex(commodity_indices)
            commodity_index =
                commodity_indices[k]

            1 <= commodity_index <= n_commodities || throw(
                BoundsError(
                    model.commodity_names,
                    commodity_index,
                ),
            )

            N[
                commodity_index,
                j,
            ] =
                local_net_supply[k]
        end
    end

    _check_net_supply_matrix_consistency(
        N,
        result,
    )

    return N
end


"""
    net_supply_value_matrix(model::GEMBModel, result::GEM.EquilibriumResult)

Return the commodity-by-agent net-supply value matrix

    diag(result.prices) * net_supply_matrix(model, result)

without explicitly constructing a diagonal matrix.

Rows follow `model.commodity_names`; columns follow `model.agents`.
A positive entry is the value of an agent's net supply of a commodity;
a negative entry is the value of its net demand.
"""
function net_supply_value_matrix(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    N =
        net_supply_matrix(
            model,
            result,
        )

    prices =
        result.prices

    length(prices) == size(N, 1) || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(prices)) prices, but the " *
            "net-supply matrix has $(size(N, 1)) commodity rows.",
        ),
    )

    return reshape(
        prices,
        :,
        1,
    ) .* N
end


"""
    agent_net_supply_values(model::GEMBModel, result::GEM.EquilibriumResult)

Return the vector of total net-supply values by agent.

For agent `j`, the returned value is

    sum_i p[i] * N[i, j]

where `N = net_supply_matrix(model, result)`.

The vector order is identical to `model.agents` and `model.agent_refs`.
"""
function agent_net_supply_values(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    VN =
        net_supply_value_matrix(
            model,
            result,
        )

    return vec(
        sum(
            VN;
            dims=1,
        ),
    )
end



# ----------------------------------------------------------------
# Activity levels
# ----------------------------------------------------------------

function _is_activity_level_variable_name(
    name::Symbol,
)
    name === :utility &&
        return true

    name === :activity &&
        return true

    return startswith(
        String(name),
        "activity_",
    )
end


function _activity_levels(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    hasproperty(
        result,
        :agent_variable_names,
    ) || return (
        activity_levels=Float64[],
        activity_level_refs=AgentRef[],
    )

    hasproperty(
        result,
        :agent_variable_values,
    ) || return (
        activity_levels=Float64[],
        activity_level_refs=AgentRef[],
    )

    variable_names =
        result.agent_variable_names

    variable_values =
        result.agent_variable_values

    n_agents =
        length(
            model.agents,
        )

    length(variable_names) == n_agents || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(variable_names)) " *
            "agent-variable-name vectors, but GEMBModel contains " *
            "$(n_agents) agents.",
        ),
    )

    length(variable_values) == n_agents || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(variable_values)) " *
            "agent-variable-value vectors, but GEMBModel contains " *
            "$(n_agents) agents.",
        ),
    )

    raw_levels =
        Any[]

    refs =
        AgentRef[]

    for j in eachindex(model.agents)
        names_j =
            variable_names[j]

        values_j =
            variable_values[j]

        length(names_j) == length(values_j) || throw(
            DimensionMismatch(
                "Agent $(repr(model.agent_refs[j])) has " *
                "$(length(names_j)) variable names but " *
                "$(length(values_j)) equilibrium variable values.",
            ),
        )

        for k in eachindex(names_j)
            name =
                names_j[k]

            name isa Symbol || throw(
                ArgumentError(
                    "Agent variable names must be Symbols; got " *
                    "$(typeof(name)) for agent $(repr(model.agent_refs[j])).",
                ),
            )

            _is_activity_level_variable_name(
                name,
            ) || continue

            value =
                values_j[k]

            value isa Real || throw(
                ArgumentError(
                    "Activity level values must be real numbers; got " *
                    "$(typeof(value)) for agent $(repr(model.agent_refs[j])).",
                ),
            )

            push!(
                raw_levels,
                value,
            )

            push!(
                refs,
                model.agent_refs[j],
            )
        end
    end

    levels =
        if isempty(raw_levels)
            Float64[]
        else
            T =
                promote_type(
                    (
                        typeof(value)
                        for value in raw_levels
                    )...,
                )

            T[
                convert(
                    T,
                    value,
                )
                for value in raw_levels
            ]
        end

    return (
        activity_levels=levels,
        activity_level_refs=refs,
    )
end


"""
    equilibrium_statistics(model::GEMBModel, result::GEM.EquilibriumResult)

Collect the current GEMB equilibrium statistics into one named tuple.

The returned fields are:

- `prices`
- `activity_levels`
- `activity_level_refs`
- `net_supply_matrix`
- `net_supply_value_matrix`
- `total_net_supply`
- `agent_net_supply_values`
- `commodity_names`
- `agent_refs`

The function does not solve or re-evaluate the model. It only reorganizes
the already computed equilibrium result.

`activity_levels` contains all explicitly represented activity levels, flattened
first by agent order and then by each agent's existing variable order. The
economic interpretation of an activity level depends on the representation of
the agent; for example, it may represent a production activity level or a
consumer's utility level. `activity_level_refs` has the same length and identifies the
GEMB agent that owns each level. A multi-activity agent therefore appears
multiple times in `activity_level_refs`.

The statistics layer recognizes the standard GEMB activity-level variable names
`:activity`, `:activity_*`, and `:utility`. Other endogenous variables such as
input quantities, multipliers, claim quantities, or custom auxiliary
variables are not included.

Future versions may extend this named tuple with additional high-level
economic statistics such as demand matrices or supply matrices.
"""
function equilibrium_statistics(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    N =
        net_supply_matrix(
            model,
            result,
        )

    prices =
        result.prices

    length(prices) == size(N, 1) || throw(
        DimensionMismatch(
            "Equilibrium result contains $(length(prices)) prices, but the " *
            "net-supply matrix has $(size(N, 1)) commodity rows.",
        ),
    )

    activity_data =
        _activity_levels(
            model,
            result,
        )

    VN =
        reshape(
            prices,
            :,
            1,
        ) .* N

    matrix_total =
        vec(
            sum(
                N;
                dims=2,
            ),
        )

    values =
        vec(
            sum(
                VN;
                dims=1,
            ),
        )

    return (
        prices =
            copy(prices),

        activity_levels =
            activity_data.activity_levels,

        activity_level_refs =
            activity_data.activity_level_refs,

        net_supply_matrix =
            N,

        net_supply_value_matrix =
            VN,

        total_net_supply =
            matrix_total,

        agent_net_supply_values =
            values,

        commodity_names =
            copy(model.commodity_names),

        agent_refs =
            copy(model.agent_refs),
    )
end

# ----------------------------------------------------------------
# Equilibrium-statistics display
# ----------------------------------------------------------------

function _check_statistics_display_arguments(
    display_tol::Real,
    sigdigits::Integer,
)
    isfinite(display_tol) && display_tol >= 0 || throw(
        ArgumentError(
            "display_tol must be finite and nonnegative.",
        ),
    )

    sigdigits >= 1 || throw(
        ArgumentError(
            "sigdigits must be at least 1.",
        ),
    )

    return nothing
end


function _statistics_number_string(
    value::Real;
    display_tol::Real,
    sigdigits::Integer,
)
    if value isa AbstractFloat && !isfinite(value)
        return string(value)
    end

    displayed =
        abs(value) <= display_tol ?
        zero(value) :
        value

    iszero(displayed) &&
        return "0"

    return string(
        round(
            displayed;
            sigdigits=sigdigits,
        ),
    )
end


function _statistics_agent_label(
    ref::AgentRef,
)
    isempty(ref.selectors) &&
        return String(ref.name)

    selector_names =
        keys(
            ref.selectors,
        )

    selector_parts =
        [
            string(
                selector_name,
                "=",
                getproperty(
                    ref.selectors,
                    selector_name,
                ),
            )
            for selector_name in selector_names
        ]

    return string(
        ref.name,
        "(",
        join(
            selector_parts,
            ", ",
        ),
        ")",
    )
end


function _print_statistics_vector(
    io::IO,
    title::AbstractString,
    labels,
    values;
    display_tol::Real,
    sigdigits::Integer,
)
    println(
        io,
        title,
    )

    println(
        io,
        repeat(
            "-",
            max(
                3,
                length(title),
            ),
        ),
    )

    label_strings =
        String.(
            labels,
        )

    value_strings =
        [
            _statistics_number_string(
                value;
                display_tol=display_tol,
                sigdigits=sigdigits,
            )
            for value in values
        ]

    label_width =
        isempty(label_strings) ?
        0 :
        maximum(
            length,
            label_strings,
        )

    for i in eachindex(label_strings)
        print(
            io,
            rpad(
                label_strings[i],
                label_width,
            ),
        )

        print(
            io,
            "  ",
        )

        println(
            io,
            value_strings[i],
        )
    end

    println(io)

    return nothing
end


function _print_statistics_matrix(
    io::IO,
    title::AbstractString,
    row_labels,
    column_labels,
    values::AbstractMatrix;
    display_tol::Real,
    sigdigits::Integer,
)
    size(values, 1) == length(row_labels) || throw(
        DimensionMismatch(
            "Matrix row count does not match row-label count.",
        ),
    )

    size(values, 2) == length(column_labels) || throw(
        DimensionMismatch(
            "Matrix column count does not match column-label count.",
        ),
    )

    println(
        io,
        title,
    )

    println(
        io,
        repeat(
            "-",
            max(
                3,
                length(title),
            ),
        ),
    )

    row_strings =
        String.(
            row_labels,
        )

    column_strings =
        String.(
            column_labels,
        )

    value_strings =
        [
            _statistics_number_string(
                values[i, j];
                display_tol=display_tol,
                sigdigits=sigdigits,
            )
            for i in axes(values, 1),
                j in axes(values, 2)
        ]

    row_width =
        isempty(row_strings) ?
        0 :
        maximum(
            length,
            row_strings,
        )

    column_widths =
        [
            max(
                length(
                    column_strings[j],
                ),
                isempty(row_strings) ?
                0 :
                maximum(
                    length(
                        value_strings[i, j],
                    )
                    for i in axes(values, 1)
                ),
            )
            for j in axes(values, 2)
        ]

    print(
        io,
        rpad(
            "",
            row_width,
        ),
    )

    for j in eachindex(column_strings)
        print(
            io,
            "  ",
            lpad(
                column_strings[j],
                column_widths[j],
            ),
        )
    end

    println(io)

    for i in eachindex(row_strings)
        print(
            io,
            rpad(
                row_strings[i],
                row_width,
            ),
        )

        for j in eachindex(column_strings)
            print(
                io,
                "  ",
                lpad(
                    value_strings[i, j],
                    column_widths[j],
                ),
            )
        end

        println(io)
    end

    println(io)

    return nothing
end


"""
    print_equilibrium_statistics(
        [io::IO],
        model::GEMBModel,
        result::GEM.EquilibriumResult;
        display_tol=1.0e-10,
        sigdigits=8,
        show_matrices=true,
    )

Print the current GEMB equilibrium statistics.

The display includes:

- equilibrium prices;
- activity levels; and, when `show_matrices=true`,
- the commodity-by-agent net-supply matrix, with total net supply by
  commodity in a rightmost `Sum` column; and
- the commodity-by-agent net-supply value matrix, with total net-supply
  value by commodity in a rightmost `Sum` column and total net-supply
  value by agent in a bottom `Sum` row.

Rows of the two matrices follow `model.commodity_names`; ordinary columns
follow `model.agent_refs`. The added `Sum` row and column are display-only
summaries and do not change the statistics returned by
`equilibrium_statistics`.

Set `show_matrices=false` to suppress both matrix displays. The matrices
remain available in the statistics returned by `equilibrium_statistics`.

Values whose absolute magnitude does not exceed `display_tol` are displayed
as zero. This affects display only; the stored equilibrium result and the
statistics returned by `equilibrium_statistics` are not modified.
"""
function print_equilibrium_statistics(
    io::IO,
    model::GEMBModel,
    result::GEM.EquilibriumResult;
    display_tol::Real=1.0e-10,
    sigdigits::Integer=8,
    show_matrices::Bool=true,
)
    _check_statistics_display_arguments(
        display_tol,
        sigdigits,
    )

    stats =
        equilibrium_statistics(
            model,
            result,
        )

    commodity_labels =
        String.(
            stats.commodity_names,
        )

    agent_labels =
        [
            _statistics_agent_label(
                ref,
            )
            for ref in stats.agent_refs
        ]

    println(
        io,
        "========== GEMB Equilibrium Statistics ==========",
    )

    println(io)

    _print_statistics_vector(
        io,
        "Prices",
        commodity_labels,
        stats.prices;
        display_tol=display_tol,
        sigdigits=sigdigits,
    )

    activity_agent_labels =
        [
            _statistics_agent_label(
                ref,
            )
            for ref in stats.activity_level_refs
        ]

    _print_statistics_vector(
        io,
        "Activity levels",
        activity_agent_labels,
        stats.activity_levels;
        display_tol=display_tol,
        sigdigits=sigdigits,
    )

    if show_matrices
        sum_column_label =
            "Sum"

        net_supply_display =
            hcat(
                stats.net_supply_matrix,
                stats.total_net_supply,
            )

        net_supply_column_labels =
            vcat(
                agent_labels,
                sum_column_label,
            )

        _print_statistics_matrix(
            io,
            "Net supply matrix",
            commodity_labels,
            net_supply_column_labels,
            net_supply_display;
            display_tol=display_tol,
            sigdigits=sigdigits,
        )

        commodity_net_supply_values =
            stats.prices .* stats.total_net_supply

        grand_net_supply_value =
            sum(
                stats.agent_net_supply_values,
            )

        net_supply_value_display =
            vcat(
                hcat(
                    stats.net_supply_value_matrix,
                    commodity_net_supply_values,
                ),
                reshape(
                    vcat(
                        stats.agent_net_supply_values,
                        grand_net_supply_value,
                    ),
                    1,
                    :,
                ),
            )

        net_supply_value_row_labels =
            vcat(
                commodity_labels,
                "Sum",
            )

        net_supply_value_column_labels =
            vcat(
                agent_labels,
                sum_column_label,
            )

        _print_statistics_matrix(
            io,
            "Net supply value matrix",
            net_supply_value_row_labels,
            net_supply_value_column_labels,
            net_supply_value_display;
            display_tol=display_tol,
            sigdigits=sigdigits,
        )

    end

    println(
        io,
        "=================================================",
    )

    return nothing
end


function print_equilibrium_statistics(
    model::GEMBModel,
    result::GEM.EquilibriumResult;
    kwargs...,
)
    return print_equilibrium_statistics(
        stdout,
        model,
        result;
        kwargs...,
    )
end
