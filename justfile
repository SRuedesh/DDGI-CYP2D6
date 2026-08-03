set shell := ["pwsh.exe", "-NoProfile", "-Command"]

root := justfile_directory()
runner := root / "../../tools/Qualification-Runner.12.2.232"
workdir := "C:/tmp/osp"

default:
    just --list

run:
    just --justfile "{{root}}/justfile" local-plan
    just --justfile "{{root}}/justfile" preflight
    $ErrorActionPreference='Stop'; pwsh.exe -NoProfile -ExecutionPolicy Bypass -File '{{root}}/scripts/prepare-local-work-folder.ps1' -WorkFolder '{{workdir}}'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $runner=(Resolve-Path -LiteralPath '{{runner}}/QualificationRunner.exe').Path; $plan=(Resolve-Path -LiteralPath '{{root}}/Qualification/tmp/qualification_plan.local.json').Path; $work=(Resolve-Path -LiteralPath '{{workdir}}').Path; $output=Join-Path $work 're_input'; & $runner -i $plan -o $output --norun -n report-configuration-plan -f; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; pwsh.exe -NoProfile -ExecutionPolicy Bypass -File '{{root}}/scripts/remove-iv-cmax-ratios.ps1' -ReferenceFolder $output; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $env:QUALIFICATION_REFERENCE_FOLDER=$output; just --justfile "{{root}}/justfile" check-render-inputs; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $env:QUALIFICATION_WORK_DIR=$work; just --justfile "{{root}}/justfile" render; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

preflight:
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-qualification-references.ps1" -Root "{{root}}"

check-report-consistency:
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-report-consistency.ps1" -Root "{{root}}"

check-release-readiness:
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-report-consistency.ps1" -Root "{{root}}" -ReleaseReady

check-render-inputs:
    $ErrorActionPreference='Stop'; $referenceFolder=$env:QUALIFICATION_REFERENCE_FOLDER; if (-not $referenceFolder) { $referenceFolder=Join-Path (Resolve-Path -LiteralPath '{{workdir}}').Path 're_input' }; pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/check-render-mappings.ps1" -ReferenceFolder $referenceFolder

local-plan:
    just --justfile "{{root}}/justfile" harmonize-plan
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/create-local-plan.ps1" -Root "{{root}}"

harmonize-plan:
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "{{root}}/scripts/harmonize-qualification-plan.ps1" -Root "{{root}}"

render:
    $ErrorActionPreference='Stop'; $env:REPO_ROOT='{{root}}'; $env:LC_ALL=$null; $env:LC_CTYPE=$null; $env:LANG=$null; if (-not $env:QUALIFICATION_WORK_DIR) { $env:QUALIFICATION_WORK_DIR=(Resolve-Path -LiteralPath '{{workdir}}').Path }; if (-not $env:QUALIFICATION_REFERENCE_FOLDER) { $env:QUALIFICATION_REFERENCE_FOLDER=(Join-Path $env:QUALIFICATION_WORK_DIR 're_input') }; pwsh.exe -NoProfile -ExecutionPolicy Bypass -File '{{root}}/scripts/remove-iv-cmax-ratios.ps1' -ReferenceFolder $env:QUALIFICATION_REFERENCE_FOLDER; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; & Rscript '{{root}}/scripts/render-local-report.R'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; pwsh.exe -NoProfile -ExecutionPolicy Bypass -File '{{root}}/scripts/copy-local-report.ps1' -SourceFolder (Join-Path $env:QUALIFICATION_WORK_DIR 'report') -DestinationFolder '{{root}}/Qualification/report' -RepositoryRoot '{{root}}'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

render-ratios:
    $ErrorActionPreference='Stop'; $env:REPO_ROOT='{{root}}'; $env:LC_ALL=$null; $env:LC_CTYPE=$null; $env:LANG=$null; if (-not $env:QUALIFICATION_WORK_DIR) { $env:QUALIFICATION_WORK_DIR=(Resolve-Path -LiteralPath '{{workdir}}').Path }; if (-not $env:QUALIFICATION_REFERENCE_FOLDER) { $env:QUALIFICATION_REFERENCE_FOLDER=(Join-Path $env:QUALIFICATION_WORK_DIR 're_input') }; & Rscript '{{root}}/scripts/render-ratio-plots.R'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

render-pdf:
    $ErrorActionPreference='Stop'; $env:LC_ALL=$null; $env:LC_CTYPE=$null; $env:LANG=$null; $workspace=(Resolve-Path -LiteralPath '{{root}}/../..').Path; $reportDir=(Resolve-Path -LiteralPath '{{root}}/Qualification/report').Path; Push-Location $workspace; try { & Rscript 'tmp/pdfs/render-manual-dgi-timeprofile-plots.R'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; Push-Location $reportDir; try { & pandoc 'report.md' '--embed-resources' '--standalone' '--mathml' '--quiet' '-f' 'gfm+tex_math_dollars' '-t' 'html' '-o' 'report.html'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { Pop-Location }; $edgeCandidates=@('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','C:/Program Files/Microsoft/Edge/Application/msedge.exe'); $browser=($edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1); if (-not $browser) { throw 'Microsoft Edge is required for offline MathML rendering.' }; & node 'tmp/pdfs/render-osp-pdf.js' (Join-Path $reportDir 'report.html') (Join-Path $reportDir 'report.pdf') $browser; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } } finally { Pop-Location }

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
    just harmonize-plan
    just check-utf8
    just check-report-consistency
    just preflight
    just check-plan
    just spellcheck

actions-act:
    act -W .github/workflows/Check_Input_Files.yml
    act -W .github/workflows/Check_Links_In_Report.yml
    act -W .github/workflows/CheckUsingLatestRelease.yml
