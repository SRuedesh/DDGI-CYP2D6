param(
  [string]$ReferenceFolder
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

if (-not $ReferenceFolder) {
  throw 'ReferenceFolder is required.'
}

function Read-Json($Path) {
  [System.IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json
}

function Add-Issue($Issues, $Project, $Simulation, $Detail) {
  $Issues.Add([pscustomobject]@{
    Project = $Project
    Simulation = $Simulation
    Detail = $Detail
  }) | Out-Null
}

function Join-ReferencePath($Root, $RelativePath, $FileName) {
  $parts = [System.Collections.Generic.List[string]]::new()
  $parts.Add($Root)

  foreach ($part in ([string]$RelativePath -split '[\\/]')) {
    if ($part) {
      $parts.Add($part)
    }
  }

  if ($FileName) {
    $parts.Add($FileName)
  }

  return [System.IO.Path]::Combine($parts.ToArray())
}

function Collect-SimulationReferences($Node, $Project, $References) {
  if ($null -eq $Node) {
    return
  }

  if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
    foreach ($item in $Node) {
      Collect-SimulationReferences $item $Project $References
    }
    return
  }

  if ($Node -is [string] -or -not $Node.PSObject -or -not $Node.PSObject.Properties) {
    return
  }

  $nextProject = $Project
  $projectProperty = $Node.PSObject.Properties['Project']
  if ($projectProperty -and $projectProperty.Value) {
    $nextProject = [string]$projectProperty.Value
  }

  $simulationProperty = $Node.PSObject.Properties['Simulation']
  if ($simulationProperty -and $simulationProperty.Value -and $nextProject) {
    $References.Add([pscustomobject]@{
      Project = $nextProject
      Simulation = [string]$simulationProperty.Value
    }) | Out-Null
  }

  foreach ($property in $Node.PSObject.Properties) {
    Collect-SimulationReferences $property.Value $nextProject $References
  }
}

$planPath = Join-Path $ReferenceFolder 'report-configuration-plan.json'
if (-not (Test-Path -LiteralPath $planPath)) {
  throw "Report configuration plan not found: $planPath"
}

$plan = Read-Json $planPath
$references = [System.Collections.Generic.List[object]]::new()
Collect-SimulationReferences $plan $null $references

$mappings = @{}
$mappedProjects = @{}
Get-ChildItem -Path (Join-Path $ReferenceFolder 'temp') -Recurse -File -Filter mapping.json | ForEach-Object {
  $mapping = Read-Json $_.FullName
  foreach ($simulationMapping in $mapping.SimulationMappings) {
    $key = "$($simulationMapping.Project)`n$($simulationMapping.Simulation)"
    $mappings[$key] = $simulationMapping
    $mappedProjects[$simulationMapping.Project] = $true
  }
}

$issues = [System.Collections.Generic.List[object]]::new()
foreach ($reference in ($references | Sort-Object Project, Simulation -Unique)) {
  if (-not $mappedProjects.ContainsKey($reference.Project)) {
    continue
  }

  $key = "$($reference.Project)`n$($reference.Simulation)"
  if (-not $mappings.ContainsKey($key)) {
    Add-Issue $issues $reference.Project $reference.Simulation 'Report references a simulation that was not exported into simulationMappings.'
  }
}

foreach ($simulationMapping in $mappings.Values) {
  $simulationFile = Join-ReferencePath $ReferenceFolder $simulationMapping.Path "$($simulationMapping.SimulationFile).pkml"
  if (-not (Test-Path -LiteralPath $simulationFile)) {
    Add-Issue $issues $simulationMapping.Project $simulationMapping.Simulation "Mapped simulation file does not exist: $simulationFile"
  }
}

Get-ChildItem -Path (Join-Path $ReferenceFolder 'temp') -Recurse -File -Filter mapping.json | ForEach-Object {
  $mapping = Read-Json $_.FullName
  foreach ($observedDataMapping in $mapping.ObservedDataMappings) {
    $observedDataFile = Join-ReferencePath $ReferenceFolder $observedDataMapping.Path $null
    if (-not (Test-Path -LiteralPath $observedDataFile)) {
      Add-Issue $issues $_.Directory.BaseName $observedDataMapping.Id "Mapped observed-data file does not exist: $observedDataFile"
    }
  }
}

if ($issues.Count -gt 0) {
  $issues | Sort-Object Project, Simulation | Format-Table -AutoSize | Out-String -Width 220 | Write-Error
  throw "Render mapping preflight failed with $($issues.Count) missing simulation mapping(s)."
}

Write-Output "Render mapping preflight passed: $($references.Count) report simulation references checked."
