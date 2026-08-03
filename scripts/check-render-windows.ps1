param(
  [Parameter(Mandatory = $true)]
  [string]$PlanPath,
  [Parameter(Mandatory = $true)]
  [string]$ReferenceFolder,
  [Parameter(Mandatory = $true)]
  [string]$ResultsFolder
)

$ErrorActionPreference = "Stop"

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$simulationFiles = @{}
Get-ChildItem -Path (Join-Path $ReferenceFolder "temp") -Recurse -File -Filter mapping.json |
  ForEach-Object {
    $mapping = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
    foreach ($simulation in $mapping.SimulationMappings) {
      $simulationFiles["$($simulation.Project)`n$($simulation.Simulation)"] =
        $simulation.SimulationFile
    }
  }

$issues = [System.Collections.Generic.List[object]]::new()
foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  $isLogarithmic = @($plot.Axes | Where-Object {
    $_.Type -eq "Y" -and $_.Scaling -eq "Log"
  }).Count -gt 0

  foreach ($outputMapping in $plot.OutputMappings) {
    if ($outputMapping.ObservedData) {
      $observedPath = Join-Path (Join-Path $ReferenceFolder "ObservedData") "$($outputMapping.ObservedData).csv"
      if (-not (Test-Path -LiteralPath $observedPath)) {
        $issues.Add([pscustomobject]@{
          Plot = $plot.Title
          Simulation = $outputMapping.Simulation
          Issue = "Missing observed-data CSV: $($outputMapping.ObservedData)"
        }) | Out-Null
      } else {
        $observed = Import-Csv -LiteralPath $observedPath
        $observedTimeColumn = $observed[0].PSObject.Properties.Name |
          Where-Object { $_ -match "^Time \[h\]$" } |
          Select-Object -First 1
        $observedStart = [double]$outputMapping.StartTime
        $observedEnd = $observedStart + [double]$plot.SimulationDuration
        $observedWindow = @($observed | Where-Object {
          [double]$_.$observedTimeColumn -ge $observedStart -and
            [double]$_.$observedTimeColumn -le $observedEnd
        })
        if (-not $observedTimeColumn -or $observedWindow.Count -eq 0) {
          $issues.Add([pscustomobject]@{
            Plot = $plot.Title
            Simulation = $outputMapping.Simulation
            Issue = "No observed values in $observedStart-$observedEnd h"
          }) | Out-Null
        }
      }
    }

    $key = "$($outputMapping.Project)`n$($outputMapping.Simulation)"
    if (-not $simulationFiles.ContainsKey($key)) {
      $issues.Add([pscustomobject]@{
        Plot = $plot.Title
        Simulation = $outputMapping.Simulation
        Issue = "No simulation-file mapping"
      }) | Out-Null
      continue
    }

    $resultPath = Join-Path $ResultsFolder (
      "$($outputMapping.Project)-$($simulationFiles[$key])-SimulationResults.csv"
    )
    if (-not (Test-Path -LiteralPath $resultPath)) {
      $issues.Add([pscustomobject]@{
        Plot = $plot.Title
        Simulation = $outputMapping.Simulation
        Issue = "No simulation-results CSV"
      }) | Out-Null
      continue
    }

    $data = Import-Csv -LiteralPath $resultPath
    $timeColumn = $data[0].PSObject.Properties.Name |
      Where-Object { $_ -match "^Time \[min\]$" } |
      Select-Object -First 1
    $outputColumn = $data[0].PSObject.Properties.Name |
      Where-Object { $_.StartsWith("$($outputMapping.Output) [") } |
      Select-Object -First 1
    if (-not $timeColumn -or -not $outputColumn) {
      $issues.Add([pscustomobject]@{
        Plot = $plot.Title
        Simulation = $outputMapping.Simulation
        Issue = "Missing time or requested-output column"
      }) | Out-Null
      continue
    }

    $startMinute = [double]$outputMapping.StartTime * 60
    $endMinute = $startMinute + ([double]$plot.SimulationDuration * 60)
    $window = @($data | Where-Object {
      [double]$_.$timeColumn -ge $startMinute -and
        [double]$_.$timeColumn -le $endMinute
    })
    if ($window.Count -eq 0) {
      $issues.Add([pscustomobject]@{
        Plot = $plot.Title
        Simulation = $outputMapping.Simulation
        Issue = "No simulated values in $($outputMapping.StartTime)-$($outputMapping.StartTime + $plot.SimulationDuration) h"
      }) | Out-Null
      continue
    }
    if ($isLogarithmic -and -not ($window | Where-Object {
      [double]$_.$outputColumn -gt 0
    })) {
      $issues.Add([pscustomobject]@{
        Plot = $plot.Title
        Simulation = $outputMapping.Simulation
        Issue = "No positive simulated values in logarithmic-plot window"
      }) | Out-Null
    }
  }
}

if ($issues.Count -gt 0) {
  $issues | Sort-Object Plot, Simulation | Format-Table -AutoSize | Out-String -Width 240 |
    Write-Error
  throw "Render-window audit failed with $($issues.Count) issue(s)."
}

Write-Output "Render-window audit passed for all comparison-time-profile mappings."
