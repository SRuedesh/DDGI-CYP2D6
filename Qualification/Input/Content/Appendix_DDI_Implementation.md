Drug-drug interaction simulations in the OSP Suite use mechanistic changes in drug disposition processes. The qualified CYP2D6 network includes enzyme inhibition, enzyme induction, transporter interactions, and genotype-dependent enzyme activity. The source models define the applicable mechanisms and parameters.

**Reversible inhibition**

Reversible inhibition reduces the affected enzyme or transporter activity according to the inhibitor concentration and the inhibition parameters in the source model. See the OSP documentation for [competitive inhibition](https://docs.open-systems-pharmacology.org/working-with-pk-sim/pk-sim-documentation/pk-sim-compounds-defining-inhibition-induction-processes#competitive-inhibition-simple-setting-with-one-inhibitor).

**Mechanism-based inactivation**

Mechanism-based inactivation changes enzyme activity over time. Recovery depends on enzyme turnover and the inactivation parameters in the source model. See the OSP documentation for [irreversible inhibition](https://docs.open-systems-pharmacology.org/working-with-pk-sim/pk-sim-documentation/pk-sim-compounds-defining-inhibition-induction-processes#irreversible-inhibition).

**Induction**

Induction increases the abundance or activity of the affected protein according to the inducer exposure and the induction parameters. See the OSP documentation for [enzyme induction](https://docs.open-systems-pharmacology.org/working-with-pk-sim/pk-sim-documentation/pk-sim-compounds-defining-inhibition-induction-processes#enzyme-induction).

**Transporter interactions**

Some interactions in the network include transporter inhibition or induction, such as P-glycoprotein effects. These effects are separate from CYP2D6 metabolism and are included only when they are defined in the qualified source model and interaction scenario.

**Drug-gene and drug-drug-gene interactions**

CYP2D6 genotype or phenotype is represented with the activity-score-specific or phenotype-specific settings defined by each source model. A DGI comparison changes CYP2D6 activity without a perpetrator. A DDGI comparison combines the genotype-dependent activity setting with perpetrator exposure. Drug effects and gene effects therefore enter the simulations through separate model settings.

The qualification workflow calculates AUC and C<sub>max</sub> ratios from matched control and comparison simulations over the prespecified integration windows. It compares these predictions with the corresponding observed ratios. The qualification workflow does not optimize mechanism parameters during report generation. Interaction-project snapshots may contain prespecified mechanism parameters that differ from, or are not included in, the corresponding parent-model snapshot. Such deviations are documented in the network description.
