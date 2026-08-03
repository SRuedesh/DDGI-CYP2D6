param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Read-Json($Path) {
  [System.IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json
}

function Add-Issue($Issues, $Kind, $Project, $Value, $Detail) {
  $Issues.Add([pscustomobject]@{
    Kind = $Kind
    Project = $Project
    Value = $Value
    Detail = $Detail
  }) | Out-Null
}

function Resolve-ProjectSnapshotPath($Root, $ProjectId, $ProjectPath) {
  $file = Split-Path -Leaf $ProjectPath
  $candidatePaths = [System.Collections.Generic.List[string]]::new()
  $candidatePaths.Add((Join-Path $Root (Join-Path '../ddi' (Join-Path $ProjectId $file)))) | Out-Null
  $candidatePaths.Add((Join-Path $Root (Join-Path '..' (Join-Path $ProjectId $file)))) | Out-Null

  if ($ProjectId -match '-DGI$') {
    $modelRepo = $ProjectId -replace '-DGI$', '-Model'
    $candidatePaths.Add((Join-Path $Root (Join-Path '..' (Join-Path $modelRepo $file)))) | Out-Null
  }

  foreach ($candidate in $candidatePaths) {
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  return $candidatePaths[0]
}

function Collect-References($Node, $Project, $References) {
  if ($null -eq $Node) {
    return
  }

  if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
    foreach ($item in $Node) {
      Collect-References $item $Project $References
    }
    return
  }

  if ($Node.PSObject -and $Node.PSObject.Properties) {
    $nextProject = $Project
    $projectProperty = $Node.PSObject.Properties['Project']
    if ($projectProperty -and $projectProperty.Value) {
      $nextProject = [string]$projectProperty.Value
    }

    foreach ($property in $Node.PSObject.Properties) {
      if (($property.Name -eq 'Simulation' -or $property.Name -eq 'ObservedData') -and $nextProject) {
        $References.Add([pscustomobject]@{
          Project = $nextProject
          Type = $property.Name
          Value = [string]$property.Value
        }) | Out-Null
      }
      Collect-References $property.Value $nextProject $References
    }
  }
}

$planPath = Join-Path $Root 'Qualification/Input/qualification_plan.json'
$plan = Read-Json $planPath
$issues = [System.Collections.Generic.List[object]]::new()
$references = [System.Collections.Generic.List[object]]::new()
Collect-References $plan $null $references

$projects = @{}
foreach ($project in $plan.Projects) {
  $snapshotPath = Resolve-ProjectSnapshotPath $Root $project.Id $project.Path
  if (-not (Test-Path -LiteralPath $snapshotPath)) {
    Add-Issue $issues 'missing-project-snapshot' $project.Id $snapshotPath 'Local project snapshot was not found.'
    continue
  }

  $snapshot = Read-Json $snapshotPath
  $projects[$project.Id] = [pscustomobject]@{
    SnapshotPath = $snapshotPath
    Simulations = @($snapshot.Simulations | ForEach-Object { [string]$_.Name })
    ObservedData = @($snapshot.ObservedData | ForEach-Object { [string]$_.Name })
  }

}

foreach ($reference in $references) {
  if (-not $projects.ContainsKey($reference.Project)) {
    continue
  }

  $allowed = if ($reference.Type -eq 'Simulation') {
    $projects[$reference.Project].Simulations
  } else {
    $projects[$reference.Project].ObservedData
  }

  if ($reference.Value -notin $allowed) {
    Add-Issue $issues "missing-$($reference.Type)" $reference.Project $reference.Value "Reference is not present in local $($reference.Type) names."
  }
}

if ($issues.Count -gt 0) {
  $issues | Sort-Object Project, Kind, Value | Format-Table -AutoSize | Out-String -Width 220 | Write-Error
  throw "Qualification reference preflight failed with $($issues.Count) issue(s)."
}

Write-Output "Qualification reference preflight passed: $($references.Count) plan references checked."
