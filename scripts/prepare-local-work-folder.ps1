param(
    [Parameter(Mandatory = $true)]
    [string]$WorkFolder
)

$ErrorActionPreference = 'Stop'

$requestedFolder = [System.IO.Path]::GetFullPath($WorkFolder)
$expectedFolder = [System.IO.Path]::GetFullPath('C:\tmp\osp')

if (-not $requestedFolder.Equals(
        $expectedFolder,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to prepare unexpected work folder: $requestedFolder"
}

if (Test-Path -LiteralPath $requestedFolder) {
    Remove-Item -LiteralPath $requestedFolder -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $requestedFolder

Write-Output "Prepared local work folder: $requestedFolder"
