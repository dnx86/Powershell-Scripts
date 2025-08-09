# Purpose - Installs Windows ADK and Windows PE add-on.
# Adapted from KB5042429 recovery tool.

# References
# https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
# https://go.microsoft.com/fwlink/?linkid=2280386

#Requires -RunAsAdministrator

# Constant Paths
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKInstaller = [System.Environment]::ExpandEnvironmentVariables("%TEMP%\adksetup.exe")

$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")
$ADKWinPEAddOnInstaller = [System.Environment]::ExpandEnvironmentVariables("%TEMP%\adkwinpesetup.exe")

#
# Check if Windows ADK is installed
#
Write-Host "Checking if Windows ADK is installed..."
$ADKInstalled = Test-Path -Path "$ADKInstallLocation\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
if ($ADKInstalled) {
    Write-Host "  -- An installation of Windows ADK was found on device."
}
elseif (Test-Path -Path "$PSScriptRoot\adksetup.exe") {
    $pathTemp = "$PSScriptRoot\adksetup.exe"
    # Verify digital signature
    Write-Host "Verifying digital signature. . ."
    if ((Get-AuthenticodeSignature $pathTemp).Status -ne "Valid") {
        Write-Host "Error - Invalid or no signature"
        Exit
    }
    elseif ( (Get-AuthenticodeSignature $pathTemp).Status -eq "Valid" ) {
        Write-Host "Valid digital signature."
    }

    Write-Host "Installing Windows ADK..."
    Start-Process -FilePath $pathTemp -Wait -ArgumentList '/quiet /ceip off /features OptionId.DeploymentTools'
    Write-Host "  -- Successfully installed Windows ADK."
}
else {
    Write-Host "  -- An installation of Windows ADK was not found on the device."
    Write-Host "This script will now download and install Windows ADK."

    # Download the ADK Installer
    Write-Host "Downloading Windows ADK..."

    # Remove existing installation file
    if (Test-Path $ADKInstaller) {
        Remove-Item $ADKInstaller -Verbose
    }

    # Download
    # Windows ADK 10.1.26100.2454 (December 2024)
    $url = "https://go.microsoft.com/fwlink/?linkid=2289980"
    Start-BitsTransfer -Source $url -Destination $ADKInstaller

    # Verify digital signature
    if ((Get-AuthenticodeSignature $ADKInstaller).Status -ne "Valid") {
        Write-Host "Error - Invalid or no signature"
        Exit
    }

    Write-Host "Installing Windows ADK..."
    Start-Process -FilePath $ADKInstaller -Wait -ArgumentList '/quiet /ceip off /features OptionId.DeploymentTools'
    Write-Host "  -- Successfully installed Windows ADK."
}

#
# Check if Windows ADK WinPE add-on is installed
#
Write-Host "Checking if Windows ADK WinPE add-on is installed..."
$ADKWinPEInstalled = Test-Path -Path $ADKWinPELocation
if ($ADKWinPEInstalled) {
    Write-Host "  -- An installation of Windows ADK WinPE add-on was found on this device."
}
elseif (Test-Path -Path "$PSScriptRoot\adkwinpesetup.exe") {
    $pathTemp = "$PSScriptRoot\adkwinpesetup.exe"
    # Verify digital signature
    Write-Host "Verifying digital signature. . ."
    if ((Get-AuthenticodeSignature $pathTemp).Status -ne "Valid") {
        Write-Host "Error - Invalid or no signature"
        Exit
    }
    elseif ( (Get-AuthenticodeSignature $pathTemp).Status -eq "Valid" ) {
        Write-Host "Valid digital signature."
    }

    Write-Host "Installing Windows ADK WinPE add-on..."
    Start-Process -FilePath $pathTemp -Wait -ArgumentList '/quiet /ceip off /features OptionId.WindowsPreinstallationEnvironment'
    Write-Host "  -- Successfully installed Windows ADK WinPE add-on."
}
else {
    Write-Host "  -- An installation for Windows ADK WinPE add-on was NOT found on this device."
    Write-Host "This script will now download and install the Windows ADK WinPE add-on."

    # Download the Windows ADK WinPE add-on installer
    Write-Host "Downloading Windows ADK WinPE add-on..."
    
    # Remove existing installation file
    if (Test-Path $ADKWinPEAddOnInstaller) {
        Remove-Item $ADKWinPEAddOnInstaller -verbose
    }

    # Download
    # Windows PE add-on for the Windows ADK 10.1.26100.2454 (December 2024)
    $url = "https://go.microsoft.com/fwlink/?linkid=2289981"
    Start-BitsTransfer -Source $url -Destination $ADKWinPEAddOnInstaller

    # Verify digital signature
    if ((Get-AuthenticodeSignature $ADKWinPEAddOnInstaller).Status -ne "Valid") {
        Write-Host "Error - Invalid or no signature"
        Exit
    }

    Write-Host "Installing Windows ADK WinPE add-on..."
    Start-Process -FilePath $ADKWinPEAddOnInstaller -Wait -ArgumentList '/quiet /ceip off /features OptionId.WindowsPreinstallationEnvironment'
    Write-Host "  -- Successfully installed Windows ADK WinPE add-on."
}