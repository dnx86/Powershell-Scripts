# Run create-custom-winpe-wim.ps1 before running this script.
# Requires Windows ADK and WinPE add-on installed.
#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime"

# Constant Paths
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")

$pathVHDFolder = "$PSScriptRoot\vhd"
$pathVHD = "$pathVHDFolder\windows-11.vhdx"

# Wim folder and file
$pathWimFolder = "$PSScriptRoot\wim"
$pathWimFile = "$pathWimFolder\install.wim"

$indexWIM = 1

# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bcdboot-command-line-options-techref-di?view=windows-11
$pathBcdboot = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\BCDBoot\bcdboot.exe")

# Check if Windows ADK and PE add-on are installed
Write-Host "Checking if Windows ADK is installed..."
$ADKInstalled = Test-Path -Path "$ADKInstallLocation\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
if ($ADKInstalled) {
    Write-Host "  -- An installation of Windows ADK was found on device."
}
else {
    Write-Host "  -- An installation of Windows ADK was not found on the device." -ForegroundColor Yellow
    Exit
}

Write-Host "Checking if Windows ADK WinPE add-on is installed..."
$ADKWinPEInstalled = Test-Path -Path $ADKWinPELocation
if ($ADKWinPEInstalled) {
    Write-Host "  -- An installation of Windows ADK WinPE add-on was found on this device."
}
else {
    Write-Host "  -- An installation for Windows ADK WinPE add-on was NOT found on this device." -ForegroundColor Yellow
    Exit
}

# Check if the wim folder exists and is not empty
if ( !(Test-Path -Path "$pathWimFolder") ) {
    Write-Host "The wim folder does not exists! Script cannot proceed!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathWimFolder").Count -eq 0 ) {
    Write-Host "The wim folder is EMPTY! Script cannot proceed!" -ForegroundColor Yellow
    Write-Host "Put a SINGLE WIM file with Windows 11 in this folder" -ForegroundColor Yellow
    Write-Host "and run this script again!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathWimFolder").Count -gt 1 ) {
    Write-Host "Feature to handle multiple files not implemented yet! Script cannot proceed!" -ForegroundColor Yellow
    Write-Host "Ensure a SINGLE WIM file with Windows 11 is in this folder" -ForegroundColor Yellow
    Write-Host "and run this script again!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathWimFolder").Count -eq 1 ) {
    # Check if a WIM file is present
    $theFile = Get-ChildItem -Path "$pathWimFolder" -Recurse -Include "*.wim"
    if ($theFile.Count -eq 0) {
        Write-Host "WIM file not present! Exiting!" -ForegroundColor Yellow
        Exit
    }

    $pathFile = $theFile.FullName

    # Delete existing VHD folder and create a new one.
    if (Test-Path -Path $pathVHDFolder){
        Write-Host "Deleting the existing vhd folder and its contents." -ForegroundColor DarkGreen
        Remove-Item -Path $pathVHDFolder -Recurse -Force
    }
    else {
        Write-Host "Creating new vhd folder..." -ForegroundColor DarkGreen
        New-Item -Path $pathVHDFolder -ItemType Directory | Out-Null
    }

    # Adapted from
    # https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-install-on-a-hard-drive--flat-boot-or-non-ram?view=windows-11#install-windows-pe-to-the-media
    # Powershell used instead of diskpart.
    # winpe.vhdx will be 16GB. WindowsPE partition is 2GB and FAT32 formatted. Images partition uses the remaining space and NTFS formatted.
    $sizeVHD = 60GB #Adjust if necessary
    New-VHD -Path $pathVHD -Dynamic -SizeBytes $sizeVHD
    $theVHD = Mount-VHD -Path $pathVHD -Passthru | Initialize-Disk -PartitionStyle GPT -Passthru #Passthru required for both
    try {
        # Drive letters: System=S, Windows=W, and Recovery=R. The MSR partition doesn't get a letter. The letter W is used to avoid potential drive letter conflicts.
        # Create system partition
        New-Partition -DiskNumber $theVHD.DiskNumber -Size 260MB -DriveLetter S -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -ErrorAction Stop
        Format-Volume -DriveLetter S -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false -Force -ErrorAction Stop
        
        # Create MSR partition
        New-Partition -DiskNumber $theVHD.DiskNumber -Size 16MB -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}" -ErrorAction Stop
        
        # Create Windows partition
        New-Partition -DiskNumber $theVHD.DiskNumber -UseMaximumSize -DriveLetter W | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows" -Confirm:$false -Force
        
        Dism /Apply-Image /ImageFile:$pathFile /index:$indexWIM /ApplyDir:W:\
        
        # Add a boot entry
        Start-Process -FilePath $pathBcdboot -ArgumentList "W:\Windows /s S: /f UEFI /v" -NoNewWindow -Wait
        
        # Make the Panther folder and copy the unattend file to it
        #Mkdir "W:\Windows\Panther"
        #Copy-Item ".\unattend\unattend.xml" -Destination "W:\Windows\Panther\unattend.xml"
    }
    finally {
        Dismount-VHD -DiskNumber $theVHD.DiskNumber
    }
}
else {
    Write-Host "Unknown error involving wim folder! Exiting!" -ForegroundColor Yellow
    Exit
}

Write-Host "Script completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red