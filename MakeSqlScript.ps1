param(
        $FileListPath = "E:\SVN\example.files",
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

# Check if FileListPath is absolute, if not, root directory is set to $PSScriptRoot
if(Split-Path -Path $FileListPath -IsAbsolute) {
    $fileListRoot = Split-Path -Path $FileListPath -Parent
} else {
    $fileListRoot = $PSScriptRoot

    # Convert FileListPath relative path to qualified
    $FileListPath = Join-Path -Path $fileListRoot -ChildPath $FileListPath
}

# Set output file name if not provided
if(-Not($OutputFilePath)) {
    $fileListExtension = '.' + (Split-Path -Path $FileListPath -Leaf).Split(".")[-1]
    $OutputFilePath = $FileListPath -replace $fileListExtension,'.script.sql'
}

# Convert OutputFilePath relative path to qualified
if(-Not(Split-Path -Path $OutputFilePath -IsAbsolute)) {
    $OutputFilePath = Join-Path -Path $fileListRoot -ChildPath $OutputFilePath
}

# Check if OutputFilePath exists and delete if needed
if(Test-Path -Path $OutputFilePath) {
    Remove-Item -Path $OutputFilePath -Confirm
}

# Get file list
$fileList = Get-Content -LiteralPath $FileListPath

foreach($file in $fileList) {
    # Convert / to \
    if ($file -like '*/*') {
        $file = $file -replace '/','\'
    }
    
    # Convert relative path to qualified
    if (-Not(Split-Path -Path $file -IsAbsolute))
    {
        $file = Join-Path -Path $fileListRoot -ChildPath $file
    }

    # Resolves wildcards
    $resolvedFile = Resolve-Path -Path $file

    Write-Host $resolvedFile

    # Get raw file content
    $fileContent = Get-Content -Path $resolvedFile -Raw

    # Check encoding and try in UTF8 - resolves problem with UTF-8 no BOM
    if($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş›]') {
        Write-Warning 'Try UTF8'
        $fileContent = Get-Content -Path $resolvedFile -Encoding UTF8
    }
    
    # Add file separator if necessary
    if($fileContent -notmatch $fileSeparatorPattern) {
        Write-Debug 'Add file separator'
        $fileContent = $fileContent + "`r`n$fileSeparator"
    }

    if($AddInfoMessage = 1) {
        $fileName = Split-Path -Path $resolvedFile -Leaf
        $infoMessage = "RAISERROR('Running $fileName...', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
        $fileContent = $infoMessage + $fileContent
    }

    # Add to script
    Add-Content -Path $OutputFilePath -Value $fileContent -Encoding UTF8
}
if($AddInfoMessage = 1) {
    $infoMessage = "RAISERROR('Script completed!', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
    Add-Content -Path $OutputFilePath -Value $infoMessage -Encoding UTF8
}