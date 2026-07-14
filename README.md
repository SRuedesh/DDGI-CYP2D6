# Qualification-DDGI-CYP2D6

This repository contains the qualification plan and static input content for the CYP2D6 drug-drug-gene interaction (DDGI) network published by Rüdesheim et al. [[1](#references)].

The qualification evaluates a network of PBPK models for selected CYP2D6 perpetrators, victims, and genotype-dependent interaction scenarios using published clinical DD(G)I data.

Users of the qualification workflow are expected to cite this study when using the network or qualification content in scientific work, reports or derivative model development:
- [S Rüdesheim, H L H Loer, D Feick, F Z Marok, L M Fuhr, D Selzer, D Teutonico, A R P Schneider, J Solodenko, S Frechen, M van der Lee, D J A R Moes, J J Swen, M Schwab, T Lehr. A Comprehensive CYP2D6 Drug-Drug-Gene Interaction Network for Application in Precision Dosing and Drug Development. Clin Pharmacol Ther, 2025.](https://doi.org/10.1002/cpt.3604)

## Repository files
This repository contains:

- static content as input for the qualification plan
- a qualification plan to create the CYP2D6 DDGI qualification report
- GitHub workflow files for automated checks
- local helper scripts and a `justfile` for preflight and report-assembly checks

## Local report workflow

The local workflow is intended for fast structural checks and report-only iterations against the sibling repositories under `../` and `../ddi`.

Prerequisites:

1. OSP Qualification Runner 12.2.232 is available at `../../tools/Qualification-Runner.12.2.232`.
2. The adjusted parent and interaction repositories are available as local siblings, for example `../Atomoxetine-Model`, `../Paroxetine-Model`, and `../ddi/<interaction-repository>`.
3. R can load `ospsuite.reportingengine`.
4. `just` is available on `PATH`.

Useful recipes:

1. `just preflight`: checks that all simulations and observed-data references in `Qualification/Input/qualification_plan.json` resolve against the local sibling snapshots.
2. `just local-plan`: writes `Qualification/tmp/qualification_plan.local.json` with local snapshot and content paths.
3. `just check-render-inputs`: checks the exported `re_input/report-configuration-plan.json` and runner mappings before rendering.
4. `just render`: assembles `Qualification/report/report.md` from existing reporting-engine outputs. This recipe intentionally inactivates simulation, PK calculation, and plot-generation tasks.
5. `just run`: runs `preflight`, creates the local plan, exports runner input with `--norun`, checks render mappings, and then runs the report-only render.
6. `just actions`: runs the local equivalents of the input-file checks, including UTF-8, plan validation, and spellcheck.

The local workflow uses a temporary `Q:` drive during `just run` to avoid Windows path-length problems in exported runner files.

If model simulations, PK parameters, or plots must be regenerated locally, do not rely on `just render` alone. Run the full reporting workflow with the relevant reporting-engine tasks enabled, or use the remote workflow described below.

## Remote report workflow

Remote report generation is handled from the `Create-Qualification-Reports` repository, not from this repository directly.

For a full CYP2D6 qualification report:

1. Add or enable one row in `qualifications.csv` with `Repository name` set to `DDGI-CYP2D6`.
2. Set `Released version` to the branch or tag that contains the intended qualification plan.
3. Leave `Workflow name` empty unless a non-default workflow script is required. The default is `Qualification/workflow.R`.
4. Set `Folder name` to the output folder for the generated report.
5. Run the GitHub Action `Create qualification reports`.

The remote workflow runs `Qualification/workflow.R`, creates `report.md`, `report.pdf`, and `images`, and opens a pull request in the repository where the workflow was run. If the workflow is run from a fork, the generated pull request is created in that fork.

For batch testing, use separate `qualifications.csv` rows that point to batch branches. For the final report, disable batch rows and enable the single full-report row only.

## Code of conduct

Everyone interacting in the Open Systems Pharmacology community (codebases, issue trackers, chat rooms, mailing lists etc...) is expected to follow the Open Systems Pharmacology [code of conduct](https://github.com/Open-Systems-Pharmacology/Suite/blob/master/CODE_OF_CONDUCT.md#contributor-covenant-code-of-conduct).

## Contribution

We encourage contribution to the Open Systems Pharmacology community. Before getting started please read the [contribution guidelines](https://github.com/Open-Systems-Pharmacology/Suite/blob/master/CONTRIBUTING.md#ways-to-contribute).

## License

The model code is distributed under the [GPLv2 License](https://github.com/Open-Systems-Pharmacology/Suite/blob/develop/LICENSE).

## References
[1] [S Rüdesheim, H L H Loer, D Feick, F Z Marok, L M Fuhr, D Selzer, D Teutonico, A R P Schneider, J Solodenko, S Frechen, M van der Lee, D J A R Moes, J J Swen, M Schwab, T Lehr. A Comprehensive CYP2D6 Drug-Drug-Gene Interaction Network for Application in Precision Dosing and Drug Development. Clin Pharmacol Ther, 2025.](https://doi.org/10.1002/cpt.3604)
