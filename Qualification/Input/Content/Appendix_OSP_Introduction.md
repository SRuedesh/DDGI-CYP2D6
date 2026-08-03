The Open Systems Pharmacology (OSP) Suite is an open software environment for whole-body physiologically based pharmacokinetic (PBPK) modeling and simulation. PK-Sim and MoBi are the principal modeling applications in the suite [[1](#references-osps-introduction)]. PK-Sim provides a generic whole-body PBPK structure. MoBi supports detailed extensions of the model structure and reaction networks.

The generic human model represents the principal organs and tissues that control drug absorption, distribution, metabolism, and excretion. These include arterial and venous blood, adipose tissue, brain, bone, gonads, heart, kidneys, large intestine, liver, lung, muscle, pancreas, portal vein, skin, small intestine, spleen, and stomach. Figure Appendix-1 shows the model structure.

Each organ contains vascular plasma, blood-cell, interstitial, and cellular spaces. Distribution between these spaces can be perfusion-limited or permeability-limited. The brain model places the permeation barrier between the vascular and interstitial spaces. PK-Sim can estimate intestinal permeability, organ-to-plasma partition coefficients, and membrane permeabilities from compound properties and tissue composition [[2-7](#references-osps-introduction)].

The physiological databases describe organ composition, organ weights, blood flows, and gastrointestinal properties. The gastrointestinal parameters include segment length, radius, surface area, transit time, and pH. These properties depend on characteristics such as body weight, height, age, sex, and ethnicity. PK-Sim uses these relationships to create individuals and virtual populations [[2, 4, 8, 9](#references-osps-introduction)]. See the current [OSP modeling concepts](https://docs.open-systems-pharmacology.org/mechanistic-modeling-of-pharmacokinetics-and-dynamics/modeling-concepts) for additional details.

<a id="figure-appendix-1"></a>

![Diagram of the generic PK-Sim whole-body PBPK model with gastrointestinal, hepatic, renal, pulmonary, and systemic tissue compartments](images/PK-Sim_PBPK_generic_model_scheme.png)

**Figure Appendix-1: Structure of the whole-body PBPK model implemented in PK-Sim**

<a id="references-osps-introduction"></a>

### References for the OSP introduction

1. [Open Systems Pharmacology](https://www.open-systems-pharmacology.org/).
2. [Willmann S, Schmitt W, Keldenich J, Lippert J, Dressman JB. A physiological model for the estimation of the fraction dose absorbed in humans. *J Med Chem.* 2004;47:4022-4031.](https://pubmed.ncbi.nlm.nih.gov/15267240/)
3. Haerter MW, Keldenich J, Schmitt W. Estimation of physicochemical and ADME parameters. In: *Handbook of Combinatorial Chemistry*. Wiley-VCH; 2002:743-760.
4. [Willmann S, Lippert J, Schmitt W. From physicochemistry to absorption and distribution: predictive mechanistic modelling and computational tools. *Expert Opin Drug Metab Toxicol.* 2005;1:159-168.](https://pubmed.ncbi.nlm.nih.gov/16922658/)
5. [Rodgers T, Leahy D, Rowland M. Physiologically based pharmacokinetic modeling 1: predicting the tissue distribution of moderate-to-strong bases. *J Pharm Sci.* 2005;94:1259-1276.](https://pubmed.ncbi.nlm.nih.gov/15858854/)
6. [Rodgers T, Rowland M. Physiologically based pharmacokinetic modelling 2: predicting the tissue distribution of acids, very weak bases, neutrals and zwitterions. *J Pharm Sci.* 2006;95:1238-1257.](https://pubmed.ncbi.nlm.nih.gov/16639716/)
7. [Rodgers T, Rowland M. Mechanistic approaches to volume of distribution predictions: understanding the processes. *Pharm Res.* 2007;24:918-933.](https://pubmed.ncbi.nlm.nih.gov/17372687/)
8. [Willmann S, Höhn K, Edginton A, et al. Development of a physiology-based whole-body population model for assessing the influence of individual variability on drug pharmacokinetics. *J Pharmacokinet Pharmacodyn.* 2007;34:401-431.](https://pubmed.ncbi.nlm.nih.gov/17431751/)
9. Willmann S, Lippert J, Sevestre M, et al. PK-Sim: a physiologically based pharmacokinetic whole-body model. *Biosilico.* 2003;1:121-124.
