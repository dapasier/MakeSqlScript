param(
	$FileListPath = "E:\SVN\CE\PromotionAdd.files",
	$OutputFilePath = $null,
	$AddInfoMessage = $true
)
#Requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"
#$DebugPreference = "Continue"

# Define file separator
$fileSeparator = 'GO'

# Build file spearator pattern
$fileSeparatorPattern = '\r\n' + $fileSeparator + '(\r\n)?\Z'

# Regex to match object name
$objectNameRegexPattern = '(?:CREATE|ALTER)\s+(?:TABLE|PROC|PROCEDURE|FUNCTION|TRIGGER|VIEW)\s+(\[?\w+\]?\.)?(\[?\w+\]?)'

# Variables
$objectName = ""
# Flags
$alterFlag = $false
$dropTableFlag = $false

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
	$alterFlag = $false
	$dropTableFlag = $false

	# Ignore commented lines
	if ($file -like '#*') {
		Write-Host 'Commented:'$file -ForegroundColor Green
		Continue
	}

	if ($file -like '*#ALTER*') {
		$file = $file -replace('#ALTER','')
		$alterFlag = $true
	}

	if ($file -like '*#DROPTABLE*') {
		$file = $file -replace('#DROPTABLE','')
		$dropTableFlag = $true
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
	
	# File name only
	$fileName = Split-Path -Path $resolvedFile -LeafBase

	# Write host message
	if($alterFlag) {
		Write-Host 'ALTER ' -NoNewline -ForegroundColor Blue
	}
	if($dropTableFlag) {
		Write-Host 'DROP TABLE ' -NoNewline -ForegroundColor DarkMagenta
	}
	Write-Host $resolvedFile

	# Get raw file content
	$fileContent = Get-Content -Path $resolvedFile -Raw

	# Get object name
	$objectNameMatch = Select-String -Pattern $objectNameRegexPattern -InputObject $fileContent
	if ($objectNameMatch) {
		$objectName = $objectNameMatch.Matches.Groups[1].Value + $objectNameMatch.Matches.Groups[2].Value
	}

	# Check encoding and try in UTF8 - resolves problem with UTF-8 no BOM
	if($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş›–]') {
		$fileContent = Get-Content -Path $resolvedFile -Encoding 1250 -Delimiter "\r\n"

		if ($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş›–]') {
			$fileContent = Get-Content -Path $resolvedFile -Encoding utf8 -Delimiter "\r\n"
			Write-Host 'Try UTF8'
		} else {			
			Write-Host 'Try Windows 1250'
		}

		if ($fileContent -imatch '[^\s\x21-\x7EęóąśłżźćńĹş›–]') {
			Write-Warning 'Invalid characters still exists!'
		}
	}
	
	# Replace CREATE to ALTER
	if($alterFlag) {
		$fileContent = $fileContent -replace('CREATE PROC','ALTER PROC')
		$fileContent = $fileContent -replace('CREATE FUNCTION','ALTER FUNCTION')
		$fileContent = $fileContent -replace('CREATE TRIGGER','ALTER TRIGGER')
		$fileContent = $fileContent -replace('CREATE VIEW','ALTER VIEW')
	}

	# Add DROP TABLE
	if($dropTableFlag) {
		$dropTableStatemant = "DROP TABLE IF EXISTS $objectName;`r`n$fileSeparator`r`n"
		$fileContent = $dropTableStatemant + $fileContent
	}

	# Add file separator if necessary
	if($fileContent -notmatch $fileSeparatorPattern) {
		Write-Debug 'Add file separator'
		$fileContent = $fileContent + "`r`n$fileSeparator"
	}

	if($AddInfoMessage) {
		$infoMessage = "RAISERROR('Running $fileName...', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
		$fileContent = $infoMessage + $fileContent
	}

	# Add to script
	Add-Content -Path $OutputFilePath -Value $fileContent -Encoding utf8
}
if($AddInfoMessage) {
	$infoMessage = "RAISERROR('Script completed!', 10, 1, 1) WITH NOWAIT;`r`n$fileSeparator`r`n"
	Add-Content -Path $OutputFilePath -Value $infoMessage -Encoding utf8
}
Write-Host "Script created:"$OutputFilePath
