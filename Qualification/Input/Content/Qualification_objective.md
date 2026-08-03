This qualification report evaluates the developed physiologically based pharmacokinetic (PBPK) drug-drug-gene interaction (DDGI) network for the ability to perform simulations with the intended purpose to predict cytochrome P450 2D6 (**CYP2D6**)-mediated drug-drug interactions (DDIs) and DDGIs.

This report is mainly based on the comprehensive CYP2D6 DDGI network published by [Rüdesheim 2025](#references) and on the quinidine PBPK model and interaction network published by [Feick 2023](#references). These publications provide the scientific basis for the network structure, CYP2D6 activity-score implementation, and quinidine interaction scenarios evaluated here.

To demonstrate the level of confidence, the predictive performance is assessed using a network of PBPK models for selected CYP2D6 perpetrators, victims, and genotype-dependent interaction scenarios together with clinical DD(G)I data from published studies. The models are whole-body PBPK models and allow dynamic interaction simulations in tissues expressing the relevant enzymes or transporters.

The respective *qualification plan* to produce this *qualification report* is transparently documented and provided open-source (https://github.com/Open-Systems-Pharmacology/DDGI-CYP2D6). The same applies for all presented PBPK models including *evaluation reports* on model building and evaluation of each model (https://github.com/Open-Systems-Pharmacology/OSP-PBPK-Model-Library).

*Evaluation reports* include descriptions of model building and detailed evaluations of the included models. These reports are available separately. The models and interaction scenarios in this qualification are summarized in the [CYP2D6 DDGI network](#cyp2d6-ddgi-network).

See the [Appendix](#appendix) for further details:

- The [OSP Suite introduction](#osp-introduction) describes the whole-body PBPK model structure.

- The [mathematical implementation section](#mathematical-implementation-of-ddi) describes DDI, DGI, and DDGI mechanisms in the OSP Suite.

- The [automatic requalification workflow](#automatic-requalification-workflow) describes the qualification plan, execution, and report generation.
