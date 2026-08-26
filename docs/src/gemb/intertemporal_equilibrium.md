# Intertemporal equilibrium

GEMB does not use a separate intertemporal equilibrium model type. A finite-
horizon Arrow--Debreu economy is an ordinary [`GEMBModel`](@ref) whose
commodity space contains dated commodities.

The final high-level intertemporal API is:

- [`CommoditySpec`](@ref)
- [`CommodityRef`](@ref)
- [`CommoditySpace`](@ref)
- [`AgentRef`](@ref)
- [`GEMBModel`](@ref)
- [`add_agent!`](@ref)
- [`AgentTemplate`](@ref)
- [`add_agents!`](@ref)
- [`RelativePeriod`](@ref)
- [`ByPeriod`](@ref)
- [`build_model`](@ref)

There is no intertemporal-specific solver. After [`build_model`](@ref), use the
ordinary GEM equilibrium solver.

## 1. Dated commodities

Time is represented as an ordinary commodity axis.

```julia
product = CommoditySpec(
    :product;
    axes=(
        type=1:1,
        period=1:np,
    ),
)

labor = CommoditySpec(
    :labor;
    axes=(
        type=1:1,
        period=1:(np - 1),
    ),
)
```

A [`CommodityRef`](@ref) may identify one dated commodity:

```julia
CommodityRef(
    :product;
    type=1,
    period=2,
)
```

or a whole dated group by omitting an axis:

```julia
CommodityRef(
    :product;
    type=1,
)
```

The latter selects every period compatible with the declared commodity space.

## 2. One concrete agent: `add_agent!`

A concrete agent, including a concrete dated agent, is added with ordinary
[`add_agent!`](@ref).

```julia
add_agent!(
    model,
    CESSpec([1.0]);
    name=AgentRef(
        :firm;
        period=2,
    ),
    demands=[
        CommodityRef(
            :labor;
            period=RelativePeriod(0),
        ),
    ],
    outputs=[
        CommodityRef(
            :product;
            period=RelativePeriod(1),
        ),
    ],
)
```

Here the concrete agent period is 2, so the relative commodity references are
materialized as:

```text
labor,   RelativePeriod(0)  -> period 2
product, RelativePeriod(1)  -> period 3
```

A concrete agent does not need a special intertemporal wrapper.

An undated household that consumes an entire product path is also an ordinary
agent:

```julia
add_agent!(
    model,
    CESSpec(fill(1.0 / np, np));
    name=:household,
    demands=[
        CommodityRef(
            :product;
            type=1,
        ),
    ],
    endowments=[
        CommodityRef(
            :product;
            type=1,
            period=1,
        ),
        CommodityRef(
            :labor;
            type=1,
        ),
    ],
    endowment_quantities=vcat(
        [150.0],
        fill(100.0, np - 1),
    ),
)
```

## 3. Repeated agents: `AgentTemplate`

Use [`AgentTemplate`](@ref) only when one structural declaration should create
agents for several periods.

```julia
producer = AgentTemplate(
    :producer,
    CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=2.0,
    );
    periods=1:(np - 1),
    demands=[
        CommodityRef(
            :product;
            type=1,
            period=RelativePeriod(0),
        ),
        CommodityRef(
            :labor;
            type=1,
            period=RelativePeriod(0),
        ),
    ],
    outputs=[
        CommodityRef(
            :product;
            type=1,
            period=RelativePeriod(1),
        ),
    ],
)
```

Then expand the template directly into the model:

```julia
add_agents!(
    model,
    producer,
)
```

If `periods=1:3`, the base identity `:producer` produces:

```text
producer(period=1)
producer(period=2)
producer(period=3)
```

The base `AgentRef` of an [`AgentTemplate`](@ref) must not already contain a
`:period` selector. If there is only one concrete dated agent, use
[`add_agent!`](@ref).

## 4. `RelativePeriod`

[`RelativePeriod`](@ref) expresses a selector relative to the concrete agent
period.

```julia
RelativePeriod(-1)
RelativePeriod(0)
RelativePeriod(1)
```

It can be used in dated [`CommodityRef`](@ref) values and relative
[`AgentRef`](@ref) values.

For a concrete observer in period 3:

```julia
AgentRef(
    :firm;
    period=RelativePeriod(-1),
)
```

refers to `firm(period=2)` after contextual materialization.

`RelativePeriod` is allowed only on the `:period` axis.

## 5. `ByPeriod`

[`ByPeriod`](@ref) is for parameter values that vary across repeated template
instances.

A scalar remains constant:

```julia
claim_rate=0.10
```

A vector wrapped in `ByPeriod` follows template position:

```julia
claim_rate=ByPeriod([
    0.10,
    0.15,
    0.20,
])
```

For:

```julia
periods=[1, 3, 5]
```

the vector above means:

```text
period 1 -> 0.10
period 3 -> 0.15
period 5 -> 0.20
```

An explicit period mapping follows actual period labels:

```julia
claim_rate=ByPeriod(
    1 => 0.10,
    3 => 0.15,
    5 => 0.20,
)
```

A function provider is also supported:

```julia
claim_rate=ByPeriod(
    t -> tax_rate[t],
)
```

A plain vector is never silently interpreted as a period-varying parameter.
This avoids ambiguity with ordinary vector-valued behavior options.

## 6. Period-varying endowments

`ByPeriod` can also be used for template endowment quantities.

```julia
producer_owner = AgentTemplate(
    :owner,
    CESSpec([1.0]);
    periods=1:3,
    demands=[
        CommodityRef(
            :product;
            period=RelativePeriod(0),
        ),
    ],
    endowments=[
        CommodityRef(
            :labor;
            period=RelativePeriod(0),
        ) => ByPeriod([
            100.0,
            105.0,
            110.0,
        ]),
    ],
)
```

For each template instance, the `ByPeriod` value is materialized first. The
resulting scalar or vector is then processed by the ordinary endowment
expansion rules.

## 7. Dated claims

The examples below use `type=:tax` to label one tax application of the claim
mechanism. This selector is application-specific: an ad valorem claim is the
more general proportional right to an economic value base and is not limited to taxation.


A claim is an ordinary commodity. Its claim role comes from the `claim`
binding and the behavior modifier option such as `claim_rate`.

```julia
claim = CommoditySpec(
    :claim;
    axes=(
        type=[:tax],
        period=1:(np - 1),
    ),
    price_lower_bound=1.0e-10,
)
```

A repeated taxed producer can bind the current dated claim:

```julia
producer = AgentTemplate(
    :producer,
    CESSpec([0.5, 0.5]);
    periods=1:(np - 1),
    demands=[
        CommodityRef(
            :product;
            period=RelativePeriod(0),
        ),
        CommodityRef(
            :labor;
            period=RelativePeriod(0),
        ),
    ],
    outputs=[
        CommodityRef(
            :product;
            period=RelativePeriod(1),
        ),
    ],
    claim=CommodityRef(
        :claim;
        type=:tax,
        period=RelativePeriod(0),
    ),
    claim_rate=ByPeriod([
        0.10,
        0.12,
        0.15,
    ]),
)
```

The claim owner is normally one concrete intertemporal agent and therefore uses
ordinary [`add_agent!`](@ref), not a template.

## 8. Full construction workflow

The model container is created before agents are added:

```julia
model = GEMBModel(
    [
        product,
        labor,
        claim,
    ];
    numeraire=CommodityRef(
        :product;
        type=1,
        period=1,
    ),
)
```

Repeated structures are expanded:

```julia
add_agents!(
    model,
    producer,
)
```

Concrete agents are added normally:

```julia
add_agent!(
    model,
    household_spec;
    name=:household,
    demands=...,
    endowments=...,
    endowment_quantities=...,
)
```

Finally:

```julia
gem_model =
    build_model(
        model,
    )
```

and solve with the standard GEM solver.

## 9. Conceptual boundary

The final architecture is:

```text
CommoditySpec / CommodityRef
          |
    CommoditySpace
          |
      GEMBModel
       /     \
 add_agent!  AgentTemplate
               |
           add_agents!
               |
           add_agent!
               |
          build_model
               |
              GEM
```

The important distinction is structural rather than behavioral:

- [`add_agent!`](@ref): add one concrete agent;
- [`AgentTemplate`](@ref) + [`add_agents!`](@ref): repeat one structural
  declaration across periods;
- [`RelativePeriod`](@ref): vary a reference relative to the concrete period;
- [`ByPeriod`](@ref): vary a parameter value across template periods.

The behavior specification itself remains an ordinary GEMB behavior object such
as `CESSpec`, `CESMarginalUtilitySpec`, `PowerProductionSpec`, or another
supported specification.
