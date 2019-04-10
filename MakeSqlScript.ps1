param(
        $FileListPath = "aggr_value_round.files",
        $OutputFilePath = $null,
        $AddInfoMessage = 1
)
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"
#$DebugPreference = "Continue"

# Define file separator
$fileSeparator = 'GO'

# Build file spearator pattern
$fileSeparatorPattern = '\r\n' + $fileSeparator + '(\r\n)?'

# Convert FileListPath relative path to qualified
$FileListPath = Join-Path -Path $PSScriptRoot -ChildPath $FileListPath

# Convert OutputFilePath relative path to qualified
if (-Not($OutputFilePath)) {
    $OutputFilePath = Split-Path -Path $FileListPath -Leaf
    $OutputFilePath = $OutputFilePath -replace '\.files',''
    $OutputFilePath += '.sql'
}
$OutputFilePath = Join-Path -Path $PSScriptRoot -ChildPath $OutputFilePath

# Check if OutputFilePath exists and delete if needed
if(Test-Path -LiteralPath $OutputFilePath) {
    Remove-Item -LiteralPath $OutputFilePath
}

# Get file list
$fileList = Get-Content -LiteralPath $FileListPath

foreach($file in $fileList) {
    # Convert / to \
    if ($file -like '*/*') {
        $file = $file -replace '/','\'
    }
    
    # Convert relative path to qualified
    if (Split-Path -Path $file -IsAbsolute)
    {
        $file = Join-Path -Path $PSScriptRoot -ChildPath $file
    }

    # Resolves wildcards
    $resolvedFile = Resolve-Path -Path $file

    Write-Host $resolvedFile

    # Get raw file content
    $fileContent = Get-Content -LiteralPath $resolvedFile -Raw

    # Check encoding and try in UTF8 - resolves problem with UTF-8 no BOM
    if($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş]') {
        Write-Host 'Try UTF8'
        $fileContent = Get-Content -LiteralPath $resolvedFile -Encoding UTF8
    }
    
    # Add file separator if necessary
    if($fileContent -notmatch $fileSeparatorPattern) {
        $fileContent = $fileContent + "`r`n$fileSeparator"
    }

    if($AddInfoMessage = 1) {
        $fileName = Split-Path -Path $resolvedFile -Leaf
        $infoMessage = "RAISERROR('Running $fileName...', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
        $fileContent = $infoMessage + $fileContent
    }

    # Add to script
    Add-Content -LiteralPath $OutputFilePath -Value $fileContent -Encoding UTF8
}
if($AddInfoMessage = 1) {
    $infoMessage = "RAISERROR('Script copleted!', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
    Add-Content -LiteralPath $OutputFilePath -Value $infoMessage -Encoding UTF8
}