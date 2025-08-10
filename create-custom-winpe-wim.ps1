# Generates a winpe.wim file with drivers, optional components, and updates.
# Customize Windows PE boot images
# https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image?tabs=powershell
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11
#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime"

# Variables
# List of optional components that will be added in the order listed.
$listOCs = @("WinPE-WMI", "WinPE-NetFX", "WinPE-Scripting", "WinPE-PowerShell", "WinPE-DismCmdlets", "WinPE-StorageWMI", "WinPE-SecureStartup", "WinPE-FMAPI", "WinPE-SecureBootCmdlets", "WinPE-EnhancedStorage")

# List of cumulative updates in the CUs folder. KB names are in double quotes separated by commas.
$listCUs = @("kb5062553")

# Constant Paths
$pathADKWinPE = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$pathADKDism = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe")
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")

# Optional components folders
$pathOC = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs")
$pathOCen = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us")

$pathMount = "$PSScriptRoot\Mount"
$pathCU = "$PSScriptRoot\CUs"
$pathDrivers = "$PSScriptRoot\Drivers"

$pathWimFolder = "$PSScriptRoot\wim"
$pathWimFile = "$pathWimFolder\winpe.wim"

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

# Delete the wim folder if it already exists and create a new one.
if (Test-Path -Path "$pathWimFolder") {
    Write-Host "Removing existing wim folder..."
    Remove-Item -Path "$pathWimFolder" -Recurse -Force
}
Write-Host "Creating new wim folder..."
New-Item -Path "$pathWimFolder" -ItemType Directory

# Copy boot image to the wim folder
if (Test-Path -Path "$pathADKWinPE") {
    Write-Host "Copying winpe.wim to the wim folder."
    Copy-Item -Path "$pathADKWinPE" -Destination "$pathWimFile"
}
else {
    Write-Host "winpe.wim file does not exists! Exiting!"
    Exit
}

# Delete the mount folder if it already exists and create a new one.
if ( (Test-Path -Path "$pathMount") -and ((Get-ChildItem -Path "$pathMount").Count -eq 0) ) {
    Write-Host "Deleting existing Mount folder..."
    Remove-Item -Path "$pathMount" -Force
}
elseif ((Test-Path -Path "$pathMount") -and ((Get-ChildItem -Path "$pathMount").Count -gt 0)) {
    Write-Host "Reboot the computer and run the command below with admin privileges!"
    Write-Host "Dismount-WindowsImage -Path "$pathMount" -Discard"
    Exit
}
Write-Host "Creating new Mount folder..."
New-Item -Path "$pathMount" -ItemType Directory

# Mount boot image to mount folder.
Write-Host "Mounting winpe.wim..."
Mount-WindowsImage -Path "$pathMount" -ImagePath "$pathWimFile" -Index 1 -Verbose

# Add drivers to boot image (optional)
# Dell Command | Deploy WinPE Driver Packs
# https://www.dell.com/support/kbdoc/en-us/000107478/dell-command-deploy-winpe-driver-packs
# Copy Dell WinPE 11 driver pack to the Drivers directory and expand (see example below)
# expand -f:* .\WinPE11.0-Drivers-A06-336TP.cab .
if ((Test-Path -Path $pathDrivers) -and ((Get-ChildItem -Path "$pathDrivers").Count -ne 0)) {
    # Add drivers if folder is not empty. It does not check whether the files are actually drivers.
    Write-Host "Adding drivers..."
    Add-WindowsDriver -Path "$pathMount" -Driver "$pathDrivers" -Recurse
}
else {
    Write-Host "Drivers folder does not exists or it is empty."
}

# Add optional components to boot image
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#how-to-add-optional-components
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference?view=windows-11#winpe-optional-components
# For Windows 11: If you're launching Windows Setup from WinPE, make sure your WinPE image includes the WinPE-WMI and WinPE-SecureStartup optional components.
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro?view=windows-11#notes-on-running-windows-setup-in-windows-pe
foreach ($oc in $listOCs) {
    Write-Host "Adding $oc.cab"
    Add-WindowsPackage -Path "$pathMount" -Verbose -PackagePath "$pathOC\$oc.cab"

    if (Test-Path -Path "$pathOCen\$oc`_en-us.cab") {
        Write-Host "Adding $oc`_en-us.cab"
        Add-WindowsPackage -Path "$pathMount" -Verbose -PackagePath "$pathOCen\$oc`_en-us.cab"
    }
    
}

# Set the power scheme to high performance
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-customize?view=windows-11#set-the-power-scheme-to-high-performance
$pathStartnetcmd = Join-Path -Path $pathMount -ChildPath "windows\system32\startnet.cmd"
Write-Host "Setting the power scheme to high-performance."
"powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" | Out-File -FilePath "$pathStartnetcmd" -Append -Encoding ascii

# Add cumulative update (CU) to boot image
# Windows 11 24H2 updates at https://support.microsoft.com/en-us/help/5045988
# https://catalog.update.microsoft.com/
# https://learn.microsoft.com/en-us/windows/deployment/update/catalog-checkpoint-cumulative-updates
# https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update
# Add-WindowsPackage -PackagePath "<Path_to_CU_MSU_update>\<CU>.msu" -Path "<Mount_folder_path>" -Verbose
if ( (Test-Path -Path "$pathCU") -and ((Get-ChildItem -Path "$pathCU").Count -ne 0) -and ($listCUs.Count -gt 0) ) {
    Write-Host "Adding cumulative update(s)..."
    foreach ($cu in $listCUs) {
        if (Test-Path -Path "$pathCU\*$cu*") {
            Write-Host "Adding $cu"

            $nameCU = (Get-ChildItem -Path "$pathCU\*$cu*").Name
            $pathTemp = "$pathCU\$nameCU"
            Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathTemp"
        }
        else {
            Write-Host "$cu does not exist!"
        }

    }
}
else {
    Write-Host "Cumulative updates folder does not exist or no updates to add."
}

# Perform component cleanup
Write-Host "Performing component cleanup..."
Start-Process "$pathADKDism" -ArgumentList " /Image:${pathMount} /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile

# Unmount boot image and save changes
Write-Host "Unmounting and saving changes to winpe.wim..."
Dismount-WindowsImage -Path "$pathMount" -Save -Verbose


Write-Host "Script completed at $(Get-Date) and took $( ( (Get-Date) - $StartDateTime).Minutes) minutes"
