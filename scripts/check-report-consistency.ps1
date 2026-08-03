param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [switch]$ReleaseReady
)

$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$inputPath = Join-Path $rootPath "Qualification/Input"
$contentPath = Join-Path $inputPath "Content"
$plan = Get-Content (Join-Path $inputPath "qualification_plan.json") -Raw |
  ConvertFrom-Json
$manifest = @(Import-Csv (Join-Path $inputPath "snapshot_manifest.csv"))
$studyMap = @(Import-Csv (Join-Path $inputPath "study_reference_map.csv"))

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

$projects = @($plan.Projects)
Assert-True ($manifest.Count -eq $projects.Count) `
  "The snapshot manifest must contain one row per qualification project."
Assert-True (($manifest.Project | Sort-Object -Unique).Count -eq $manifest.Count) `
  "Snapshot manifest project names must be unique."

foreach ($project in $projects) {
  $rows = @($manifest | Where-Object Project -eq $project.Id)
  Assert-True ($rows.Count -eq 1) `
    "Project '$($project.Id)' does not have exactly one manifest row."

  $uri = [uri]$project.Path
  $parts = $uri.AbsolutePath.TrimStart("/") -split "/"
  $expectedRepository = "https://github.com/$($parts[0])/$($parts[1])"
  $expectedSnapshot = $parts[3..($parts.Length - 1)] -join "/"
  $expectedCommit = if ($parts[2] -match "^[0-9a-f]{40}$") {
    $parts[2]
  } else {
    "Pending"
  }
  $row = $rows[0]
  Assert-True ($row.Repository -eq $expectedRepository) `
    "Manifest repository mismatch for '$($project.Id)'."
  Assert-True ($row.SnapshotPath -eq $expectedSnapshot) `
    "Manifest snapshot-path mismatch for '$($project.Id)'."
  Assert-True ($row.Commit -eq $expectedCommit) `
    "Manifest commit mismatch for '$($project.Id)'."
}

if ($ReleaseReady) {
  $pending = @($manifest | Where-Object Commit -eq "Pending")
  Assert-True ($pending.Count -eq 0) `
    "Release readiness requires immutable commits for every manifest row."
}

Assert-True (($studyMap.DataID | Sort-Object -Unique).Count -eq $studyMap.Count) `
  "Study-reference DataIDs must be unique."
$ratioIds = @(
  $plan.Plots.DDIRatioPlots.Groups.DDIRatios |
    Where-Object ObservedData -eq "DDI Ratios" |
    ForEach-Object { [string]$_.ObservedDataRecordId } |
    Sort-Object -Unique
)
$mappedIds = @($studyMap.DataID | Sort-Object -Unique)
Assert-True (($ratioIds -join ",") -eq ($mappedIds -join ",")) `
  "The study-reference map must cover exactly the quantitative DDI DataIDs."

$requiredStudyKeys = @{
  "16962" = "Hardy 1988"
  "17108" = "Chellingsworth 1988"
  "17110" = "Chellingsworth 1988"
  "17170" = "Kim 2008"
  "17172" = "Kim 2008"
}
foreach ($dataId in $requiredStudyKeys.Keys) {
  $row = $studyMap | Where-Object DataID -eq $dataId
  Assert-True ($row.StudyKey -eq $requiredStudyKeys[$dataId]) `
    "Canonical study key mismatch for DataID $dataId."
}

$references = Get-Content (Join-Path $contentPath "References.md") -Raw
foreach ($key in $studyMap.BibliographyKey | Sort-Object -Unique) {
  $keyMatch = [regex]::Match($key, "^(?<author>.+) (?<year>\d{4})[a-z]?$" )
  Assert-True $keyMatch.Success "Invalid bibliography key '$key'."
  $author = $keyMatch.Groups["author"].Value
  $year = $keyMatch.Groups["year"].Value
  Assert-True (
    $references -match [regex]::Escape($author) -and
      $references -match ", $year\."
  ) `
    "Bibliography key '$key' is not present in References.md."
}

$clinicalRows = Get-ChildItem $contentPath -File |
  Where-Object Name -Match "-(?:DDI|DDGI)\.md$" |
  ForEach-Object { Get-Content $_.FullName }
foreach ($line in $clinicalRows) {
  $match = [regex]::Match(
    $line,
    "^\|\s*(?<ids>\d+(?:\s*,\s*\d+)*)\s*\|\s*\[(?<key>[^]]+)\]\(#references\)"
  )
  if (-not $match.Success) {
    continue
  }
  foreach ($dataId in $match.Groups["ids"].Value -split "\s*,\s*") {
    $mapped = $studyMap | Where-Object DataID -eq $dataId
    if ($null -ne $mapped) {
      Assert-True ($mapped.StudyKey -eq $match.Groups["key"].Value) `
        "Clinical and canonical study keys differ for DataID $dataId."
    }
  }
}

$guestDeltas = @($plan.Plots.DDIRatioPlots.GuestDelta | Sort-Object -Unique)
Assert-True ($guestDeltas.Count -eq 1 -and $guestDeltas[0] -eq 1.25) `
  "All ratio plots must use the prespecified Guest delta of 1.25."

$ratioRecordReferenceDefinition = "A dash identifies the reference group and means that no separate ratio record was generated."
$dgiFiles = @(Get-ChildItem $contentPath -File -Filter "*-DGI.md")
foreach ($file in $dgiFiles) {
  $text = Get-Content $file.FullName -Raw
  Assert-True ($text.Contains("| **Ratio record ID** |")) `
    "DGI ratio-record header is missing from '$($file.Name)'."
  Assert-True ($text -match "(?i)ratio record ID identifies .*derived .*ratio") `
    "DGI ratio-record definition is missing from '$($file.Name)'."
  Assert-True ($text.Contains($ratioRecordReferenceDefinition)) `
    "DGI reference-group definition is missing from '$($file.Name)'."
  Assert-True (-not $text.Contains("DataID")) `
    "DGI content incorrectly presents a ratio-record identifier as a DataID in '$($file.Name)'."
}

$contentText = Get-ChildItem $contentPath -File -Filter "*.md" |
  ForEach-Object { Get-Content $_.FullName -Raw }
Assert-True (-not (($contentText -join "`n").Contains(
      "The exact snapshot used for this qualification is available"
    ))) "Repeated snapshot-link prose remains in report content."

foreach ($plot in $plan.Plots.ComparisonTimeProfilePlots) {
  Assert-True ([string]$plot.Title -match "^[^:]+:\s+.+") `
    "A time-profile title lacks study and scenario context."
  $study = ([string]$plot.Title -split ":", 2)[0]
  Assert-True (([regex]::Matches([string]$plot.Title, [regex]::Escape($study))).Count -eq 1) `
    "A time-profile title repeats its study name: $($plot.Title)"
  Assert-True (([string]$plot.Title).Length -le 80) `
    "A time-profile title is too long for a stable image filename: $($plot.Title)"
}
$profileSection = $plan.Sections |
  Where-Object Reference -eq "concentration-time-profiles"
Assert-True ($profileSection.Content -eq "Content/Intro_evaluation_CTprofiles.md") `
  "The shared concentration-time introduction is missing."
foreach ($subsection in $profileSection.Sections) {
  Assert-True ($null -eq $subsection.Content) `
    "The shared concentration-time introduction is repeated in '$($subsection.Reference)'."
}

$networkPath = Join-Path $contentPath "Qualification_DDI_network_description.md"
$networkText = Get-Content $networkPath -Raw
foreach ($row in $manifest) {
  Assert-True ($networkText.Contains("| $($row.Project) |")) `
    "The report manifest omits project '$($row.Project)'."
  if ($row.Commit -ne "Pending") {
    Assert-True ($networkText.Contains($row.Commit)) `
      "The report manifest omits the commit for '$($row.Project)'."
  }
}
$fluvoxaminePattern = '(?s)\| \*\*Interaction project\*\* \| \*\*Parameter not present in parent snapshot\*\* \| \*\*Value\*\* \| \*\*Source or justification\*\* \|.*?The available project documentation does not explain why the two interaction snapshots use different CYP2D6 \$K_i\$ values for fluvoxamine\. This report records the difference and does not interpret it as study-specific calibration\.'
$fluvoxamineBlock = [regex]::Match($networkText, $fluvoxaminePattern)
Assert-True $fluvoxamineBlock.Success "The protected fluvoxamine table is missing."
$normalizedBlock = $fluvoxamineBlock.Value -replace "`r`n", "`n"
$blockBytes = [Text.Encoding]::UTF8.GetBytes($normalizedBlock)
$blockHash = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData($blockBytes)
).ToLowerInvariant()
Assert-True ($blockHash -eq "bfc1a3d1627e3d50ac209f937ea91b1bad6b308ba00a4cce359b348b28e303a2") `
  "The protected fluvoxamine table or its interpretation changed."

Write-Output "Report-source consistency checks passed."
