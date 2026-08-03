param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [string]$DestinationFolder,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'

$source = (Resolve-Path -LiteralPath $SourceFolder).Path
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$destination = [System.IO.Path]::GetFullPath($DestinationFolder)
$repositoryPrefix = $repository.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

if (-not $destination.StartsWith(
        $repositoryPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Report destination is outside the repository: $destination"
}

$null = New-Item -ItemType Directory -Force -Path $destination
& robocopy.exe $source $destination /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
$robocopyExitCode = $LASTEXITCODE
if ($robocopyExitCode -gt 7) {
    throw "Robocopy failed with exit code $robocopyExitCode."
}

$reportPath = Join-Path $destination 'report.md'
if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw "Rendered report was not copied: $reportPath"
}

$reportText = [System.IO.File]::ReadAllText(
    $reportPath,
    [System.Text.UTF8Encoding]::new($false, $true)
)
$imageMatches = [regex]::Matches(
    $reportText,
    '!\[[^\]]*\]\(([^)]+)\)'
)
$missingImages = foreach ($match in $imageMatches) {
    $imagePath = ($match.Groups[1].Value -split '\s+["'']')[0].Trim('<', '>')
    if ($imagePath -notmatch '^https?://' -and -not (Test-Path -LiteralPath (
                Join-Path $destination $imagePath
            ))) {
        $imagePath
    }
}

if ($missingImages) {
    throw "Copied report references $(@($missingImages).Count) missing image(s)."
}

Write-Output "Copied report passed: $($imageMatches.Count) image references checked."
