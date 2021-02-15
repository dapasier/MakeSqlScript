param(
        $FileListPath = "e:\SVN\CKK_mod.files",
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

# Alter flag
$alterFlag = $false

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

# Check if OutputFilePath exists and rename if needed
if(Test-Path -Path $OutputFilePath) {
	$oldFile = Split-Path -Path $OutputFilePath -Leaf
	$oldFileExtension = '.' + $oldFile.Split(".")[-1]
	$oldFileDate = Get-ItemPropertyValue -Path $OutputFilePath -Name CreationTime
	$newFileExtension = '.old.' + $oldFileDate.ToString("yyyyMMdd.HHmmss") + '.sql'
	$newFile = $oldFile -replace $oldFileExtension,$newFileExtension
	$msg = 'Renaming old script file ' + $oldFile.ToString() + ' to ' + $newFile
	Write-Warning $msg
	Rename-Item -Path $OutputFilePath -NewName $newFile.ToString()
}

# Get file list
$fileList = Get-Content -LiteralPath $FileListPath

foreach($file in $fileList) {
	# Reset alter flag
	$alterFlag = 0

	# Ignore commented lines
	if ($file -like '#*') {
		Write-Host 'Commented:'$file -ForegroundColor Green
		Continue
	}

	if ($file -like '*#ALTER*') {
		$file = $file -replace('#ALTER','')
		$alterFlag = $true
	}

	# Convert / to \
    if ($file -like '*/*') {
        $file = $file -replace('/','\')
	}

    # Convert relative path to qualified
    if (-Not(Split-Path -Path $file -IsAbsolute))
    {
        $file = Join-Path -Path $fileListRoot -ChildPath $file
    }

    # Resolves wildcards
    $resolvedFile = Resolve-Path -Path $file

	# Write host message
	if($alterFlag) {
		Write-Host 'ALTER ' -NoNewline -ForegroundColor Blue
	}
    Write-Host $resolvedFile

    # Get raw file content
    $fileContent = Get-Content -Path $resolvedFile -Raw

    # Check encoding and try in UTF8 - resolves problem with UTF-8 no BOM
    if($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş›–]') {
        Write-Warning 'Try UTF8'
        $fileContent = Get-Content -Path $resolvedFile -Encoding UTF8 -Delimiter "\r\n"
	}
	
	# Replace CREATE to ALTER
	if($alterFlag) {
		$fileContent = $fileContent -replace('CREATE PROC','ALTER PROC')
		$fileContent = $fileContent -replace('CREATE FUNCTION','ALTER FUNCTION')
		$fileContent = $fileContent -replace('CREATE TRIGGER','ALTER TRIGGER')
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
Write-Host "Script created:"$OutputFilePath
