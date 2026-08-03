$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$contentFolder = Join-Path $repoRoot "Qualification/Input/Content"
$planPath = Join-Path $repoRoot "Qualification/Input/qualification_plan.json"
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json

$releaseLinks = @{
  "Atomoxetine-DGI" = "https://github.com/Open-Systems-Pharmacology/Atomoxetine-Model/releases/tag/v1.0"
  "Clomiphene-DGI" = "https://github.com/Open-Systems-Pharmacology/Clomiphene-Model/releases/tag/v1.0"
  "Desipramine-DGI" = "https://github.com/Open-Systems-Pharmacology/Desipramine-Model/releases/tag/v1.0"
  "Mexiletine-DGI" = "https://github.com/Open-Systems-Pharmacology/Mexiletine-Model/releases/tag/v2.0"
  "Paroxetine-DGI" = "https://github.com/Open-Systems-Pharmacology/Paroxetine-Model/releases/tag/v1.0"
  "Quinidine-Metoprolol-DDGI" = "https://github.com/Open-Systems-Pharmacology/Quinidine-Metoprolol-DDGI/releases/tag/v1.1"
  "Risperidone-DGI" = "https://github.com/Open-Systems-Pharmacology/Risperidone-Model/releases/tag/v1.0"
}

foreach ($project in $plan.Projects) {
  $contentPath = Join-Path $contentFolder "$($project.Id).md"
  if (-not (Test-Path -LiteralPath $contentPath)) {
    continue
  }

  $text = [System.IO.File]::ReadAllText($contentPath).Replace("`r`n", "`n")
  $text = $text -replace "`nThe exact snapshot used for this qualification is available \[here\]\([^)]+\)\.(?: The corresponding released snapshot is available \[here\]\([^)]+\)\.)?", ""

  $snapshotSentence = "The exact snapshot used for this qualification is available [here]($($project.Path))."
  if ($releaseLinks.ContainsKey($project.Id)) {
    $snapshotSentence += " The corresponding released snapshot is available [here]($($releaseLinks[$project.Id]))."
  }

  $sourceLinePattern = '(?m)^(Source (?:project|model snapshot): .+\.)$'
  if ($text -notmatch $sourceLinePattern) {
    throw "Source link not found in $($project.Id).md."
  }
  $text = [regex]::Replace(
    $text,
    $sourceLinePattern,
    "`$1`n`n$snapshotSentence",
    1
  )

  $updated = $text.TrimEnd("`n") + "`n"
  [System.IO.File]::WriteAllText(
    $contentPath,
    $updated,
    [System.Text.UTF8Encoding]::new($false)
  )
}
