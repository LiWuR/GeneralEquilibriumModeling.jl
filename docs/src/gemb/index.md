```@meta
CurrentModule = GEMB
```

# GEMB

GEMB is the high-level model-building submodule of
`GeneralEquilibriumModeling.jl`. It provides convenient behavioral
specifications for consumers, producers, demand systems, production
technologies, and ad valorem claims, and translates these specifications into
the net-supply agents and complementarity conditions used by `GEM`.

GEMB is designed for routine economic modeling in which users prefer to specify
economic behavior directly rather than manually construct net-supply functions
and complementarity conditions. It uses the `GEM` submodule as its underlying
equilibrium engine, so models constructed with GEMB are ultimately assembled
as GEM equilibrium models and solved through the same JuMP/PATH
complementarity framework.

GEMB supports CES and displaced-CES demand systems, activity-demand
specifications, marginal-utility consumers, Marshallian-demand consumers, and
production-function-based agents. The same activity-demand framework can be
used for producers and consumers: a producer's activity variable represents
production scale, while a consumer's activity variable may represent utility
when compensated demand is available. Generic demand modifiers can also be
attached to agents, including ad valorem claims that represent proportional rights to economic value bases.

## Main features

- High-level `build_agent` interface for constructing GEM equilibrium agents
- Built-in CES and displaced-CES specifications through [`CESSpec`](@ref) and
  [`DCESSpec`](@ref)
- Generic activity-demand models through [`ActivityDemandSpec`](@ref)
- Condition-only agents for endogenous policy variables, closure variables, and explicit equilibrium conditions
- Consumers specified by marginal utility or Marshallian demand
- High-level pure asset-exchange equilibrium solver for additive
  mean-standard-deviation (AMSD) preferences
- Production-function specifications with automatic equilibrium conditions
- Automatic producer condition rules with user-overridable `UnitRevenueExpenditureBalanceConditions`, `TotalRevenueExpenditureBalanceConditions`, and explicit conditions
- Utility-activity consumers with automatic expenditure-income conditions
- General ad valorem claims for proportional rights to economic value bases
- Intertemporal equilibrium specifications for dated commodities, generic intertemporal agents, optional temporal repetition, and dated claims
- Support for joint production and multiple output commodities
- Direct access to GEM's equilibrium models, price bounds, auxiliary variables,
  and MCP solver when additional control is required
- Structured equilibrium results and diagnostics inherited from GEM
- Post-solve [equilibrium statistics](equilibrium_statistics.md) for activity levels, net supplies, and value statistics

## Basic workflow

A GEMB model is typically constructed and solved in four steps:

1. Choose an economic specification such as `CESSpec`, `DCESSpec`,
   `ActivityDemandSpec`, a marginal-utility specification, or a production
   specification.
2. Convert each specification into an equilibrium agent with `build_agent`,
   supplying commodity indices, endowments, outputs, claims, and other
   model-specific information.
3. Assemble the agents and commodities into a GEM `EquilibriumModel`.
4. Solve the resulting mixed complementarity problem and inspect equilibrium
   prices, activity levels, utility levels, net supplies, market residuals, and
   solver diagnostics.

For intertemporal models, GEMB provides a structural layer that is independent
of producer/consumer categories. Define dated commodity groups with
[`CommoditySpec`](@ref), select dated commodities with
[`CommodityRef`](@ref) and [`RelativePeriod`](@ref), bind any supported
ordinary GEMB behavior specification through
[`AgentTemplate`](@ref), combine the agents in
[`GEMBModel`](@ref), add intertemporal agents with [`add_agents!`](@ref), and call [`build_model`](@ref). The result is an ordinary GEM
equilibrium model and is solved with the standard GEM solver.

For standard CES or displaced-CES technologies and preferences, users should
normally use `CESSpec` or `DCESSpec` directly. `ActivityDemandSpec` provides a
more general extension interface for models in which compensated or conditional
demand is already available as a function of an activity variable and prices.
Lower-level GEM interfaces remain available whenever a model requires custom
net supplies, complementarity conditions, price bounds, or equilibrium
structures not covered by GEMB's higher-level specifications.


## Producer condition rules

For activity-demand producers, GEMB selects a default complementarity condition
rule when `condition_rule=nothing`. An explicitly supplied `condition_rule`
always overrides the default. This is intentional: GEMB provides convenient
defaults but does not prevent researchers from studying alternative
specifications, including formulations that may have no equilibrium.

The default producer rule is selected in the following order:

1. An `ActivityDemandSpec` with `producer_condition_function` uses
   `ExplicitAgentConditions`.
2. A producer with fixed endowments uses `TotalRevenueExpenditureBalanceConditions`.
3. A `DCESSpec` with any nonzero displacement parameter `xi` uses
   `TotalRevenueExpenditureBalanceConditions`.
4. Otherwise, GEMB uses `UnitRevenueExpenditureBalanceConditions`.

For activity `k`, `UnitRevenueExpenditureBalanceConditions` evaluates net supply at one unit of
that activity, with the other activity variables set to zero:

```math
F_k(\bm p)
=
-\bm p^\top \bm s(\bm e_k,\bm p)
```

`TotalRevenueExpenditureBalanceConditions` instead evaluates the current level of activity `k`.
Let ``\bm z^{(k)}`` denote the activity vector that keeps ``z_k`` and sets the
other activity variables to zero. Then

```math
F_k(\bm z,\bm p)
=
-\bm p^\top \bm s(\bm z^{(k)},\bm p)
```

For a single-activity producer, this reduces to

```math
F(z,\bm p)
=
-\bm p^\top \bm s(z,\bm p)
```

The automatic multi-activity `TotalRevenueExpenditureBalanceConditions` construction is most
natural for a separable composite producer whose activities can be evaluated
independently. GEM and GEMB do not test separability. If activities interact,
or if common fixed endowments or other shared net-supply components require a
particular allocation across paired conditions, users may provide explicit
paired conditions instead.

For example, a researcher may override the default rule directly:

```julia
firm = build_agent(
    CESSpec([0.5, 0.5]);
    output_indices=[1],
    demand_indices=[2, 3],
    condition_rule=TotalRevenueExpenditureBalanceConditions(),
)
```

See [`ActivityDemandSpec`](@ref), [`CESSpec`](@ref), [`DCESSpec`](@ref), and
[`build_agent`](@ref) for the corresponding specification and builder details.


## AMSD asset-exchange equilibrium

GEMB provides the high-level [`solve_asset_equilibrium_amsd`](@ref) interface
for pure asset-exchange economies in which investors have additive
mean-standard-deviation (AMSD) preferences.

The required economic inputs are:

- `Supply`: initial asset endowments, with assets in rows and investors in
  columns;
- `gamma`: investor risk-aversion coefficients;
- `PMP`: subjective expected asset payoffs;
- `PSD`: subjective payoff standard deviations;
- `Cor`: the payoff correlation matrix.

A model can be solved directly with:

```julia
result = solve_asset_equilibrium_amsd(
    Supply=Supply,
    gamma=gamma,
    PMP=PMP,
    PSD=PSD,
    Cor=Cor,
)
```

For investor `i`, GEMB internally constructs a
[`MeanStandardDeviationMarginalUtilitySpec`](@ref) from `PMP[:, i]`,
`PSD[:, i]`, `Cor`, and `gamma[i]`, builds the corresponding pure-exchange
consumer, assembles the equilibrium model, and solves the resulting MCP through
GEM.

By default, short selling is excluded and the final asset is used as the
numeraire. The numeraire can be changed with `numeraire_index`.

The returned equilibrium result retains the standard GEM result information
and additionally provides asset-market quantities and diagnostics, including:

- `p`: equilibrium asset prices;
- `D`: equilibrium asset-holding matrix;
- `lambda`: investor budget multipliers;
- `wealth` and `expenditure`;
- `portfolio_sd`;
- `aggregate_supply`, `aggregate_demand`, and `market_residual`;
- `MU`, `VMU`, and `R`;
- `kkt_passed`.

A complete five-asset, three-investor example is available in
[gemb_assetEquilibriumAMSD_nc5_na3_v1](examples/gemb_assetEquilibriumAMSD_nc5_na3_v1.md).

## Ad valorem claims

In GEMB, a **claim** means an **ad valorem claim**: a right to receive a
specified proportion of an economic value base. The payoff may be a dividend,
interest, ad valorem tax revenue, monopoly rent, transaction fee, or another
proportional value flow. Tax certificates, stocks, bonds, and money are concrete
forms of this general concept. When no ambiguity arises, GEMB documentation
uses *claim* as shorthand for *ad valorem claim*.

The generic interface is `claim_rate` plus `claim=CommodityRef(...)`. See the
[Ad valorem claims guide](ad_valorem_claims.md) for the economic interpretation,
sign convention, dated claims, and the distinction from the separate
asset-equilibrium application layer.

## Intertemporal equilibrium

GEMB represents a finite-horizon intertemporal economy as an ordinary
[`GEMBModel`](@ref) over dated commodities. Time is a commodity axis rather
than a separate equilibrium-model type.

The main public interfaces are:

- [`CommoditySpec`](@ref)
- [`CommodityRef`](@ref)
- [`AgentRef`](@ref)
- [`GEMBModel`](@ref)
- [`add_agent!`](@ref)
- [`AgentTemplate`](@ref)
- [`add_agents!`](@ref)
- [`RelativePeriod`](@ref)
- [`ByPeriod`](@ref)
- [`build_model`](@ref)

Use [`add_agent!`](@ref) for one concrete agent, including a concrete dated
agent. Use [`AgentTemplate`](@ref) with [`add_agents!`](@ref) only when one
structural declaration should be repeated across periods. `RelativePeriod`
varies a reference relative to the concrete agent period, while `ByPeriod`
varies a template parameter value across periods.

See the [Intertemporal equilibrium guide](intertemporal_equilibrium.md) for
the complete workflow, dated claims, repeated agents, and period-varying
parameters.

## Condition agents

[`ConditionAgentSpec`](@ref) represents endogenous equilibrium variables that
are determined directly by explicit conditions rather than by commodity demand
or supply behavior. A condition agent may contain one or several variables,
observe equilibrium prices or variables owned by other agents, and return one
paired condition for each variable. It contributes no economic commodity net
supply.

This is useful for endogenous policy parameters, closure variables, and other
equilibrium quantities that would otherwise require a separate auxiliary
variable and equation. Variable bounds retain the standard GEM
mixed-complementarity interpretation.

See the [Condition agents guide](condition_agents.md) for the complete
interface and examples, including an endogenous tax-rate setter.

## Custom net-supply agents

Standard economic behavior should normally be modeled with [`add_agent!`](@ref)
and a GEMB behavioral specification. For agents whose complete net-supply
mapping and condition rule must be supplied directly, use
[`add_net_supply_agent!`](@ref).

See [Custom net-supply agents](custom_net_supply_agents.md) for the recommended
workflow and the role of the advanced builder API.

## Key API entry points
Detailed documentation for GEMB's types and functions is provided in the API
reference pages. The following interfaces are useful starting points:

- [`build_agent`](@ref)
- [`CESSpec`](@ref)
- [`DCESSpec`](@ref)
- [`ActivityDemandSpec`](@ref)
- [`ConditionAgentSpec`](@ref)
- [`activity_demand`](@ref)
- [`MarginalUtilityConsumerSpec`](@ref)
- [`MarshallDemandConsumerSpec`](@ref)
- [`ProductionFunctionSpec`](@ref)
- [`AbstractMarginalUtilitySpec`](@ref)
- [`CESMarginalUtilitySpec`](@ref)
- [`MeanStandardDeviationMarginalUtilitySpec`](@ref)
- [`solve_asset_equilibrium_amsd`](@ref)

