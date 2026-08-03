$ErrorActionPreference = "Stop"

$contentFolder = Join-Path $PSScriptRoot "../Qualification/Input/Content"

$dataIdsByFile = @{
  "Atomoxetine-Desipramine-DDI.md" = @("17078")
  "Carbamazepine-Quinidine-DDI.md" = @("16956, 16958")
  "Cimetidine-Metoprolol-DDI.md" = @("17108", "17110", "17112", "17114")
  "Cimetidine-Quinidine-DDI.md" = @("16960", "16962")
  "Clarithromycin-Clomiphene-DDGI.md" = @(
    "16998, 17000, 17002, 17004",
    "17006, 17008, 17010, 17012",
    "17014, 17016, 17018, 17020",
    "17022, 17024, 17026, 17028",
    "17030, 17032, 17034, 17036"
  )
  "Erythromycin-Quinidine-DDI.md" = @("17160")
  "Fluvoxamine-Atomoxetine-DDI.md" = @("16986")
  "Fluvoxamine-Quinidine-DDI.md" = @("16964, 16966")
  "Itraconazole-Paroxetine-DDI.md" = @("17158")
  "Itraconazole-Quinidine-DDI.md" = @("17162", "17164")
  "Ketoconazole-Risperidone-DDI.md" = @("17166, 17168")
  "Omeprazole-Quinidine-DDI.md" = @("16968, 16970")
  "Paroxetine-Alprazolam-DDI.md" = @("16980")
  "Paroxetine-Atomoxetine-DDGI.md" = @("16988", "16990", "16992", "16994", "16996")
  "Paroxetine-Clomiphene-DDGI.md" = @(
    "17038, 17040, 17042, 17044",
    "17046, 17048, 17050, 17052",
    "17054, 17056, 17058, 17060",
    "17062, 17064, 17066, 17068",
    "17070, 17072, 17074, 17076"
  )
  "Paroxetine-Desipramine-DDGI.md" = @(
    "17082, 17084", "17086", "17088", "17090", "17092, 17093, 17094"
  )
  "Paroxetine-Dextromethorphan-DDGI.md" = @("17098", "17102", "17106")
  "Paroxetine-Metoprolol-DDI.md" = @(
    "17116", "17118", "17120, 17122", "17124, 17126", "17128, 17130", "17132, 17134"
  )
  "Quinidine-Desipramine-DDI.md" = @("17096")
  "Quinidine-Dextromethorphan-DDI.md" = @("16940", "16944")
  "Quinidine-Digoxin-DDI.md" = @("16946", "16948")
  "Quinidine-Metoprolol-DDGI.md" = @(
    "17136", "17138", "17140", "17142", "17144, 17146", "17148, 17150"
  )
  "Quinidine-Mexiletine-DDGI.md" = @("16950", "16952")
  "Quinidine-Paroxetine-DDI.md" = @("16954")
  "Rifampicin-Metoprolol-DDI.md" = @("17152")
  "Rifampicin-Quinidine-DDI.md" = @("16972, 16974")
  "Rifampicin-Risperidone-DDI.md" = @("17170, 17172", "17174")
  "Verapamil-Quinidine-DDI.md" = @("16976", "16978")
  "Verapamil-Risperidone-DDI.md" = @("17176, 17178")
}

foreach ($entry in $dataIdsByFile.GetEnumerator()) {
  $path = Join-Path $contentFolder $entry.Key
  $text = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n")

  $lines = $text -split "`n"
  $headerIndex = [Array]::FindIndex(
    $lines,
    [Predicate[string]] {
      param($line)
      $line -match '^\| \*\*(DataID|Source)\*\*'
    }
  )
  if ($headerIndex -lt 0) {
    throw "Clinical table header not found in $($entry.Key)."
  }

  $sourceHeaderIndex = $lines[$headerIndex].IndexOf("**Source**")
  $lines[$headerIndex] = "| **DataID** | " + $lines[$headerIndex].Substring($sourceHeaderIndex)

  $separatorTail = $lines[$headerIndex + 1] -replace '^\| ---\s+', ''
  $lines[$headerIndex + 1] = "| --- | " + $separatorTail

  for ($rowIndex = 0; $rowIndex -lt $entry.Value.Count; $rowIndex++) {
    $lineIndex = $headerIndex + 2 + $rowIndex
    $sourceIndex = $lines[$lineIndex].IndexOf("[")
    if ($sourceIndex -lt 0) {
      throw "Unexpected clinical table row $($rowIndex + 1) in $($entry.Key)."
    }
    $lines[$lineIndex] = "| $($entry.Value[$rowIndex]) | " + $lines[$lineIndex].Substring($sourceIndex)
  }

  $updated = ($lines -join "`n").TrimEnd("`n") + "`n"
  [System.IO.File]::WriteAllText(
    $path,
    $updated,
    [System.Text.UTF8Encoding]::new($false)
  )
}
