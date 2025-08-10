# Simple script to download Windows 11 ESD files from products.xml.
# By default, the en-us versions of the Professional and Enterprise
# editions of both architectures (x64 and ARM64) are downloaded.
#
# Replace line 40, LanguageCode='en-us' with language code of your choice.

#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime"

# Constant Paths
$fileProductsCab = "$PSScriptRoot\products.cab"
$fileProductsXml = "$PSScriptRoot\products.xml"
$url = "https://go.microsoft.com/fwlink?linkid=2156292"

# Use existing cab file or download if it doesn't exist.
if (Test-Path -Path "$PSScriptRoot\*.cab") {
    $nameCab = (Get-ChildItem -Path "$PSScriptRoot\*.cab").Name
    $fileProductsCab = "$PSScriptRoot\$nameCab"
    Write-Host "Using existing file at $fileProductsCab"
}
else {
    Write-Host "Downloading products.cab file..."
    Invoke-WebRequest -Uri $url -OutFile $fileProductsCab  # Not going to bother getting the filename from Content-Disposition.
}

# Extract cab file contents
if (Test-Path $fileProductsXml) {
    Write-Host "products.xml already extracted"
}
else {
    Write-Host "Extracting products.xml from the cab file."
    Start-Process -FilePath "expand.exe" -ArgumentList "-I $fileProductsCab $PSScriptRoot" -Wait -NoNewWindow
}

# Parse products.xml file and display relevant ESDs.
Write-Host "Parsing products.xml..."
[xml]$products = Get-Content -Path "$fileProductsXml"
$theXml = Select-Xml -Xml $products -XPath "//File[LanguageCode='en-us']"  # Replace with language code of your choice.
foreach ($file in $theXml) {
    if ($file.Node.Edition -eq "Professional" -or $file.Node.Edition -eq "Enterprise") {
        Write-Host "FileName =" $file.Node.FileName
        Write-Host "Edition =" $file.Node.Edition
        Write-Host "Architecture =" $file.Node.Architecture
        Write-Host "Size =" $file.Node.Size
        Write-Host "Sha1 =" $file.Node.Sha1
        Write-Host "FilePath =" $file.Node.FilePath
        Write-Host ""
    }
}

$secondsTotal = 5  # Change to shorten or lengthen countdown timer.
$secondsLeft = $secondsTotal
Write-Host "$secondsTotal seconds before script downloads the ESD files. Press Ctrl+C to cancel!"
Write-Host "Make sure you have plenty of disk space!"
while ($secondsLeft -gt 0) {
    Write-Host "$secondsLeft seconds left."
    Start-Sleep -Seconds 1
    $secondsLeft--
}
Write-Host "Initiating download!"
Write-Host ""
foreach ($file in $theXml) {
    if ($file.Node.Edition -eq "Professional" -or $file.Node.Edition -eq "Enterprise") {
        $nameFile = "$PSScriptRoot\" + $file.Node.FileName
        if (!(Test-Path -Path "$nameFile")) {
            Write-Host "Downloading " $file.Node.FileName
            Write-Host "Destination " $nameFile
            Write-Host $file.Node.FilePath
            Start-BitsTransfer -Priority Normal -TransferType Download -Source $file.Node.FilePath -Destination "$PSScriptRoot" #-WhatIf # uncomment to skip downloading when testing.
        }
        else {
            Write-Host $file.Node.FileName "already exists! Skipping download."
        }
        
        # Check ESD file SHA1 hash.
        Write-Host "Published SHA1 =" ($file.Node.Sha1).ToUpper()
        if (Test-Path -Path "$nameFile") {  # In case download fails or file disappears.
            $hashFile = Get-FileHash -Algorithm SHA1 -Path "$nameFile"
            Write-Host "Calculated SHA1 =" $hashFile.Hash
            Write-Host "Both hashes match? " ($hashFile.Hash -eq (($file.Node.Sha1).ToUpper()))
        }
        Write-Host ""
    }
}

Write-Host "Script completed at $(Get-Date) and took $( ( (Get-Date) - $StartDateTime).Minutes) minutes"