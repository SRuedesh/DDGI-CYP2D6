param(
  [Parameter(Mandatory = $true)]
  [string]$ReferenceFolder
)

$ErrorActionPreference = "Stop"
$ddiPath = Join-Path (Resolve-Path -LiteralPath $ReferenceFolder).Path "ObservedData/DDI.csv"
if (-not (Test-Path -LiteralPath $ddiPath -PathType Leaf)) {
  throw "DDI ratio data file was not found: $ddiPath"
}

$rows = @(Import-Csv -LiteralPath $ddiPath)
$ivRows = @($rows | Where-Object { $_.'Route Victim' -eq "IV" })
if ($ivRows.Count -eq 0) {
  throw "No intravenous victim records were found in DDI.csv."
}

foreach ($row in $ivRows) {
  $row.'CmaxR Avg' = ""
  $row.'CmaxR AvgType' = ""
  $row.'CmaxR Var' = ""
  $row.'CmaxR VarType' = ""
}

$csv = $rows | ConvertTo-Csv -NoTypeInformation
[System.IO.File]::WriteAllText(
  $ddiPath,
  ($csv -join "`n") + "`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "Removed observed CMAX ratios from $($ivRows.Count) intravenous victim record(s)."
