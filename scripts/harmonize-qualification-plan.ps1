param(
  [Parameter(Mandatory = $true)]
  [string]$Root
)

$ErrorActionPreference = "Stop"

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$planPath = Join-Path $rootPath "Qualification/Input/qualification_plan.json"
$themePath = Join-Path $rootPath "Qualification/Input/report-theme.json"
$overridesPath = Join-Path $rootPath "Qualification/Input/plot-overrides.json"
$plan = Get-Content -Raw -LiteralPath $planPath | ConvertFrom-Json
$theme = Get-Content -Raw -LiteralPath $themePath | ConvertFrom-Json
$plotOverrides = Get-Content -Raw -LiteralPath $overridesPath | ConvertFrom-Json

$clomipheneSnapshotCommit = "f04a04817bd199810af30a048f994d15719dce10"
$clomipheneProject = $plan.Projects | Where-Object Id -eq "Clomiphene-DGI"
if ($null -eq $clomipheneProject) {
  throw "The Clomiphene-DGI project is missing from the qualification plan."
}
$clomipheneProject.Path =
  "https://raw.githubusercontent.com/SRuedesh/Clomiphene-Model/$clomipheneSnapshotCommit/Clomiphene-Model.json"

$sourceNameReplacements = [ordered]@{
  "Todor (2016) - atomoxetine, 25 mg, po, n=18 (NM)" =
    "Todor (2016) - atomoxetine, 25 mg, po, n=18 (EM)"
  "Sharma 2005 NM, 100 mg tartrate, n=20, AS=1.5" =
    "Sharma 2005 NM, 100 mg tartrate, n=16, AS=1.5"
  "Sharma 2005 NM, metoprolol, 100 mg tartrate, n=20, AS=1.5" =
    "Sharma 2005 NM, metoprolol, 100 mg tartrate, n=16, AS=1.5"
  "Sharma 2005 NM, (R)-metoprolol, 100 mg tartrate, n=20, AS=1.5" =
    "Sharma 2005 NM, (R)-metoprolol, 100 mg tartrate, n=16, AS=1.5"
  "Sharma 2005 NM, (S)-metoprolol, 100 mg tartrate, n=20, AS=1.5" =
    "Sharma 2005 NM, (S)-metoprolol, 100 mg tartrate, n=16, AS=1.5"
  "Sharma 2005 PM, 100 mg tartrate, n=20, AS=0" =
    "Sharma 2005 PM, 100 mg tartrate, n=4, AS=0"
  "Sharma 2005 PM, metoprolol, 100 mg tartrate, n=20, AS=0" =
    "Sharma 2005 PM, metoprolol, 100 mg tartrate, n=4, AS=0"
  "Sharma 2005 PM, (R)-metoprolol, 100 mg tartrate, n=20, AS=0" =
    "Sharma 2005 PM, (R)-metoprolol, 100 mg tartrate, n=4, AS=0"
  "Sharma 2005 PM, (S)-metoprolol, 100 mg tartrate, n=20, AS=0" =
    "Sharma 2005 PM, (S)-metoprolol, 100 mg tartrate, n=4, AS=0"
}
$clomipheneGroups = @(
  [pscustomobject]@{ ActivityScore = "0"; SampleSize = 6 },
  [pscustomobject]@{ ActivityScore = "0.5"; SampleSize = 4 },
  [pscustomobject]@{ ActivityScore = "0.75"; SampleSize = 1 },
  [pscustomobject]@{ ActivityScore = "1"; SampleSize = 2 },
  [pscustomobject]@{ ActivityScore = "2"; SampleSize = 3 },
  [pscustomobject]@{ ActivityScore = "3"; SampleSize = 3 }
)
$clomipheneAnalytes = @(
  "(E)-clomiphene",
  "(E)-4-hydroxyclomiphene",
  "(E)-N-desethylclomiphene",
  "(E)-4-hydroxy-N-desethylclomiphene"
)
foreach ($group in $clomipheneGroups) {
  $activityScore = $group.ActivityScore
  $sampleSize = $group.SampleSize
  $snapshotSimulation =
    "Mürdter (2016) - (E)-clomiphene, 42 mg, po, n=$sampleSize (AS=$activityScore)"
  $sourceNameReplacements["IKP AS=$activityScore, 42 mg po s.d., n=$sampleSize"] =
    $snapshotSimulation
  $sourceNameReplacements["IKP AS=$activityScore, 42 mg po, single dose, n=$sampleSize"] =
    $snapshotSimulation

  foreach ($analyte in $clomipheneAnalytes) {
    $legacyObservedData = "IKP AS=$activityScore, $analyte, 42 mg po s.d."
    $sourceNameReplacements[$legacyObservedData] = "$snapshotSimulation, $analyte"
  }
}
$planJson = $plan | ConvertTo-Json -Depth 100
foreach ($sourceName in $sourceNameReplacements.Keys) {
  $planJson = $planJson.Replace($sourceName, $sourceNameReplacements[$sourceName])
}
$plan = $planJson | ConvertFrom-Json

$controlColor = $theme.aestheticMaps.color[0]
$interactionColor = $theme.aestheticMaps.color[1]
$phenotypeColors = @{
  PM = $theme.aestheticMaps.color[1]
  IM = $theme.aestheticMaps.color[5]
  NM = $theme.aestheticMaps.color[0]
  UM = $theme.aestheticMaps.color[2]
  FM = $theme.aestheticMaps.color[2]
}
$phenotypeSymbols = @{
  PM = "Square"
  IM = "Triangle"
  NM = "Circle"
  UM = "Diamond"
  FM = "Diamond"
}
$conditionPalette = @(
  @("#1F78B4", "#E31A1C"),
  @("#33A02C", "#6A3D9A"),
  @("#FF7F00", "#B15928"),
  @("#A6CEE3", "#FB9A99")
)
$dgiSeriesPalette = @(
  "#1F78B4",
  "#E31A1C",
  "#33A02C",
  "#6A3D9A",
  "#FF7F00",
  "#B15928",
  "#A6CEE3",
  "#FB9A99"
)

function Get-Phenotype {
  param([string]$Text)

  if ($Text -match "(?i)(poor metabolizer|\bPM\b|AS\s*=\s*0(?:\D|$))") {
    return "PM"
  }
  if ($Text -match "(?i)(intermediate metabolizer|\bIM\b|AS\s*=\s*0[.,]5)") {
    return "IM"
  }
  if ($Text -match "(?i)(fast EM|fast NM)") {
    return "FM"
  }
  if ($Text -match "(?i)(ultrarapid metabolizer|\bUM\b|AS\s*=\s*3(?:\D|$))") {
    return "UM"
  }
  return "NM"
}

function Get-Cyp2d6Group {
  param([string]$Text)

  if ($Text -match "(?i)Storelli2018_IM_5mg_DexBase") {
    return "activity score 1"
  }
  if ($Text -match "(?i)(?:^|[^A-Z0-9])10_10(?:[^A-Z0-9]|$)") {
    return "activity score 0"
  }
  if ($Text -match "(?i)(?:^|[^A-Z0-9])WT_10(?:[^A-Z0-9]|$)") {
    return "activity score 1.25"
  }
  if ($Text -match "(?i)(?:^|[^A-Z0-9])WT_WT(?:[^A-Z0-9]|$)") {
    return "activity score 2"
  }
  if ($Text -match "(?i)AS\s*=\s*([0-9]+(?:[.,][0-9]+)?)") {
    return "activity score $($Matches[1] -replace ',', '.')"
  }
  if ($Text -match "(?i)(fast\s+(?:EM|NM)|fast\s+normal metabolizer)") {
    return "fast normal metabolizer"
  }
  if ($Text -match "(?i)(poor metabolizer|(?:^|[^A-Z0-9])PM(?:[^A-Z0-9]|$))") {
    return "poor metabolizer"
  }
  if ($Text -match "(?i)(intermediate metabolizer|(?:^|[^A-Z0-9])IM(?:[^A-Z0-9]|$))") {
    return "intermediate metabolizer"
  }
  if ($Text -match "(?i)(ultrarapid metabolizer|(?:^|[^A-Z0-9])UM(?:[^A-Z0-9]|$))") {
    return "ultrarapid metabolizer"
  }
  if (
    $Text -match
      "(?i)(normal metabolizer|extensive metabolizer|(?:^|[^A-Z0-9])(?:NM|EM)(?:[^A-Z0-9]|$))"
  ) {
    return "normal metabolizer"
  }
  return $null
}

function Get-Cyp2d6Comparison {
  param($Ratio)

  $reference = Get-Cyp2d6Group -Text ([string]$Ratio.SimulationControl.Simulation)
  $variant = Get-Cyp2d6Group -Text ([string]$Ratio.SimulationDDI.Simulation)
  if ([string]::IsNullOrWhiteSpace($reference)) {
    $reference = "reference group"
  }
  if ([string]::IsNullOrWhiteSpace($variant)) {
    $variant = "comparison group"
  }
  return "$variant / $reference"
}

function Get-DdgiComparison {
  param($Ratio)

  $variant = Get-Cyp2d6Group -Text ([string]$Ratio.SimulationControl.Simulation)
  if ([string]::IsNullOrWhiteSpace($variant)) {
    throw "A DDGI ratio mapping has no CYP2D6 group in its control simulation."
  }
  $reference = if ($variant -match "^activity score ") {
    "activity score 2"
  } else {
    "normal metabolizer"
  }
  return "$variant / $reference"
}

function New-OutputMapping {
  param(
    [string]$Simulation,
    [string]$ObservedData,
    [string]$Caption,
    [string]$Project = "Desipramine-DGI",
    [string]$Output = "Organism|PeripheralVenousBlood|Desipramine|Plasma (Peripheral Venous Blood)"
  )

  return [pscustomobject]@{
    Project = $Project
    Simulation = $Simulation
    Output = $Output
    ObservedData = $ObservedData
    StartTime = 0
    TimeUnit = "h"
    Color = $controlColor
    Caption = $Caption
    Symbol = "Circle"
  }
}

if (-not ($plan.Plots.ComparisonTimeProfilePlots.Title -match "^Schadel 1995:")) {
  $schadelPlot = [pscustomobject]@{
    SectionReference = "quinidine-dextromethorphan-ddi-timeprofile"
    Title = "Schadel 1995: Quinidine - Dextromethorphan DDI"
    SimulationDuration = 48
    TimeUnit = "h"
    OutputMappings = @(
      [pscustomobject]@{
        Project = "Quinidine-Dextromethorphan-DDI"
        Simulation = "Schadel (1995) - dextromethorphan hydrobromide, 30 mg, po, n=5 (EM)"
        Output = "Organism|PeripheralVenousBlood|Dextrorphan-O-glucuronide|Plasma (Peripheral Venous Blood)"
        ObservedData = "Schadel (1995) - dextromethorphan hydrobromide, 30 mg, po, n=5 (EM), dextrorphan-O-glucuronide"
        StartTime = 0
        TimeUnit = "h"
        Color = $controlColor
        Caption = "Schadel 1995, dextrorphan O-glucuronide, control"
        Symbol = "Triangle"
      },
      [pscustomobject]@{
        Project = "Quinidine-Dextromethorphan-DDI"
        Simulation = "Schadel (1995) - DDI - quinidine-dextromethorphan, 100/30 mg, po, n=5 (EM)"
        Output = "Organism|PeripheralVenousBlood|Dextrorphan-O-glucuronide|Plasma (Peripheral Venous Blood)"
        ObservedData = "Schadel (1995) - DDI - quinidine-dextromethorphan, 100/30 mg, po, n=5 (EM), dextrorphan-O-glucuronide"
        StartTime = 12
        TimeUnit = "h"
        Color = $interactionColor
        Caption = "Schadel 1995, dextrorphan O-glucuronide, + quinidine"
        Symbol = "Triangle"
      },
      [pscustomobject]@{
        Project = "Quinidine-Dextromethorphan-DDI"
        Simulation = "Schadel (1995) - DDI - quinidine-dextromethorphan, 100/30 mg, po, n=5 (EM)"
        Output = "Organism|PeripheralVenousBlood|Dextromethorphan|Plasma (Peripheral Venous Blood)"
        ObservedData = "Schadel (1995) - DDI - quinidine-dextromethorphan, 100/30 mg, po, n=5 (EM), dextromethorphan"
        StartTime = 12
        TimeUnit = "h"
        Color = $interactionColor
        Caption = "Schadel 1995, dextromethorphan, + quinidine"
        Symbol = "Circle"
      }
    )
  }
  $plan.Plots.ComparisonTimeProfilePlots += $schadelPlot
}

if (-not ($plan.Plots.ComparisonTimeProfilePlots.SectionReference -contains "desipramine-dgi-timeprofile")) {
  $desipraminePlots = @(
    [pscustomobject]@{
      SectionReference = "desipramine-dgi-timeprofile"
      Title = "Brøsen 1986: Desipramine DGI"
      SimulationDuration = 500
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Simulation "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (PM)" -ObservedData "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (PM), desipramine" -Caption "Brøsen 1986, PM"),
        (New-OutputMapping -Simulation "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (EM)" -ObservedData "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (EM), desipramine" -Caption "Brøsen 1986, NM"),
        (New-OutputMapping -Simulation "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (fast EM)" -ObservedData "Brøsen (1986) - desipramine hydrochloride, po, 100 mg, n=6 (fast EM), desipramine" -Caption "Brøsen 1986, fast NM")
      )
    },
    [pscustomobject]@{
      SectionReference = "desipramine-dgi-timeprofile"
      Title = "Brøsen 1988: Desipramine DGI"
      SimulationDuration = 433
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Simulation "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=3 (PM)" -ObservedData "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=3 (PM), desipramine" -Caption "Brøsen 1988, PM"),
        (New-OutputMapping -Simulation "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=4 (EM)" -ObservedData "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=4 (EM), desipramine" -Caption "Brøsen 1988, NM"),
        (New-OutputMapping -Simulation "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=4 (fast EM)" -ObservedData "Brøsen (1988) - desipramine hydrochloride, iv, 50 mg, n=4 (fast EM), desipramine" -Caption "Brøsen 1988, fast NM")
      )
    },
    [pscustomobject]@{
      SectionReference = "desipramine-dgi-timeprofile"
      Title = "Spina 1987: Desipramine DGI"
      SimulationDuration = 100
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Simulation "Spina (1987) - desipramine hydrochloride, po, 25 mg, n=6 (PM)" -ObservedData "Spina (1987) - desipramine hydrochloride, po, 25 mg, n=6 (PM), desipramine" -Caption "Spina 1987, PM"),
        (New-OutputMapping -Simulation "Spina (1987) - desipramine hydrochloride, po, 25 mg, n=8 (EM)" -ObservedData "Spina (1987) - desipramine hydrochloride, po, 25 mg, n=8 (EM), desipramine" -Caption "Spina 1987, NM")
      )
    }
  )
  $plan.Plots.ComparisonTimeProfilePlots += $desipraminePlots
}

if (-not ($plan.Plots.ComparisonTimeProfilePlots.SectionReference -contains "paroxetine-dgi-timeprofile")) {
  $paroxetineOutput = "Organism|PeripheralVenousBlood|Paroxetine|Plasma (Peripheral Venous Blood)"
  $paroxetinePlots = @(
    [pscustomobject]@{
      SectionReference = "paroxetine-dgi-timeprofile"
      Title = "Sindrup 1992: Paroxetine DGI"
      SimulationDuration = 456
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Sindrup (1992) - paroxetine hydrochloride, 30 mg, po, md, n=8 (PM)" -ObservedData "Sindrup (1992) - paroxetine hydrochloride, 30 mg, po, md, n=8 (PM), paroxetine (last dose)" -Caption "Sindrup 1992, PM, last dose"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Sindrup (1992) - paroxetine hydrochloride, 30 mg, po, md, n=9 (EM)" -ObservedData "Sindrup (1992) - paroxetine hydrochloride, 30 mg, po, md, n=9 (EM), paroxetine (last dose)" -Caption "Sindrup 1992, NM, last dose")
      )
    },
    [pscustomobject]@{
      SectionReference = "paroxetine-dgi-timeprofile"
      Title = "Chen 2015: Paroxetine DGI"
      SimulationDuration = 120
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=4 (AS=0.5)" -ObservedData "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=4 (AS=0.5), paroxetine" -Caption "Chen 2015, AS=0.5, n=4"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=11 (AS=1)" -ObservedData "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=11 (AS=1), paroxetine" -Caption "Chen 2015, AS=1, n=11"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=5 (AS=1.5)" -ObservedData "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=5 (AS=1.5), paroxetine" -Caption "Chen 2015, AS=1.5, n=5"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=4 (AS=2)" -ObservedData "Chen (2015) - paroxetine hydrochloride, 25 mg, po, n=4 (AS=2), paroxetine" -Caption "Chen 2015, AS=2, n=4")
      )
    },
    [pscustomobject]@{
      SectionReference = "paroxetine-dgi-timeprofile"
      Title = "Mürdter 2016: Paroxetine DGI"
      SimulationDuration = 270
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=0)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=0), paroxetine" -Caption "Mürdter 2016, AS=0, n=3"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=4 (AS=0.5)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=4 (AS=0.5), paroxetine" -Caption "Mürdter 2016, AS=0.5, n=4"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=1 (AS=0.75)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=1 (AS=0.75), paroxetine" -Caption "Mürdter 2016, AS=0.75, n=1"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=2 (AS=1)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=2 (AS=1), paroxetine" -Caption "Mürdter 2016, AS=1, n=2"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=2)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=2), paroxetine" -Caption "Mürdter 2016, AS=2, n=3"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=3)" -ObservedData "Mürdter (2016) - paroxetine hydrochloride, 40 mg, po, md, n=3 (AS=3), paroxetine" -Caption "Mürdter 2016, AS=3, n=3")
      )
    },
    [pscustomobject]@{
      SectionReference = "paroxetine-dgi-timeprofile"
      Title = "Yoon 2000: Paroxetine DGI"
      SimulationDuration = 300
      TimeUnit = "h"
      OutputMappings = @(
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=1 (AS=0)" -ObservedData "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=1 (AS=0), paroxetine" -Caption "Yoon 2000, AS=0, n=1"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=3 (AS=0.5)" -ObservedData "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=3 (AS=0.5), paroxetine" -Caption "Yoon 2000, AS=0.5, n=3"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=6 (AS=1.25)" -ObservedData "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=6 (AS=1.25), paroxetine" -Caption "Yoon 2000, AS=1.25, n=6"),
        (New-OutputMapping -Project "Paroxetine-DGI" -Output $paroxetineOutput -Simulation "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=6 (AS=2)" -ObservedData "Yoon (2000) - paroxetine hydrochloride, 40 mg, po, n=6 (AS=2), paroxetine" -Caption "Yoon 2000, AS=2, n=6")
      )
    }
  )
  $plan.Plots.ComparisonTimeProfilePlots += $paroxetinePlots
}

function Add-DgiProfileIfMissing {
  param(
    [string]$SectionReference,
    [string]$Title,
    [double]$SimulationDuration,
    [object[]]$OutputMappings
  )

  if ($plan.Plots.ComparisonTimeProfilePlots.Title -contains $Title) {
    return
  }
  $plan.Plots.ComparisonTimeProfilePlots += [pscustomobject]@{
    SectionReference = $SectionReference
    Title = $Title
    SimulationDuration = $SimulationDuration
    TimeUnit = "h"
    OutputMappings = $OutputMappings
  }
}

$desipramineOutput =
  "Organism|PeripheralVenousBlood|Desipramine|Plasma (Peripheral Venous Blood)"
$hydroxydesipramineOutput =
  "Organism|PeripheralVenousBlood|2-Hydroxydesipramine|Plasma (Peripheral Venous Blood)"
$bergmannMappings = @()
foreach ($activityScore in @("2", "2.5")) {
  $simulation =
    "Bergmann (2001) - desipramine hydrochloride, po, 100 mg, n=6 (AS=$activityScore)"
  $bergmannMappings += New-OutputMapping `
    -Project "Desipramine-DGI" `
    -Output $desipramineOutput `
    -Simulation $simulation `
    -ObservedData "$simulation, desipramine" `
    -Caption "Bergmann 2001, AS=$activityScore"
}
Add-DgiProfileIfMissing `
  -SectionReference "desipramine-dgi-timeprofile" `
  -Title "Bergmann 2001: Desipramine DGI" `
  -SimulationDuration 15 `
  -OutputMappings $bergmannMappings

$bergmannMetaboliteMappings = @()
foreach ($activityScore in @("2", "2.5")) {
  $simulation =
    "Bergmann (2001) - desipramine hydrochloride, po, 100 mg, n=6 (AS=$activityScore)"
  $bergmannMetaboliteMappings += New-OutputMapping `
    -Project "Desipramine-DGI" `
    -Output $hydroxydesipramineOutput `
    -Simulation $simulation `
    -ObservedData "$simulation, 2-hydroxydesipramine" `
    -Caption "Bergmann 2001, 2-hydroxydesipramine, AS=$activityScore"
}
Add-DgiProfileIfMissing `
  -SectionReference "desipramine-dgi-timeprofile" `
  -Title "Bergmann 2001: 2-Hydroxydesipramine DGI" `
  -SimulationDuration 25 `
  -OutputMappings $bergmannMetaboliteMappings

$brosenMappings = @()
foreach ($group in @(
  [pscustomobject]@{ n = "5"; source = "EM"; label = "NM" }
  [pscustomobject]@{ n = "8"; source = "PM"; label = "PM" }
  [pscustomobject]@{ n = "4"; source = "fast EM"; label = "fast NM" }
)) {
  $simulation =
    "Brosen (1993) - desipramine hydrochloride, po, 100 mg, n=$($group.n) ($($group.source))"
  $brosenMappings += New-OutputMapping `
    -Project "Paroxetine-Desipramine-DDGI" `
    -Output $desipramineOutput `
    -Simulation $simulation `
    -ObservedData "$simulation, desipramine" `
    -Caption "Brøsen 1993, $($group.label), n=$($group.n)"
}
Add-DgiProfileIfMissing `
  -SectionReference "desipramine-dgi-timeprofile" `
  -Title "Brøsen 1993: Desipramine DGI" `
  -SimulationDuration 241 `
  -OutputMappings $brosenMappings

$labbeMappings = @()
foreach ($phenotype in @("EM", "PM")) {
  $simulation =
    "Labbé (2000) - mexiletine, 100 mg b.i.d. po, n=1 ($phenotype) prediction"
  $labbeMapping = New-OutputMapping `
    -Project "Mexiletine-DGI" `
    -Output "Organism|PeripheralVenousBlood|Mexiletine|Plasma (Peripheral Venous Blood)" `
    -Simulation $simulation `
    -ObservedData "Labbe2000.Mexiletine.m/f.83.31.po.$phenotype" `
    -Caption "Labbé 2000, $($phenotype -replace 'EM', 'NM')"
  $labbeMapping.StartTime = 72
  $labbeMappings += $labbeMapping
}
Add-DgiProfileIfMissing `
  -SectionReference "mexiletine-dgi-timeprofile" `
  -Title "Labbé 2000: Mexiletine DGI" `
  -SimulationDuration 13 `
  -OutputMappings $labbeMappings

$leemannMappings = @()
foreach ($group in @(
  [pscustomobject]@{ n = "4"; source = "EM"; label = "NM" }
  [pscustomobject]@{ n = "3"; source = "PM"; label = "PM" }
)) {
  $simulation =
    "Leemann (1993) - metoprolol tartrate 20 mg, iv, n=$($group.n) ($($group.source))"
  $leemannMappings += New-OutputMapping `
    -Project "Quinidine-Metoprolol-DDGI" `
    -Output "Organism|PeripheralVenousBlood|Metoprolol racemate|Metoprolol racemate Observer" `
    -Simulation $simulation `
    -ObservedData "$simulation, metoprolol" `
    -Caption "Leemann 1993, $($group.label), n=$($group.n)"
}
Add-DgiProfileIfMissing `
  -SectionReference "metoprolol-dgi-timeprofile" `
  -Title "Leemann 1993: Metoprolol DGI" `
  -SimulationDuration 9 `
  -OutputMappings $leemannMappings

$todorMappings = @()
foreach ($group in @(
  [pscustomobject]@{ n = "18"; source = "EM"; label = "NM" }
  [pscustomobject]@{ n = "2"; source = "PM"; label = "PM" }
)) {
  $simulation =
    "Todor (2016) - atomoxetine, 25 mg, po, n=$($group.n) ($($group.source))"
  $todorMappings += New-OutputMapping `
    -Project "Atomoxetine-DGI" `
    -Output "Organism|PeripheralVenousBlood|Atomoxetine|Plasma (Peripheral Venous Blood)" `
    -Simulation $simulation `
    -ObservedData "$simulation, atomoxetine" `
    -Caption "Todor 2016, $($group.label), n=$($group.n)"
}
Add-DgiProfileIfMissing `
  -SectionReference "atomoxetine-dgi-timeprofile" `
  -Title "Todor 2016: Atomoxetine DGI" `
  -SimulationDuration 50 `
  -OutputMappings $todorMappings

$jungMappings = @()
foreach ($sourcePlot in $plan.Plots.ComparisonTimeProfilePlots | Where-Object {
  $_.SectionReference -eq "paroxetine-atomoxetine-ddgi-timeprofile" -and
    ($_.OutputMappings.ObservedData -join " ") -match "^Jung 2020"
}) {
  $controlMapping = $sourcePlot.OutputMappings | Where-Object {
    [string]$_.ObservedData -match "^Jung 2020" -and
      [string]$_.ObservedData -notmatch "DDI"
  } | Select-Object -First 1
  if ($null -ne $controlMapping) {
    $jungMappings += $controlMapping.PSObject.Copy()
  }
}
Add-DgiProfileIfMissing `
  -SectionReference "atomoxetine-dgi-timeprofile" `
  -Title "Jung 2020: Atomoxetine DGI" `
  -SimulationDuration 25 `
  -OutputMappings $jungMappings

$sauerMappings = @()
foreach ($group in @(
  [pscustomobject]@{ n = "4"; source = "EM"; label = "NM" }
  [pscustomobject]@{ n = "3"; source = "PM"; label = "PM" }
)) {
  $simulation =
    "Sauer (2003) - atomoxetine, 20 mg b.i.d., po, n=$($group.n) ($($group.source))"
  $sauerMapping = New-OutputMapping `
    -Project "Atomoxetine-DGI" `
    -Output "Organism|PeripheralVenousBlood|Atomoxetine|Plasma (Peripheral Venous Blood)" `
    -Simulation $simulation `
    -ObservedData "$simulation, atomoxetine" `
    -Caption "Sauer 2003, $($group.label), n=$($group.n)"
  $sauerMapping.StartTime = 108
  $sauerMappings += $sauerMapping
}
Add-DgiProfileIfMissing `
  -SectionReference "atomoxetine-dgi-timeprofile" `
  -Title "Sauer 2003: Atomoxetine DGI" `
  -SimulationDuration 205 `
  -OutputMappings $sauerMappings

$bondolfiMappings = @()
foreach ($group in @(
  [pscustomobject]@{ n = "8"; source = "EM"; label = "NM" }
  [pscustomobject]@{ n = "2"; source = "PM"; label = "PM" }
)) {
  $simulation =
    "Bondolfi (2002) - risperidone, 2 mg, po, md, n=$($group.n) ($($group.source))"
  $bondolfiMapping = New-OutputMapping `
    -Project "Risperidone-DGI" `
    -Output "Organism|PeripheralVenousBlood|Risperidone|Plasma (Peripheral Venous Blood)" `
    -Simulation $simulation `
    -ObservedData "$simulation, risperidone" `
    -Caption "Bondolfi 2002, $($group.label), n=$($group.n)"
  $bondolfiMapping.StartTime = 72
  $bondolfiMappings += $bondolfiMapping
}
Add-DgiProfileIfMissing `
  -SectionReference "risperidone-dgi-timeprofile" `
  -Title "Bondolfi 2002: Risperidone DGI" `
  -SimulationDuration 49 `
  -OutputMappings $bondolfiMappings

$yamazakiMappings = @()
foreach ($group in @(
  [pscustomobject]@{ simulation = "Yamazaki2017_NM_30mg_DexHBr_AS=2"; label = "NM, AS=2, n=11" }
  [pscustomobject]@{ simulation = "Yamazaki2017_IM_30mg_DexHBr_AS=0.5"; label = "IM, AS=0.5, n=12" }
)) {
  $yamazakiMappings += New-OutputMapping `
    -Project "Dextromethorphan-DGI" `
    -Output "Organism|PeripheralVenousBlood|Dextromethorphan|Plasma (Peripheral Venous Blood)" `
    -Simulation $group.simulation `
    -ObservedData $group.simulation `
    -Caption "Yamazaki 2017, $($group.label)"
}
Add-DgiProfileIfMissing `
  -SectionReference "dextromethorphan-dgi-timeprofile" `
  -Title "Yamazaki 2017: Dextromethorphan DGI - Dextromethorphan" `
  -SimulationDuration 25 `
  -OutputMappings $yamazakiMappings

$plan.Plots.ComparisonTimeProfilePlots = @(
  $plan.Plots.ComparisonTimeProfilePlots |
    Where-Object Title -ne "Schoedel 2012: Paroxetine DGI"
)

$combinedDgiPlots = [ordered]@{}
$otherComparisonPlots = [System.Collections.Generic.List[object]]::new()
foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  if ([string]$plot.SectionReference -notmatch "-dgi-timeprofile$") {
    $otherComparisonPlots.Add($plot)
    continue
  }

  $key = "$($plot.SectionReference)`n$($plot.Title)"
  if (-not $combinedDgiPlots.Contains($key)) {
    $combinedDgiPlots[$key] = $plot
    continue
  }

  $target = $combinedDgiPlots[$key]
  $existingMappings = @{}
  foreach ($mapping in $target.OutputMappings) {
    $mappingKey = @(
      [string]$mapping.Project,
      [string]$mapping.Simulation,
      [string]$mapping.Output,
      [string]$mapping.ObservedData
    ) -join "|"
    $existingMappings[$mappingKey] = $true
  }
  foreach ($mapping in $plot.OutputMappings) {
    $mappingKey = @(
      [string]$mapping.Project,
      [string]$mapping.Simulation,
      [string]$mapping.Output,
      [string]$mapping.ObservedData
    ) -join "|"
    if (-not $existingMappings.ContainsKey($mappingKey)) {
      $target.OutputMappings += $mapping
      $existingMappings[$mappingKey] = $true
    }
  }
  $target.SimulationDuration = [math]::Max(
    [double]$target.SimulationDuration,
    [double]$plot.SimulationDuration
  )
}
$plan.Plots.ComparisonTimeProfilePlots = @(
  $otherComparisonPlots + @($combinedDgiPlots.Values)
)

foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  $plot.Title = ([string]$plot.Title) -replace "Kovar 2022", "Mürdter 2016"
  $plot.Title = ([string]$plot.Title) -replace " DDGI", " DDI"
  if (
    [string]$plot.Title -match
      "^(?<study>.+?): (?<scenario>.+?) - \k<study>$"
  ) {
    $plot.Title = "$($Matches.study): $($Matches.scenario)"
  }
  foreach ($mapping in $plot.OutputMappings) {
    $mapping.Caption = ([string]$mapping.Caption) -replace "Kovar 2022", "Mürdter 2016"
  }

  if ($plot.SectionReference -eq "atomoxetine-midazolam-ddi-timeprofile") {
    $period = if (($plot.OutputMappings.ObservedData -join " ") -match "day 12") { "12" } else { "6" }
    $windowStart = if ($period -eq "12") { 264 } else { 120 }
    $plot.Title = "Sauer 2004, day ${period}: Atomoxetine - Midazolam DDI"
    $plot.SimulationDuration = 8
    foreach ($mapping in $plot.OutputMappings) {
      $mapping.StartTime = $windowStart
    }
    $plot.OutputMappings[0].Simulation = "Sauer 2004 - Midazolam, po, 5 mg, sd, day 6 and day 12, n=8"
    $plot.OutputMappings[0].ObservedData = "Sauer 2004 - Midazolam, po, 5 mg, sd, day $period"
    $plot.OutputMappings[0].Caption = "Sauer 2004, MID (5 mg s.d. po), n = 8 PM"
    $plot.OutputMappings[1].Caption = "Sauer 2004, MID (+ ATO, 60 mg b.i.d. po), n = 8 PM"
    $xAxis = $plot.Axes | Where-Object Type -eq "X"
    $xAxis.Min = 0
    $xAxis.Max = 8
  }

  if ($plot.SectionReference -eq "quinidine-paroxetine-ddi-timeprofile") {
    $plot.Title = "Schoedel 2012: Quinidine - Paroxetine DDI"
    foreach ($mapping in $plot.OutputMappings) {
      if ($mapping.ObservedData -match "\(control\)") {
        $mapping.StartTime = 264
        $mapping.Caption = "Schoedel 2012, PAR, control"
      } else {
        $mapping.StartTime = 456
        $mapping.Caption = "Schoedel 2012, PAR (+ QUI/DEX)"
      }
    }
  }

  if (
    $plot.SectionReference -eq "paroxetine-atomoxetine-ddgi-timeprofile" -and
    ($plot.OutputMappings.ObservedData -join " ") -match "^Belle 2002"
  ) {
    $plot.Title = "Belle 2002: Paroxetine - Atomoxetine DDI"
    $plot.SimulationDuration = 120
    $plot.OutputMappings[0].StartTime = 72
    $plot.OutputMappings[1].StartTime = 360
  }

  if (
    $plot.SectionReference -eq "paroxetine-dextromethorphan-ddgi-timeprofile" -and
    ($plot.OutputMappings.ObservedData -join " ") -match "Schoedel \(2012\)"
  ) {
    $plot.Title = "Schoedel 2012: Paroxetine + Quinidine - Dextromethorphan"
    $plot.SimulationDuration = 36
    $plot.OutputMappings[0].StartTime = 156
    $plot.OutputMappings[0].Caption =
      "Schoedel 2012, DEX (+ QUI, 30 mg b.i.d. po), n = 13"
    $plot.OutputMappings[1].StartTime = 444
    $plot.OutputMappings[1].Caption =
      "Schoedel 2012, DEX (+ QUI and PAR, 20 mg q.d. po), n = 13"
  }

  if (
    $plot.SectionReference -eq "paroxetine-atomoxetine-ddgi-timeprofile" -and
    ($plot.OutputMappings.ObservedData -join " ") -match "^Jung 2020"
  ) {
    $plot.Title = "Jung 2020: Paroxetine - Atomoxetine DDI"
    $plot.SimulationDuration = 168
    $plot.OutputMappings[0].StartTime = 0
    $plot.OutputMappings[1].StartTime = 144
  }

  if (
    $plot.SectionReference -eq "paroxetine-atomoxetine-ddgi-timeprofile" -and
    ($plot.OutputMappings.ObservedData -join " ") -match "^Todor 2015"
  ) {
    $plot.Title = "Todor 2015: Paroxetine - Atomoxetine DDI"
    $plot.SimulationDuration = 48
    $plot.OutputMappings[0].StartTime = 0
    $plot.OutputMappings[1].StartTime = 120
  }

  if (
    $plot.SectionReference -eq "paroxetine-dextromethorphan-ddgi-timeprofile" -and
    ($plot.OutputMappings.ObservedData -join " ") -match "^Storelli 2018"
  ) {
    $isIntermediate = ($plot.OutputMappings.ObservedData -join " ") -match " IM "
    $phenotype = if ($isIntermediate) { "IM" } else { "NM" }
    $sampleSize = if ($isIntermediate) { 16 } else { 17 }
    $plot.Title = "Storelli 2018: Paroxetine - Dextromethorphan DDI"
    $plot.SimulationDuration = 37
    $plot.OutputMappings[0].StartTime = 144
    $plot.OutputMappings[0].Caption =
      "Storelli 2018, DEX (5 mg s.d. po), n = $sampleSize $phenotype"
    $plot.OutputMappings[1].StartTime = 456
    $plot.OutputMappings[1].Caption =
      "Storelli 2018, DEX (+ PAR, 20 mg b.i.d. po), n = $sampleSize $phenotype"
  }

  if ($plot.SectionReference -eq "rifampicin-metoprolol-ddi-timeprofile") {
    $plot.SimulationDuration = 13
    $plot.OutputMappings[0].StartTime = 48
    $plot.OutputMappings[1].StartTime = 408
  }

  if ($plot.Title -eq "Sindrup 1992: Paroxetine DGI") {
    $plot.SimulationDuration = 124
    foreach ($mapping in $plot.OutputMappings) {
      $mapping.StartTime = 336
    }
  }

  if ($plot.Title -eq "Mürdter 2016: Paroxetine DGI") {
    $plot.SimulationDuration = 172
    foreach ($mapping in $plot.OutputMappings) {
      $mapping.StartTime = 48
    }
  }

  if ($plot.Title -eq "Yoon 2000: Paroxetine DGI") {
    $plot.SimulationDuration = 246
  }

  $firstCaption = [string]$plot.OutputMappings[0].Caption
  if ($firstCaption -match "^([^,]+(?:\s+\d{4}[a-z]?))") {
    $study = $Matches[1]
    if (-not ([string]$plot.Title -match "^$([regex]::Escape($study))[:,]")) {
      $plot.Title = "${study}: $($plot.Title)"
    }
  }

  $outputKeys = @($plot.OutputMappings | ForEach-Object { [string]$_.Output } | Select-Object -Unique)
  $seenOutputCount = @{}
  $dgiMappingIndex = 0
  foreach ($mapping in $plot.OutputMappings) {
    $mappingText = "$($mapping.Simulation) $($mapping.Caption)"
    $outputKey = [string]$mapping.Output
    $outputIndex = [Array]::IndexOf($outputKeys, $outputKey) % $conditionPalette.Count
    $mappingIndex = $seenOutputCount[$outputKey] ?? 0
    $mappingCount = @($plot.OutputMappings | Where-Object { $_.Output -eq $outputKey }).Count
    $isInteraction = if ($mappingCount -gt 1) {
      $mappingIndex -gt 0
    } else {
      $mappingText -match "(?i)\bDDI\b|\+\s*(?:quinidine|paroxetine|fluvoxamine|itraconazole|erythromycin|rifampicin|cimetidine|verapamil|ketoconazole|carbamazepine)"
    }
    $seenOutputCount[$outputKey] = ($seenOutputCount[$outputKey] ?? 0) + 1
    if (
      $plot.SectionReference -notmatch "-dgi-timeprofile$" -and
      (
        $mapping.ObservedData -match "(?i)\(control\)" -or
        $mapping.Caption -match "(?i)control"
      )
    ) {
      $mapping.Color = $conditionPalette[$outputIndex][0]
      continue
    }

    if ($plot.SectionReference -match "-dgi-timeprofile$") {
      $phenotype = Get-Phenotype -Text $mappingText
      $mapping.Color = $dgiSeriesPalette[$dgiMappingIndex % $dgiSeriesPalette.Count]
      $dgiMappingIndex++
      $mapping.Symbol = $phenotypeSymbols[$phenotype]

      $captionPhenotypes = @(
        [regex]::Matches(
          [string]$mapping.Caption,
          "(?i)\b(?:PM|NM|EM|IM|UM|FM)\b"
        ) | ForEach-Object Value
      )
      if ($captionPhenotypes.Count -gt 1) {
        $caption = ([string]$mapping.Caption) -replace "(?i)(?:,\s*)?\b(?:PM|NM|EM|IM|UM|FM)\b", ""
        $caption = ($caption -replace "\s*,\s*,", ",").Trim(" ", ",")
        if ($caption -match "^(?<study>.+?\d{4}[a-z]?)(?<rest>.*)$") {
          $study = $Matches.study
          $rest = $Matches.rest.Trim(" ", ",")
          $mapping.Caption = if ($rest) {
            "$study, $phenotype, $rest"
          } else {
            "$study, $phenotype"
          }
        } else {
          $mapping.Caption = "$caption, $phenotype"
        }
      }
      continue
    }

    $conditionIndex = if ($isInteraction) { 1 } else { 0 }
    $mapping.Color = $conditionPalette[$outputIndex][$conditionIndex]
  }

  if ($plot.Title -eq "Storelli 2018: Paroxetine - Dextromethorphan DDI") {
    foreach ($mapping in $plot.OutputMappings) {
      $mapping.StartTime = if ($mapping.Simulation -match " - DDI - ") { 12 } else { 0 }
    }
  }
}

# Keep condition labels independent of the study and dose. Start each label
# with the plotted compound so that multi-analyte profiles remain unambiguous.
function Get-ProfileCompound {
  param($Mapping)

  $outputParts = [string]$Mapping.Output -split "\|"
  if ($outputParts.Count -lt 3 -or [string]::IsNullOrWhiteSpace($outputParts[2])) {
    throw "A concentration-time mapping has no compound in its output path."
  }
  $compound = $outputParts[2]
  if ($compound -eq "alpha-Hydroxymetoprolol") {
    return "α-hydroxymetoprolol"
  }
  return $compound
}

foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  if ([string]$plot.SectionReference -match "-dgi-timeprofile$") {
    $groupLabels = @(
      $plot.OutputMappings |
        ForEach-Object {
          Get-Cyp2d6Group -Text "$($_.Simulation) $($_.ObservedData) $($_.Caption)"
        }
    )
    $referenceLabel = if ($groupLabels -contains "activity score 2") {
      "activity score 2"
    } elseif ($groupLabels -contains "normal metabolizer") {
      "normal metabolizer"
    } else {
      @($groupLabels | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[0]
    }

    for ($mappingIndex = 0; $mappingIndex -lt $plot.OutputMappings.Count; $mappingIndex++) {
      $label = $groupLabels[$mappingIndex]
      if ([string]::IsNullOrWhiteSpace($label)) {
        $label = "unspecified CYP2D6 group"
      }
      $condition = if ($label -eq $referenceLabel) { "Control" } else { "Comparison" }
      $compound = Get-ProfileCompound -Mapping $plot.OutputMappings[$mappingIndex]
      $plot.OutputMappings[$mappingIndex].Caption = "$compound $condition ($label)"
    }
    continue
  }

  if ([string]$plot.SectionReference -notmatch "-(?:ddi|ddgi)-timeprofile$") {
    continue
  }

  $seenOutputs = @{}
  foreach ($mapping in $plot.OutputMappings) {
    $output = [string]$mapping.Output
    $outputPosition = $seenOutputs[$output] ?? 0
    $outputMappings = @($plot.OutputMappings | Where-Object Output -eq $output)
    $outputCount = $outputMappings.Count
    $simulationText = [string]$mapping.Simulation
    $observedDataText = [string]$mapping.ObservedData
    $captionText = [string]$mapping.Caption
    $treatmentPattern = "(?i)\(DDI\)|\bDDI\b|DD\(G\)I"
    $controlPattern = "(?i)\(control\)|\bcontrol\b"
    $outputHasExplicitSimulationTreatment = @(
      $outputMappings | Where-Object {
        [string]$_.Simulation -match $treatmentPattern
      }
    ).Count -gt 0
    $isTreatment = if ($simulationText -match $controlPattern) {
      $false
    } elseif ($outputHasExplicitSimulationTreatment) {
      $simulationText -match $treatmentPattern
    } elseif ($simulationText -match $treatmentPattern) {
      $true
    } elseif ($observedDataText -match $controlPattern) {
      $false
    } elseif ($captionText -match $controlPattern) {
      $false
    } elseif ($captionText -match "(?i)\btreatment\b") {
      $true
    } elseif ($observedDataText -match $treatmentPattern -and $outputCount -eq 1) {
      $true
    } else {
      $outputCount -gt 1 -and $outputPosition -gt 0
    }
    $seenOutputs[$output] = $outputPosition + 1

    $projectParts = ([string]$mapping.Project -replace "-DDGI?$", "") -split "-"
    $perpetrator = $projectParts[0]
    $compound = Get-ProfileCompound -Mapping $mapping
    $cyp2d6Group = Get-Cyp2d6Group -Text "$simulationText $observedDataText"
    $groupSuffix = if ([string]::IsNullOrWhiteSpace($cyp2d6Group)) {
      ""
    } else {
      "; $cyp2d6Group"
    }
    $mapping.Caption = if ($isTreatment) {
      "$compound Treatment (with $perpetrator$groupSuffix)"
    } else {
      "$compound Control (without $perpetrator$groupSuffix)"
    }
  }
}

foreach ($override in $plotOverrides) {
  $matchingPlots = @($plan.Plots.ComparisonTimeProfilePlots | Where-Object {
    $_.Title -match $override.titleRegex -and
      ($null -eq $override.observedDataRegex -or
        ($_.OutputMappings.ObservedData -join " ") -match $override.observedDataRegex)
  })
  if ($matchingPlots.Count -eq 0) {
    throw "No comparison-time-profile plot matched override: $($override.titleRegex)"
  }

  foreach ($plot in $matchingPlots) {
    if ($null -ne $override.duration) {
      $plot.SimulationDuration = $override.duration
    }

    $xAxis = [pscustomobject]@{
      Type = "X"
      Dimension = "Time"
      Unit = "h"
      GridLines = $false
      Scaling = "Linear"
    }
    $yAxis = [pscustomobject]@{
      Type = "Y"
      Dimension = "Concentration (mass)"
      Unit = "µg/l"
      GridLines = $false
      Scaling = $override.scaling ?? "Log"
    }
    if ($null -ne $override.xMin) {
      $xAxis | Add-Member -NotePropertyName Min -NotePropertyValue $override.xMin
    }
    if ($null -ne $override.xMax) {
      $xAxis | Add-Member -NotePropertyName Max -NotePropertyValue $override.xMax
    }
    if ($null -ne $override.yMin) {
      $yAxis | Add-Member -NotePropertyName Min -NotePropertyValue $override.yMin
    }
    if ($null -ne $override.yMax) {
      $yAxis | Add-Member -NotePropertyName Max -NotePropertyValue $override.yMax
    }
    $plot | Add-Member -Force Axes @($xAxis, $yAxis)
  }
}

function Get-RatioKey {
  param([string]$Caption)

  return $Caption -replace "^[^,]*\d{4}[a-z]?,\s*", ""
}

$studyBySimulation = @{}
foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  if ($plot.Title -match "^(.+?\d{4}[a-z]?):") {
    $study = $Matches[1]
    foreach ($mapping in $plot.OutputMappings) {
      $studyBySimulation[[string]$mapping.Simulation] = $study
    }
  }
}

$ratioGroups = @($plan.Plots.DDIRatioPlots.Groups)
foreach ($group in $ratioGroups) {
  $group.Caption = ([string]$group.Caption) -replace "Kovar 2022", "Mürdter 2016"
}
$ratioKeys = @(
  $ratioGroups |
    ForEach-Object { Get-RatioKey -Caption ([string]$_.Caption) } |
    Sort-Object -Unique
)
$ratioPalette = @($theme.aestheticMaps.color)[0..5]
foreach ($group in $ratioGroups) {
  $key = Get-RatioKey -Caption ([string]$group.Caption)
  $colorIndex = [Array]::IndexOf($ratioKeys, $key) % $ratioPalette.Count
  $group.Color = $ratioPalette[$colorIndex]

  $controlSimulation = [string]$group.DDIRatios[0].SimulationControl.Simulation
  if ($studyBySimulation.ContainsKey($controlSimulation)) {
    $study = $studyBySimulation[$controlSimulation]
    if (-not $key.StartsWith("${study},")) {
      $group.Caption = "${study}, $key"
    }
  } elseif ($controlSimulation -match "^(.+?)\s*\(?(\d{4}[a-z]?)\)?(?:\s|\s*-)") {
    $study = "$($Matches[1].Trim()) $($Matches[2])"
    if (-not $key.StartsWith("${study},")) {
      $group.Caption = "${study}, $key"
    }
  }
}

foreach ($group in $ratioGroups) {
  $ratio = $group.DDIRatios[0]
  $outputCompound = ([string]$ratio.Output -split "\|")[2]
  $project = [string]$ratio.SimulationControl.Project
  if ($project -match "-DGI$") {
    $group.Caption = $outputCompound
    continue
  }
  $projectParts = ($project -replace "-DDGI?$", "") -split "-"
  $perpetrator = @($projectParts | Where-Object { $outputCompound -notmatch [regex]::Escape($_) })[0]
  if ([string]::IsNullOrWhiteSpace($perpetrator)) {
    $perpetrator = $projectParts[0]
  }
  $group.Caption = "$outputCompound + $perpetrator"
}

$dgiRatioPlot = $plan.Plots.DDIRatioPlots |
  Where-Object SectionReference -eq "dgi-ratio-plots"
$ddgiRatioPlot = $plan.Plots.DDIRatioPlots |
  Where-Object SectionReference -eq "ddgi-evaluations"
$ddiRatioPlot = $plan.Plots.DDIRatioPlots |
  Where-Object SectionReference -in @(
    "ddi-evaluations",
    "ddi-ratio-evaluations"
  )

function Get-InteractionRatioCaption {
  param($Ratio)

  $outputCompound = ([string]$Ratio.Output -split "\|")[2]
  $project = [string]$Ratio.SimulationControl.Project
  $projectParts = ($project -replace "-DDGI?$", "") -split "-"
  $perpetrator = @(
    $projectParts | Where-Object {
      $outputCompound -notmatch [regex]::Escape($_)
    }
  )[0]
  if ([string]::IsNullOrWhiteSpace($perpetrator)) {
    $perpetrator = $projectParts[0]
  }

  return "$outputCompound + $perpetrator"
}

function Get-RatioIdentity {
  param($Ratio)

  return @(
    [string]$Ratio.ObservedData,
    [string]$Ratio.ObservedDataRecordId,
    [string]$Ratio.Output,
    [string]$Ratio.SimulationControl.Project,
    [string]$Ratio.SimulationControl.Simulation,
    [string]$Ratio.SimulationDDI.Project,
    [string]$Ratio.SimulationDDI.Simulation
  ) -join "|"
}

function New-RatioGroups {
  param(
    [object[]]$Ratios,
    [switch]$DGI,
    [switch]$DDGI
  )

  $groups = [ordered]@{}
  foreach ($ratio in $Ratios) {
    $analyte = ([string]$ratio.Output -split "\|")[2]
    $caption = if ($DGI) {
      "$analyte`n| $(Get-Cyp2d6Comparison -Ratio $ratio)"
    } elseif ($DDGI) {
      "$(Get-InteractionRatioCaption -Ratio $ratio)`n| $(Get-DdgiComparison -Ratio $ratio)"
    } else {
      Get-InteractionRatioCaption -Ratio $ratio
    }
    if (-not $groups.Contains($caption)) {
      $groups[$caption] = [pscustomobject]@{
        Caption = $caption
        Color = "#0072B2"
        Symbol = "Circle"
        DDIRatios = @()
      }
    }
    $groups[$caption].DDIRatios += $ratio
  }

  return @($groups.Values)
}

$allRatiosByIdentity = [ordered]@{}
foreach ($ratio in $plan.Plots.DDIRatioPlots.Groups.DDIRatios) {
  $identity = Get-RatioIdentity -Ratio $ratio
  if (-not $allRatiosByIdentity.Contains($identity)) {
    $allRatiosByIdentity[$identity] = $ratio
  }
}
$allRatios = @($allRatiosByIdentity.Values)
$dgiRatios = @($allRatios | Where-Object ObservedData -eq "DGI Ratios")
$interactionRatios = @($allRatios | Where-Object ObservedData -ne "DGI Ratios")
$ddgiRatios = @($interactionRatios | Where-Object {
  [string]$_.SimulationControl.Project -match "-DDGI$" -and
    [string]$_.SimulationDDI.Project -match "-DDGI$" -and
    [string]$_.SimulationControl.Simulation -notmatch "^Nichols \(2009\)" -and
    -not [string]::IsNullOrWhiteSpace(
      (Get-Cyp2d6Group -Text ([string]$_.SimulationControl.Simulation))
    )
})
$ddiRatios = @($interactionRatios)

$dgiRatioPlot.Groups = New-RatioGroups -Ratios $dgiRatios -DGI
$ddgiRatioPlot.Groups = New-RatioGroups -Ratios $ddgiRatios -DDGI
$ddiRatioPlot.Groups = New-RatioGroups -Ratios $ddiRatios

$compoundLabelMap = @{
  "(E)-clomiphene" = "(E)-Clomiphene"
  "(E)-4-hydroxyclomiphene" = "(E)-4-Hydroxyclomiphene"
  "(E)-N-desethylclomiphene" = "(E)-N-Desethylclomiphene"
  "(E)-4-hydroxy-N-desethylclomiphene" = "(E)-4-Hydroxy-N-Desethylclomiphene"
  "alpha-Hydroxymetoprolol" = "α-hydroxymetoprolol"
}
foreach ($ratioGroup in $plan.Plots.DDIRatioPlots.Groups) {
  foreach ($sourceLabel in $compoundLabelMap.Keys) {
    $ratioGroup.Caption = ([string]$ratioGroup.Caption).Replace(
      $sourceLabel,
      $compoundLabelMap[$sourceLabel]
    )
  }
}

$ratioColors = @(
  "#0072B2", "#D55E00", "#009E73", "#CC79A7", "#56B4E9",
  "#E69F00", "#332288", "#000000", "#44AA99", "#AA4499",
  "#117733", "#882255", "#88CCEE", "#DDCC77", "#999933",
  "#661100", "#6699CC", "#AA3377", "#228833", "#EE7733",
  "#0077BB", "#33BBEE", "#EE3377", "#BBBBBB"
)
$analyteColors = @{
  "(E)-Clomiphene" = "#0072B2"
  "(E)-4-Hydroxyclomiphene" = "#E69F00"
  "(E)-N-Desethylclomiphene" = "#009E73"
  "(E)-4-Hydroxy-N-Desethylclomiphene" = "#CC79A7"
  "Desipramine" = "#D55E00"
  "2-Hydroxydesipramine" = "#AA4499"
  "Dextromethorphan" = "#332288"
  "Dextrorphan" = "#44AA99"
  "Metoprolol racemate" = "#661100"
  "R-Metoprolol" = "#56B4E9"
  "S-Metoprolol" = "#F0E442"
  "α-hydroxymetoprolol" = "#000000"
  "Risperidone" = "#B28D00"
  "9-Hydroxyrisperidone" = "#00AD7F"
  "Quinidine" = "#20A73C"
  "3-Hydroxyquinidine" = "#DE63B9"
  "Alprazolam" = "#829C00"
  "Atomoxetine" = "#3896E1"
  "Digoxin" = "#5FA200"
  "Mexiletine" = "#C38400"
  "Midazolam" = "#E16A86"
  "Paroxetine" = "#E365A2"
}
$ratioSymbols = @(
  "Circle", "Triangle", "Square", "Diamond", "InvertedTriangle",
  "Cross", "Plus", "Star", "Pentagon", "Hexagon", "CircleOpen",
  "DiamondOpen", "TriangleOpen", "SquareOpen", "InvertedTriangleOpen",
  "StarOpen", "PentagonOpen", "HexagonOpen"
)

$dgiGroupsSorted = @($dgiRatioPlot.Groups | Sort-Object Caption)
for ($index = 0; $index -lt $dgiGroupsSorted.Count; $index++) {
  $caption = [string]$dgiGroupsSorted[$index].Caption
  $analyte = ($caption -split "`n\| ")[0]
  $dgiGroupsSorted[$index].Color = if ($analyteColors.ContainsKey($analyte)) {
    $analyteColors[$analyte]
  } else {
    $ratioColors[$index % $ratioColors.Count]
  }
  $dgiGroupsSorted[$index].Symbol = "Circle"
}
$dgiRatioPlot.Groups = $dgiGroupsSorted

$interactionVictims = @(
  $ddiRatioPlot.Groups |
    ForEach-Object { ([string]$_.Caption -split " \+ ")[0] } |
    Sort-Object -Unique
)
$interactionPerpetrators = @(
  $ddiRatioPlot.Groups |
    ForEach-Object { ([string]$_.Caption -split " \+ ")[-1] } |
    Sort-Object -Unique
)
if ($interactionVictims.Count -gt $ratioColors.Count) {
  throw "The ratio color palette does not cover every victim."
}
if ($interactionPerpetrators.Count -gt $ratioSymbols.Count) {
  throw "The ratio symbol palette does not cover every perpetrator."
}

foreach ($ratioPlot in @($ddiRatioPlot, $ddgiRatioPlot)) {
  foreach ($group in $ratioPlot.Groups) {
    $captionParts = [string]$group.Caption -split "`n\| ", 2
    $interactionCaption = $captionParts[0]
    $comparison = if ($captionParts.Count -gt 1) { $captionParts[1] } else { $null }
    $parts = $interactionCaption -split " \+ "
    $victimIndex = [Array]::IndexOf($interactionVictims, $parts[0])
    $perpetratorIndex = [Array]::IndexOf(
      $interactionPerpetrators,
      $parts[-1]
    )
    $group.Color = if ($analyteColors.ContainsKey($parts[0])) {
      $analyteColors[$parts[0]]
    } else {
      $ratioColors[$victimIndex]
    }
    $group.Symbol = $ratioSymbols[$perpetratorIndex]
    $group.Caption = "$($parts[0])`n+ $($parts[-1])"
    if (-not [string]::IsNullOrWhiteSpace($comparison)) {
      $group.Caption += "`n| $comparison"
    }
  }
  $ratioPlot.Groups = @($ratioPlot.Groups | Sort-Object Caption)
}

$introduction = $plan.Sections | Where-Object Reference -eq "introduction"
$ddi = $plan.Sections | Where-Object Reference -eq "ddi-evaluations"
$dgi = $plan.Sections | Where-Object Reference -eq "dgi-evaluations"
$existingProfiles = $plan.Sections |
  Where-Object Reference -eq "concentration-time-profiles"
$ddgi = $plan.Sections | Where-Object Reference -eq "ddgi-evaluations"
$ddgi = $ddgi ?? ($ddi.Sections | Where-Object Reference -eq "ddgi-evaluations")
$conclusion = $plan.Sections | Where-Object Reference -eq "conclusion"
$references = $plan.Sections | Where-Object Reference -eq "references"
$appendix = $plan.Sections | Where-Object Reference -eq "appendix"
$glossary = $plan.Sections | Where-Object Reference -eq "glossary"

$introduction.Title = "Introduction and CYP2D6 DDGI Network"
$ddi.Title = "Qualification of CYP2D6-Mediated Interactions"
$ddi.Content = "Content/Intro_evaluation_DDI_network.md"
$ddiStudy = $ddi.Sections | Where-Object Reference -eq "ddi-study-evaluations"
$ddiStudy = $ddiStudy ?? (
  $introduction.Sections |
    Where-Object Reference -eq "ddi-study-evaluations"
)
$ddiProfiles = $ddi.Sections | Where-Object Reference -eq "ddi-concentration-time-profiles"
$ddiProfiles = $ddiProfiles ?? (
  $existingProfiles.Sections |
    Where-Object Reference -eq "ddi-concentration-time-profiles"
)
$ddiStudy.Title = "DDI Clinical Studies"
$ddiStudy.Sections = @($ddiStudy.Sections | Sort-Object Title)
$dgiParent = $dgi.Sections |
  Where-Object Reference -eq "dgi-parent-model-evaluations"
$dgiParent = $dgiParent ?? (
  $ddi.Sections |
    Where-Object Reference -eq "dgi-parent-model-evaluations"
)
$dgiParent = $dgiParent ?? (
  $introduction.Sections |
    Where-Object Reference -eq "dgi-parent-model-evaluations"
)
$dgiProfiles = $dgi.Sections |
  Where-Object Reference -eq "dgi-concentration-time-profiles"
$dgiProfiles = $dgiProfiles ?? (
  $existingProfiles.Sections |
    Where-Object Reference -eq "dgi-concentration-time-profiles"
)
$dgiParent.Title = "DGI Clinical Studies"
$dgiParent | Add-Member -Force -NotePropertyName Content `
  -NotePropertyValue "Content/Intro_evaluation_DGI.md"
$desipramineDgi = $dgiParent.Sections |
  Where-Object Reference -eq "desipramine-dgi"
if ($null -eq $desipramineDgi) {
  $dgiParent.Sections += [pscustomobject]@{
    Reference = "desipramine-dgi"
    Title = "Desipramine DGI"
    Content = "Content/Desipramine-DGI.md"
  }
}
$paroxetineDgi = $dgiParent.Sections |
  Where-Object Reference -eq "paroxetine-dgi"
if ($null -eq $paroxetineDgi) {
  $dgiParent.Sections += [pscustomobject]@{
    Reference = "paroxetine-dgi"
    Title = "Paroxetine DGI"
    Content = "Content/Paroxetine-DGI.md"
  }
} else {
  $paroxetineDgi | Add-Member -Force -NotePropertyName Content `
    -NotePropertyValue "Content/Paroxetine-DGI.md"
}
$dgiRatio = $dgi.Sections | Where-Object Reference -eq "dgi-ratio-plots"
$dgiRatio = $dgiRatio ?? (
  $ddi.Sections | Where-Object Reference -eq "dgi-ratio-plots"
)
$ddiRatioSection = [pscustomobject]@{
  Reference = "ddi-ratio-evaluations"
  Title = "DDI Qualification"
}
$ddiRatioPlot.SectionReference = $ddiRatioSection.Reference
$ddiRatioPlot | Add-Member -Force -NotePropertyName Subunits `
  -NotePropertyValue @("Perpetrator", "Victim")
$dgiRatio.Title = "DGI Qualification"
$dgiRatio | Add-Member -Force -NotePropertyName Content `
  -NotePropertyValue "Content/Intro_evaluation_DGI_ratios.md"
$dgiRatioPlot | Add-Member -Force -NotePropertyName Subunits `
  -NotePropertyValue @("Victim")
$ddgi.Title = "DDGI Qualification"
$ddgiRatioPlot | Add-Member -Force -NotePropertyName Subunits `
  -NotePropertyValue @("Perpetrator", "Victim")

$ddgiProfiles = $ddgi.Sections | Where-Object Reference -eq "ddgi-concentration-time-profiles"
$ddgiProfiles = $ddgiProfiles ?? (
  $existingProfiles.Sections |
    Where-Object Reference -eq "ddgi-concentration-time-profiles"
)
$desipramineDgiProfile = $dgiProfiles.Sections |
  Where-Object Reference -eq "desipramine-dgi-timeprofile"
if ($null -eq $desipramineDgiProfile) {
  $dgiProfiles.Sections += [pscustomobject]@{
    Reference = "desipramine-dgi-timeprofile"
    Title = "Desipramine DGI"
  }
}
$paroxetineDgiProfile = $dgiProfiles.Sections |
  Where-Object Reference -eq "paroxetine-dgi-timeprofile"
if ($null -eq $paroxetineDgiProfile) {
  $dgiProfiles.Sections += [pscustomobject]@{
    Reference = "paroxetine-dgi-timeprofile"
    Title = "Paroxetine DGI"
  }
}
$ddgiStudy = $ddgi.Sections | Where-Object Reference -eq "ddgi-study-evaluations"
$ddgiStudy = $ddgiStudy ?? (
  $introduction.Sections |
    Where-Object Reference -eq "ddgi-study-evaluations"
)
$ddgiStudy.Title = "DDGI Clinical Studies"
$ddgiStudy.Sections = @($ddgiStudy.Sections | Sort-Object Title)
$ddgi.Content = "Content/Intro_evaluation_DDGI.md"
$ddgi.Sections = @()

$network = $introduction.Sections |
  Where-Object Reference -eq "cyp2d6-ddgi-network"
$introduction.Sections = @(
  ($introduction.Sections | Where-Object Reference -eq "objective"),
  $network,
  $ddiStudy,
  $dgiParent,
  $ddgiStudy
)

$ddi.Sections = @($ddiRatioSection, $dgiRatio, $ddgi)

$embeddedDdgiProfiles = @($ddiProfiles.Sections | Where-Object {
  [string]$_.Reference -match "-ddgi-timeprofile$"
})
foreach ($section in @($embeddedDdgiProfiles) + @($ddgiProfiles.Sections)) {
  if ($section.Reference -notin $ddiProfiles.Sections.Reference) {
    $ddiProfiles.Sections += $section
  }
}
foreach ($section in $ddiProfiles.Sections) {
  if ($null -ne $section.Title) {
    $section.Title = ([string]$section.Title) -replace " DDGI$", " DDI"
  }
}
$ddiProfiles.PSObject.Properties.Remove("Content")
$dgiProfiles.PSObject.Properties.Remove("Content")

$profiles = [pscustomobject]@{
  Reference = "concentration-time-profiles"
  Title = "Concentration-Time Profiles"
  Content = "Content/Intro_evaluation_CTprofiles.md"
  Sections = @($ddiProfiles, $dgiProfiles)
}

$ddiProfiles.Sections = @($ddiProfiles.Sections | Sort-Object Title)
$dgiProfiles.Sections = @($dgiProfiles.Sections | Sort-Object Title)
$dgiParent.Sections = @($dgiParent.Sections | Sort-Object Title)

if (@($ddiRatioPlot.Groups.DDIRatios).Count -ne 117) {
  throw "The DDI ratio plot must contain all 117 within-group DDI mappings."
}
if (@($ddgiRatioPlot.Groups.DDIRatios).Count -ne 56) {
  throw "The DDGI ratio plot must contain 56 supporting within-group mappings."
}
if (@($dgiRatioPlot.Groups.DDIRatios).Count -ne 85) {
  throw "The DGI ratio plot must contain 85 mappings."
}
$storelliDgiGroups = @($dgiRatioPlot.Groups | Where-Object {
  @($_.DDIRatios.ObservedDataRecordId | Where-Object { $_ -in 900045, 900046 }).Count -gt 0
})
if (
  $storelliDgiGroups.Count -ne 2 -or
  @($storelliDgiGroups.Caption -notmatch "activity score 1 / activity score 2$").Count -gt 0
) {
  throw "Storelli 2018 DGI ratios must compare activity score 1 with activity score 2."
}
if (
  @(
    $dgiRatioPlot.Groups.Caption |
      Where-Object { $_ -match "comparison group|reference group" }
  ).Count -gt 0
) {
  throw "Every DGI ratio must identify both CYP2D6 groups from source names."
}
if (@($ddiProfiles.Sections.Title | Where-Object { $_ -match " DDGI$" }).Count -gt 0) {
  throw "DDI concentration-time profile section titles must use DDI."
}

$derivedDdgiMappings = @(
  $ddgiRatioPlot.Groups |
    Where-Object {
      [string]$_.Caption -notmatch
        "\| (activity score 2 / activity score 2|normal metabolizer / normal metabolizer)$"
    } |
    ForEach-Object DDIRatios
)
if ($derivedDdgiMappings.Count -ne 41) {
  throw "The DDGI ratio plot must yield 41 ratio-of-ratios per endpoint."
}

$ddiAnalyteColors = @(
  $ddiRatioPlot.Groups |
    ForEach-Object {
      [pscustomobject]@{
        Analyte = ([string]$_.Caption -split "`n")[0]
        Color = [string]$_.Color
      }
    } |
    Sort-Object Analyte -Unique
)
if (@($ddiAnalyteColors | Group-Object Color | Where-Object Count -gt 1).Count -gt 0) {
  throw "Each DDI analyte must use a distinct color."
}

foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  if ([string]$plot.SectionReference -match "-dgi-timeprofile$") {
    if (@($plot.OutputMappings.Caption -notmatch "^.+ (Control|Comparison) \(.+\)$").Count -gt 0) {
      throw "DGI time-profile labels must use the normalized control/comparison schema."
    }
  } elseif ([string]$plot.SectionReference -match "-(?:ddi|ddgi)-timeprofile$") {
    if ([string]$plot.Title -match " DDGI$") {
      throw "DDI concentration-time profile plot titles must use DDI."
    }
    if (@($plot.OutputMappings.Caption -notmatch "^.+ (Control \(without|Treatment \(with) .+\)$").Count -gt 0) {
      throw "DDI time-profile labels must use the normalized control/treatment schema."
    }
  }
}

$ddiProfilesWithCyp2d6Groups = @(
  $plan.Plots.ComparisonTimeProfilePlots | Where-Object {
    [string]$_.SectionReference -match "-(?:ddi|ddgi)-timeprofile$"
  }
)
foreach ($plot in $ddiProfilesWithCyp2d6Groups) {
  foreach ($mapping in $plot.OutputMappings) {
    $cyp2d6Group = Get-Cyp2d6Group -Text "$($mapping.Simulation) $($mapping.ObservedData)"
    if (
      -not [string]::IsNullOrWhiteSpace($cyp2d6Group) -and
      [string]$mapping.Caption -notmatch "; $([regex]::Escape($cyp2d6Group))\)$"
    ) {
      throw "A DDI time-profile label omits its CYP2D6 group: $($plot.Title)"
    }
  }
}

$aldermanProfile = @(
  $plan.Plots.ComparisonTimeProfilePlots | Where-Object {
    $_.Title -eq "Alderman 1997: Paroxetine - Desipramine DDI"
  }
)
if (
  $aldermanProfile.Count -ne 1 -or
  $aldermanProfile[0].OutputMappings.Count -ne 2 -or
  $aldermanProfile[0].OutputMappings[0].Caption -ne
    "Desipramine Control (without Paroxetine)" -or
  $aldermanProfile[0].OutputMappings[0].Color -ne "#1F78B4" -or
  $aldermanProfile[0].OutputMappings[0].Symbol -ne "Circle" -or
  $aldermanProfile[0].OutputMappings[1].Caption -ne
    "Desipramine Treatment (with Paroxetine)" -or
  $aldermanProfile[0].OutputMappings[1].Color -ne "#E31A1C" -or
  $aldermanProfile[0].OutputMappings[1].Symbol -ne "Circle"
) {
  throw "Alderman 1997 must have distinct control and treatment legend entries."
}

$storelliDgiProfiles = @($plan.Plots.ComparisonTimeProfilePlots | Where-Object {
  $_.Title -match "^Storelli 2018: Dextromethorphan DGI"
})
if (
  $storelliDgiProfiles.Count -ne 2 -or
  @(
    $storelliDgiProfiles.OutputMappings.Caption |
      Where-Object { $_ -match "intermediate metabolizer" }
  ).Count -gt 0 -or
  @(
    $storelliDgiProfiles.OutputMappings.Caption |
      Where-Object { $_ -match "Comparison \(activity score 1\)$" }
  ).Count -ne 2
) {
  throw "Storelli 2018 DGI profiles must label the comparison as activity score 1."
}
foreach ($plot in $storelliDgiProfiles) {
  $yAxis = $plot.Axes | Where-Object Type -eq "Y"
  if (
    $yAxis.Scaling -ne "Log" -or
    [double]$yAxis.Min -ne 0.01 -or
    [double]$yAxis.Max -ne 2
  ) {
    throw "Storelli 2018 DGI profiles must use the complete logarithmic Y-axis range."
  }
}

$plan.Sections = @(
  $introduction,
  $ddi,
  $profiles,
  $conclusion,
  $references,
  $appendix,
  $glossary
)

$brosen1988 = $plan.Plots.ComparisonTimeProfilePlots |
  Where-Object Title -eq "Brøsen 1988: Desipramine DGI"
$brosen1988YAxis = $brosen1988.Axes | Where-Object Type -eq "Y"
if ($brosen1988YAxis.Scaling -ne "Log") {
  throw "Brøsen 1988 must use logarithmic Y-axis scaling."
}

$brosen1993 = $plan.Plots.ComparisonTimeProfilePlots |
  Where-Object Title -eq "Brøsen 1993: Desipramine DGI"
$brosen1993Colors = @($brosen1993.OutputMappings.Color | Select-Object -Unique)
if ($brosen1993Colors.Count -ne $brosen1993.OutputMappings.Count) {
  throw "Brøsen 1993 must use a distinct color for each phenotype."
}

$jin2008 = $plan.Plots.ComparisonTimeProfilePlots |
  Where-Object Title -eq "Jin 2008: Metoprolol DGI - Metoprolol racemate"
$jin125 = @($jin2008.OutputMappings | Where-Object {
  $_.Simulation -match "AS=1[.]25" -and $_.ObservedData -match "AS=1[.]25"
})
if ($jin125.Count -ne 1) {
  throw "Jin 2008 metoprolol must contain one AS=1.25 simulation and observed-data mapping."
}

$json = $plan | ConvertTo-Json -Depth 100
$json = $json -replace "`r`n", "`n"
[System.IO.File]::WriteAllText(
  $planPath,
  $json + "`n",
  [System.Text.UTF8Encoding]::new($false)
)
