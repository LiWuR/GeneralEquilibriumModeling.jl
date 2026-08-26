```@meta
CurrentModule = GEMB
```

# Ad valorem claims

In GEMB, a **claim** means an **ad valorem claim**: a right to receive a
specified proportion of an economic value base. When the meaning is
unambiguous, the documentation uses *claim* as shorthand for *ad valorem
claim*.

If the relevant value base is \(B\) and the claim rate is \(\tau\), the value
attached to the claim is proportional to that base:

\[
V_{\mathrm{claim}} = \tau B.
\]

The economic interpretation of \(B\) and of the resulting payoff is
application-specific. The payoff may take the form of a dividend, interest,
ad valorem tax revenue, monopoly rent, transaction fee, or another
proportional value flow. The claim therefore represents economic ownership
of the corresponding proportional component of value.

Tax certificates, stocks, bonds, and money are concrete forms of this general
economic concept. A tax certificate is one particularly transparent example:
holding the relevant right is economically analogous to holding the right to
collect a specified ad valorem tax rate from a defined value base. The same
generic proportional-right structure can represent other institutions without
turning the generic claim layer into a tax-specific mechanism.

## GEMB interface

At the high-level GEMB interface, users specify the proportional rate and the
claim commodity separately:

```julia
claim_rate=0.10,
claim=CommodityRef(:claim),
```

`claim_rate` specifies the proportional right or obligation. `claim` identifies
the commodity that carries that right. `GEMBModel` resolves the commodity
reference internally to the low-level integer coordinate used by the builder.

A dated claim is still an ordinary dated commodity at the commodity layer.
Its economic meaning comes from the agent that binds it through `claim_rate`
and `claim`. This is why the same structural mechanism can represent a dated
tax right, a financial right, or another proportional value right.

## Sign of the claim rate

The generic claim mechanism is neutral about institutional interpretation.
The sign of `claim_rate` determines the direction of the proportional value
transfer. A negative rate is therefore not intrinsically a "subsidy"; subsidy
is one possible interpretation in a tax-policy application.

## Relation to asset equilibrium

The general economic statement that stocks, bonds, and money are forms of ad
valorem claims does **not** imply that every GEMB asset model is implemented
through the claim API.

In particular, `solve_asset_equilibrium_amsd` studies an asset-exchange
equilibrium directly. Its assets, payoff expectations, risk structure, and
portfolio holdings belong to that asset-market application layer. The
`asset_equilibrium_amsd` implementation is therefore separate from the generic
`claim_rate` / `claim` mechanism.
