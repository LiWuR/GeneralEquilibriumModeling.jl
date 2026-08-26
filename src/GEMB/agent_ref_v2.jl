# ================================================================
# agent_ref_v2.jl
#
# General structured agent identity for GEMB.
#
# STEP 4 foundation adds a deferred high-level agent-variable reference.
#
# AgentRef still identifies one concrete economic agent. It is not a
# multi-agent selector.
#
# The public helper
#
#     agent_variable_ref(agent, variable_name)
#
# stores an AgentRef target without forcing immediate model lookup. GEMBModel
# later materializes it as GEM.AgentVariableRef after any relative selector
# context has been resolved. This preserves forward references.
# ================================================================


# ----------------------------------------------------------------
# 1. Selector normalization and validation
# ----------------------------------------------------------------

function _validate_agent_ref_selector_value(
    axis_name::Symbol,
    value,
)
    if value isa Colon ||
       value isa AbstractArray ||
       value isa AbstractRange ||
       value isa Tuple ||
       value isa NamedTuple ||
       value isa AbstractSet ||
       value isa AbstractDict ||
       value isa Pair
        throw(ArgumentError(
            "AgentRef selector $(axis_name) must identify exactly one " *
            "agent coordinate; collection-valued selectors are not allowed.",
        ))
    end

    supported =
        value isa Symbol ||
        value isa AbstractString ||
        value isa Integer ||
        value isa AbstractFloat ||
        value isa Char

    supported || throw(ArgumentError(
        "AgentRef selector $(axis_name) must be an absolute scalar label " *
        "of type Symbol, AbstractString, Integer, AbstractFloat, or Char; " *
        "received $(typeof(value)).",
    ))

    if value isa AbstractFloat
        isfinite(value) || throw(ArgumentError(
            "AgentRef selector $(axis_name) must be finite.",
        ))
    end

    return nothing
end


function _canonical_agent_ref_selectors(
    selectors::NamedTuple,
)
    selector_names =
        collect(
            keys(selectors),
        )

    sort!(
        selector_names;
        by=String,
    )

    canonical_names =
        Tuple(selector_names)

    canonical_values =
        Tuple(
            begin
                value =
                    getproperty(
                        selectors,
                        selector_name,
                    )

                _validate_agent_ref_selector_value(
                    selector_name,
                    value,
                )

                value
            end
            for selector_name in selector_names
        )

    return NamedTuple{canonical_names}(
        canonical_values,
    )
end


# ----------------------------------------------------------------
# 2. AgentRef
# ----------------------------------------------------------------

"""
    AgentRef(name; selectors...)

Identify one concrete economic agent by a base name and zero or more
structured coordinates.

Examples:

    AgentRef(:firm)

    AgentRef(
        :firm;
        period=3,
    )

    AgentRef(
        :firm;
        region=:east,
        period=3,
    )

`AgentRef` represents one identity, not a set of agents. Therefore selector
values must be scalar labels. Ranges, vectors, tuples, sets, dictionaries,
pairs, and `Colon()` are rejected.

Selector order is not part of identity. Selectors are stored in canonical
alphabetical order by axis name, so these are equal:

    AgentRef(:firm; region=:east, period=3)
    AgentRef(:firm; period=3, region=:east)

`AgentRef` itself contains no intertemporal semantics. Relative-period
behavior is added later by the intertemporal layer.
"""
struct AgentRef
    name::Symbol
    selectors::NamedTuple

    function AgentRef(
        name::Symbol,
        selectors::NamedTuple,
    )
        isempty(
            String(name),
        ) && throw(ArgumentError(
            "AgentRef name cannot be empty.",
        ))

        canonical =
            _canonical_agent_ref_selectors(
                selectors,
            )

        return new(
            name,
            canonical,
        )
    end
end


function AgentRef(
    name::Symbol;
    kwargs...,
)
    return AgentRef(
        name,
        (; kwargs...),
    )
end


function Base.show(
    io::IO,
    ref::AgentRef,
)
    print(
        io,
        "AgentRef(",
        repr(ref.name),
    )

    for (
        selector_name,
        value,
    ) in pairs(ref.selectors)
        print(
            io,
            "; ",
            selector_name,
            "=",
            repr(value),
        )
    end

    print(
        io,
        ")",
    )
end


# ----------------------------------------------------------------
# 3. Canonical identity key
# ----------------------------------------------------------------

"""
    _agent_ref_key(ref)

Return the canonical structural identity key used by future GEMBModel agent
registration.

The key is internal. `AgentRef` remains the authoritative public identity.
"""
function _agent_ref_key(
    ref::AgentRef,
)
    return (
        ref.name,
        ref.selectors,
    )
end


# ----------------------------------------------------------------
# 4. Flat GEM agent-name encoding
# ----------------------------------------------------------------

function _escape_agent_ref_component(
    value::AbstractString,
)
    # Escape the separators used by the flat-name encoding. This encoding is
    # deterministic and human-readable, but it is intentionally treated as an
    # implementation detail rather than the authoritative identity.
    escaped =
        replace(
            value,
            "%" => "%25",
        )

    escaped =
        replace(
            escaped,
            "_" => "%5F",
        )

    return escaped
end


function _agent_ref_value_token(
    value::Symbol,
)
    return "s_" *
           _escape_agent_ref_component(
               String(value),
           )
end


function _agent_ref_value_token(
    value::AbstractString,
)
    return "q_" *
           _escape_agent_ref_component(
               String(value),
           )
end


function _agent_ref_value_token(
    value::Bool,
)
    return value ?
           "b_true" :
           "b_false"
end


function _agent_ref_value_token(
    value::Integer,
)
    return "i_" *
           string(value)
end


function _agent_ref_value_token(
    value::AbstractFloat,
)
    isfinite(value) || throw(ArgumentError(
        "Cannot encode a non-finite AgentRef selector value.",
    ))

    return "f_" *
           string(value)
end


function _agent_ref_value_token(
    value::Char,
)
    return "c_" *
           string(
               Int(value),
           )
end


"""
    _flat_agent_name(ref::AgentRef)

Encode an absolute `AgentRef` as a deterministic flat `Symbol` suitable for
the existing GEM `name::Symbol` interface.

Examples:

    AgentRef(:firm)
        -> :firm

    AgentRef(:firm; period=3)
        -> :firm__period_i_3

The flat name is an implementation detail. Future GEMBModel integration will
retain an explicit `AgentRef` to flat-name mapping, so user code should rely
on `AgentRef`, not parse the generated `Symbol`.
"""
function _flat_agent_name(
    ref::AgentRef,
)
    isempty(
        ref.selectors,
    ) && return ref.name

    parts =
        String[
            String(ref.name),
        ]

    for (
        selector_name,
        value,
    ) in pairs(ref.selectors)
        axis_token =
            _escape_agent_ref_component(
                String(selector_name),
            )

        value_token =
            _agent_ref_value_token(
                value,
            )

        push!(
            parts,
            axis_token *
            "_" *
            value_token,
        )
    end

    return Symbol(
        join(
            parts,
            "__",
        ),
    )
end

# ----------------------------------------------------------------
# 5. Deferred high-level agent-variable reference
# ----------------------------------------------------------------

"""
    agent_variable_ref(agent, variable_name)

Create a high-level reference to one variable owned by an economic agent.

`agent` may be either a `Symbol` or an `AgentRef`.

Unlike `GEM.AgentVariableRef`, this high-level reference retains the structured
`AgentRef` identity until GEMB has enough context to materialize the final flat
GEM agent name. This is especially important for intertemporal references such
as

    agent_variable_ref(
        AgentRef(
            :firm;
            period=RelativePeriod(-1),
        ),
        :activity,
    )

The returned object is intentionally deferred: target-agent existence is not
checked at construction time, so forward references remain possible.
"""
struct _StructuredAgentVariableRef
    agent::AgentRef
    variable_name::Symbol

    function _StructuredAgentVariableRef(
        agent::AgentRef,
        variable_name::Symbol,
    )
        isempty(
            String(variable_name),
        ) && throw(ArgumentError(
            "Agent variable name cannot be empty.",
        ))

        return new(
            agent,
            variable_name,
        )
    end
end


function agent_variable_ref(
    agent::AgentRef,
    variable_name::Symbol,
)
    return _StructuredAgentVariableRef(
        agent,
        variable_name,
    )
end


function agent_variable_ref(
    agent::Symbol,
    variable_name::Symbol,
)
    return agent_variable_ref(
        AgentRef(agent),
        variable_name,
    )
end


function Base.show(
    io::IO,
    ref::_StructuredAgentVariableRef,
)
    print(
        io,
        "agent_variable_ref(",
        repr(ref.agent),
        ", ",
        repr(ref.variable_name),
        ")",
    )
end


# ----------------------------------------------------------------
# 6. Contextual AgentRef materialization hook
# ----------------------------------------------------------------

"""
    _materialize_agent_selector_value(axis_name, value, observer_ref)

Materialize one target-AgentRef selector value in the context of the observing
agent.

The general GEMB layer leaves ordinary absolute scalar labels unchanged.
Intertemporal extensions add a more-specific method for `RelativePeriod`.
"""
function _materialize_agent_selector_value(
    axis_name::Symbol,
    value,
    observer_ref::AgentRef,
)
    return value
end


"""
    _materialize_agent_ref(observer_ref, target_ref)

Convert a possibly context-dependent target AgentRef into an absolute AgentRef.

The general layer is identity-preserving for ordinary scalar selectors.
Context-specific selector types, such as RelativePeriod, are handled through
multiple dispatch in extension files.
"""
function _materialize_agent_ref(
    observer_ref::AgentRef,
    target_ref::AgentRef,
)
    selector_names =
        keys(
            target_ref.selectors,
        )

    isempty(selector_names) &&
        return target_ref

    values =
        Tuple(
            _materialize_agent_selector_value(
                selector_name,
                getproperty(
                    target_ref.selectors,
                    selector_name,
                ),
                observer_ref,
            )
            for selector_name in selector_names
        )

    selectors =
        NamedTuple{selector_names}(
            values,
        )

    return AgentRef(
        target_ref.name;
        selectors...,
    )
end


export agent_variable_ref

