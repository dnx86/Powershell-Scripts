# Run create-custom-winpe-wim.ps1 before running this script.
# Requires Windows ADK and WinPE add-on installed.
#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime"

# Constant Paths
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$DandISetEnvPath = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat")
$WinPEPath = "$PSScriptRoot\WinPE"
$pathWinPEVHDFolder = "$PSScriptRoot\vhd"
$pathVHD = "$pathWinPEVHDFolder\winpe.vhdx"

# Check if Windows ADK and PE add-on are installed
Write-Host "Checking if Windows ADK is installed..."
$ADKInstalled = Test-Path -Path "$ADKInstallLocation\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
if ($ADKInstalled) {
    Write-Host "  -- An installation of Windows ADK was found on device."
}
else {
    Write-Host "  -- An installation of Windows ADK was not found on the device."
    Exit
}

Write-Host "Checking if Windows ADK WinPE add-on is installed..."
$ADKWinPEInstalled = Test-Path -Path $ADKWinPELocation
if ($ADKWinPEInstalled) {
    Write-Host "  -- An installation of Windows ADK WinPE add-on was found on this device."
}
else {
    Write-Host "  -- An installation for Windows ADK WinPE add-on was NOT found on this device."
    Exit
}

# Delete existing WinPE folder and create a new one.
Write-Host "[+] Creating a working copy of Windows PE"
if (Test-Path -Path "$WinPEPath") {
    Write-Host "Deleting the existing WinPE folder..."
    Remove-Item -Path "$WinPEPath" -Recurse -Force
}
Write-Host "Creating new WinPE folder..."
cmd.exe /c """$DandISetEnvPath"" && copype amd64 $WinPEPath"

# Delete existing VHD folder and create a new one.
if (Test-Path -Path $pathWinPEVHDFolder){
    Write-Host "Deleting the existing vhd folder and its contents."
    Remove-Item -Path $pathWinPEVHDFolder -Recurse -Force
}
Write-Host "Creating new vhd folder..."
New-Item -Path $pathWinPEVHDFolder -ItemType Directory | Out-Null

# Copy custom generated winpe.wim if it exists.
if (Test-Path "$PSScriptRoot\wim\winpe.wim") {
    Write-Host "[+] Custom winpe.wim detected! Will use that for the VHD."
    Remove-Item -Path "$WinPEPath\media\sources\boot.wim" -Force
    Copy-Item -Path "$PSScriptRoot\wim\winpe.wim" -Destination "$WinPEPath\media\sources\boot.wim"
}
else {
    Write-Host "Custom winpe.wim not detected!"
}

# Adapted from
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-install-on-a-hard-drive--flat-boot-or-non-ram?view=windows-11#install-windows-pe-to-the-media
# Powershell used instead of diskpart.
# winpe.vhdx will be 16GB. WindowsPE partition is 2GB and FAT32 formatted. Images partition uses the remaining space and NTFS formatted.
$sizeVHD = 16GB #Adjust if necessary
New-VHD -Path $pathVHD -Dynamic -SizeBytes $sizeVHD
$theVHD = Mount-VHD -Path $pathVHD -Passthru | Initialize-Disk -PartitionStyle MBR -Passthru #Passthru required
try {
    New-Partition -DiskNumber $theVHD.DiskNumber -Size 2GB -DriveLetter P -IsActive | Format-Volume -FileSystem FAT32 -NewFileSystemLabel "WindowsPE" -Confirm:$false -Force
    New-Partition -DiskNumber $theVHD.DiskNumber -UseMaximumSize -DriveLetter I | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Images" -Confirm:$false -Force

    # Makewinpemedia command-line options
    # https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/makewinpemedia-command-line-options?view=windows-11
    $driveLetter = (Get-Volume -FileSystemLabel WindowsPE).DriveLetter
    cmd.exe /c """$DandISetEnvPath"" && Makewinpemedia /ufd /f $WinPEPath ${driveLetter}:"
}
finally {
    Dismount-VHD -DiskNumber $theVHD.DiskNumber
}

Write-Host "Script completed at $(Get-Date) and took $( ( (Get-Date) - $StartDateTime).Minutes) minutes"