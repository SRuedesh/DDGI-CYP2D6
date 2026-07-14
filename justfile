set shell := ["powershell.exe", "-NoProfile", "-Command"]

root := justfile_directory()
runner := root / "../../tools/Qualification-Runner.12.2.232"
workdir := root / "../../runs/ddgi-cyp2d6-local"

default:
    just --list

run:
    just --justfile "{{root}}/justfile" preflight
    just --justfile "{{root}}/justfile" local-plan
    $ErrorActionPreference='Stop'; $runner=(Resolve-Path -LiteralPath '{{runner}}/QualificationRunner.exe').Path; $plan=(Resolve-Path -LiteralPath '{{root}}/Qualification/tmp/qualification_plan.local.json').Path; New-Item -ItemType Directory -Force -Path '{{workdir}}' | Out-Null; $work=(Resolve-Path -LiteralPath '{{workdir}}').Path; $drive='Q:'; if (Test-Path -LiteralPath "$drive\") { throw "Drive $drive is already in use" }; subst $drive $work; try { $short="$drive\"; $output=Join-Path $short 're_input'; & $runner -i $plan -o $output --norun -n report-configuration-plan -f; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $env:QUALIFICATION_REFERENCE_FOLDER=$output; just --justfile "{{root}}/justfile" check-render-inputs; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $env:QUALIFICATION_WORK_DIR=$short; just --justfile "{{root}}/justfile" render; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { subst $drive /D }

preflight:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-qualification-references.ps1" -Root "{{root}}"

check-render-inputs:
    $ErrorActionPreference='Stop'; $referenceFolder=$env:QUALIFICATION_REFERENCE_FOLDER; if (-not $referenceFolder) { $referenceFolder=Join-Path (Resolve-Path -LiteralPath '{{workdir}}').Path 're_input' }; powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-render-mappings.ps1" -ReferenceFolder $referenceFolder

local-plan:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/create-local-plan.ps1" -Root "{{root}}"

render:
    $ErrorActionPreference='Stop'; $env:REPO_ROOT='{{root}}'; $createdDrive=$false; if (-not $env:QUALIFICATION_WORK_DIR) { $work=(Resolve-Path -LiteralPath '{{workdir}}').Path; $drive='Q:'; if (Test-Path -LiteralPath "$drive\") { throw "Drive $drive is already in use" }; subst $drive $work; $env:QUALIFICATION_WORK_DIR="$drive\"; $createdDrive=$true }; if (-not $env:QUALIFICATION_REFERENCE_FOLDER) { $env:QUALIFICATION_REFERENCE_FOLDER=(Join-Path $env:QUALIFICATION_WORK_DIR 're_input') }; try { & Rscript '{{root}}/scripts/render-local-report.R'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { if ($createdDrive) { subst Q: /D } }

render-inline:
    $ErrorActionPreference='Stop'; $env:REPO_ROOT='{{root}}'; $createdDrive=$false; if (-not $env:QUALIFICATION_WORK_DIR) { $work=(Resolve-Path -LiteralPath '{{workdir}}').Path; $drive='Q:'; if (Test-Path -LiteralPath "$drive\") { throw "Drive $drive is already in use" }; subst $drive $work; $env:QUALIFICATION_WORK_DIR="$drive\"; $createdDrive=$true }; if (-not $env:QUALIFICATION_REFERENCE_FOLDER) { $env:QUALIFICATION_REFERENCE_FOLDER=(Join-Path $env:QUALIFICATION_WORK_DIR 're_input') }; try { Rscript -e "library(ospsuite.reportingengine); originalLoadConfigurationPlan <- ospsuite.reportingengine:::loadConfigurationPlan; patchedLoadConfigurationPlan <- function(configurationPlanFile, workflowFolder) { plan <- originalLoadConfigurationPlan(configurationPlanFile, workflowFolder); plan`$referenceFolder <- gsub('\\\\', '/', Sys.getenv('QUALIFICATION_REFERENCE_FOLDER')); mappings <- plan`$.__enclos_env__`$private`$.simulationMappings; mappings`$path <- sub('[/\\\\]+$', '', mappings`$path); simulationFiles <- file.path(plan`$referenceFolder, mappings`$path, paste0(mappings`$simulationFile, '.pkml')); fileSizes <- file.info(simulationFiles)`$size; validMappings <- file.exists(simulationFiles) & !is.na(fileSizes) & fileSizes > 0; if (any(!validMappings)) { warning(sprintf('Excluding %d simulation mapping(s) with missing or empty PKML files.', sum(!validMappings))) }; plan`$.__enclos_env__`$private`$.simulationMappings <- mappings[validMappings, , drop = FALSE]; plan }; assignInNamespace('loadConfigurationPlan', patchedLoadConfigurationPlan, ns='ospsuite.reportingengine'); root <- normalizePath(Sys.getenv('REPO_ROOT'), winslash='/', mustWork=TRUE); workDir <- gsub('\\\\', '/', Sys.getenv('QUALIFICATION_WORK_DIR')); w <- loadQualificationWorkflow(workflowFolder=file.path(workDir, 're_output'), configurationPlanFile=file.path(workDir, 're_input', 'report-configuration-plan.json')); w`$reportFilePath <- file.path(root, 'Qualification', 'report', 'report.md'); w`$createWordReport <- FALSE; w`$inactivateTasks(c('simulate', 'calculatePKParameters', 'plotTimeProfiles', 'plotComparisonTimeProfile', 'plotGOFMerged', 'plotPKRatio', 'plotDDIRatio')); w`$runWorkflow()"; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { if ($createdDrive) { subst Q: /D } }

render-pdf:
    $ErrorActionPreference='Stop'; $workspace=(Resolve-Path -LiteralPath '{{root}}/../..').Path; $reportDir=(Resolve-Path -LiteralPath '{{root}}/Qualification/report').Path; Push-Location $workspace; try { & Rscript 'tmp/pdfs/render-manual-dgi-timeprofile-plots.R'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; Push-Location $reportDir; try { & pandoc 'report.md' '--embed-resources' '--standalone' '--mathjax' '--quiet' '-c' 'osp.css' '-f' 'gfm+tex_math_dollars' '-t' 'html' '-o' 'report.html'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { Pop-Location }; $chrome=(Get-ChildItem -LiteralPath 'tmp/pdfs/chromehtml2pdf/node_modules/puppeteer/.local-chromium' -Recurse -Filter chrome.exe | Select-Object -First 1).FullName; if (-not $chrome) { throw 'Local Chromium executable was not found.' }; & node 'tmp/pdfs/render-osp-pdf.js' (Join-Path $reportDir 'report.html') (Join-Path $reportDir 'report.pdf') $chrome; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { Pop-Location }

clean:
    $paths = @('{{workdir}}', '{{root}}/Qualification/re_input', '{{root}}/Qualification/re_output', '{{root}}/Qualification/report', '{{root}}/Qualification/tmp', '{{root}}/Qualification/runner.log', '{{root}}/Qualification/Rplots.pdf', '{{root}}/Rplots.pdf', '{{root}}/.spellcheck.yml', '{{root}}/wordlist_osp_global.txt', '{{root}}/OSP_Qualification_Plan_Schema.json', '{{root}}/mlc_config.json'); foreach ($path in $paths) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force } }

check-utf8:
    $ErrorActionPreference = 'Stop'; $utf8 = [System.Text.UTF8Encoding]::new($false, $true); Get-ChildItem -Path '{{root}}' -Recurse -File -Include *.R,*.json,*.md,*.yml,*.yaml,justfile | Where-Object { $_.FullName -notmatch '\\.git\\' } | ForEach-Object { $null = $utf8.GetString([System.IO.File]::ReadAllBytes($_.FullName)) }

check-plan:
    $ErrorActionPreference = 'Stop'; $schemaUrl = (Get-Content '{{root}}/Qualification/Input/qualification_plan.json' -Raw | ConvertFrom-Json).'$schema'; Invoke-WebRequest -Uri $schemaUrl -OutFile '{{root}}/OSP_Qualification_Plan_Schema.json'; try { $output = docker run --rm -e GITHUB_WORKSPACE=/github/workspace -e INPUT_SCHEMA=OSP_Qualification_Plan_Schema.json -e INPUT_JSONS=Qualification/Input/qualification_plan.json -v '{{root}}:/github/workspace' -w /github/workspace orrosenblatt/validate-json-action:latest 2>&1; $output; if (($LASTEXITCODE -ne 0) -or (($output -join "`n") -match 'Failed to validate|ADDTIONAL PROPERTY|::error::')) { throw 'Qualification plan validation failed' } } finally { Remove-Item -LiteralPath '{{root}}/OSP_Qualification_Plan_Schema.json' -Force -ErrorAction SilentlyContinue }

spellcheck:
    $ErrorActionPreference = 'Stop'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Open-Systems-Pharmacology/Workflows/main/Config/.spellcheck.yml' -OutFile '{{root}}/.spellcheck.yml'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Open-Systems-Pharmacology/Workflows/main/Data/wordlist_osp_global.txt' -OutFile '{{root}}/wordlist_osp_global.txt'; try { $output = docker run --rm -v '{{root}}:/github/workspace' -w /github/workspace jonasbn/github-action-spellcheck:0.35.0 2>&1; $output; if (($LASTEXITCODE -ne 0) -or (($output -join "`n") -match 'Spelling check failed|Misspelled words|::error')) { throw 'Spellcheck failed' } } finally { Remove-Item -LiteralPath '{{root}}/.spellcheck.yml','{{root}}/wordlist_osp_global.txt' -Force -ErrorAction SilentlyContinue }

actions:
    just clean
    just check-utf8
    just preflight
    just check-plan
    just spellcheck

actions-act:
    act -W .github/workflows/Check_Input_Files.yml
    act -W .github/workflows/Check_Links_In_Report.yml
    act -W .github/workflows/CheckUsingLatestRelease.yml
