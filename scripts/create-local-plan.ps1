param(
  [Parameter(Mandatory = $true)]
  [string]$Root
)

$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Resolve-ProjectPath($project) {
  $file = Split-Path -Leaf $project.Path
  $candidates = [System.Collections.Generic.List[string]]::new()
  $candidates.Add((Join-Path $rootPath (Join-Path "../ddi" (Join-Path $project.Id $file)))) | Out-Null
  $candidates.Add((Join-Path $rootPath (Join-Path ".." (Join-Path $project.Id $file)))) | Out-Null

  if ($project.Id -match "-DGI$") {
    $modelRepo = $project.Id -replace "-DGI$", "-Model"
    $candidates.Add((Join-Path $rootPath (Join-Path ".." (Join-Path $modelRepo $file)))) | Out-Null
  }

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path.Replace("\", "/")
    }
  }

  throw "Local project snapshot not found for $($project.Id)"
}

function Resolve-ObservedDataPath($dataSet) {
  if ($dataSet.Id -eq "DDI Ratios") {
    $observedData = $env:DDI_OBSERVED_DATA
    if ($observedData) {
      return (Resolve-Path -LiteralPath $observedData).Path.Replace("\", "/")
    }
    return $dataSet.Path
  }

  if ($dataSet.Path -match "^https?://") {
    return $dataSet.Path
  }

  return (Resolve-Path -LiteralPath (Join-Path (Join-Path $rootPath "Qualification/Input") $dataSet.Path)).Path.Replace("\", "/")
}

$planPath = Join-Path $rootPath "Qualification/Input/qualification_plan.json"
$plan = [System.IO.File]::ReadAllText($planPath, $utf8) | ConvertFrom-Json

foreach ($project in $plan.Projects) {
  $project.Path = Resolve-ProjectPath $project
}

foreach ($dataSet in $plan.ObservedDataSets) {
  $dataSet.Path = Resolve-ObservedDataPath $dataSet
}

$tmp = Join-Path $rootPath "Qualification/tmp"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$content = (Resolve-Path -LiteralPath (Join-Path $rootPath "Qualification/Input/Content")).Path.Replace("\", "/") + "/"
$json = ($plan | ConvertTo-Json -Depth 100).Replace('"Content/', '"' + $content)
[System.IO.File]::WriteAllText((Join-Path $tmp "qualification_plan.local.json"), ($json + "`n"), $utf8)
