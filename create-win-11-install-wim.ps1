# Purpose of the script is to automate the creation of a custom Windows 11 wim file.

#Requires -RunAsAdministrator
#Requires -Version 5.1

$StartDateTime = Get-Date
Write-Host "Script started at $StartDateTime" -ForegroundColor Red

# Variables
# List of cumulative updates in the CUs folder. KB names are in double quotes separated by commas.
$listCUs = @("KB5065789")

# List of apps to remove.
$listApps = @(
    "Clipchamp.Clipchamp",
    "Microsoft.BingNews",
    "Microsoft.BingSearch",
    "Microsoft.BingWeather",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "MicrosoftCorporationII.QuickAssist",
    "MicrosoftWindows.CrossDevice",
    "Microsoft.WindowsAlarms",
    "Microsoft.Todos",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.GamingApp",
    "Microsoft.Windows.DevHome"
)

# List of optional features to remove.
$listFeatures = @("MicrosoftWindowsPowerShellV2Root", "MicrosoftWindowsPowerShellV2")

# Constant Paths
$pathADKDism = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe")
$ADKInstallLocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10")
$ADKWinPELocation = [System.Environment]::ExpandEnvironmentVariables("%ProgramFiles(x86)%\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim")

# ISO folder
$pathIsofolder = "$PSScriptRoot\iso"

# Path to file in iso folder
$pathFile

# Mount folder
$pathMount = "$PSScriptRoot\Mount"

# Cumulative Updates (CUs) folder
$pathCU = "$PSScriptRoot\CUs"

# Drivers folder
$pathDrivers = "$PSScriptRoot\Drivers"

# Wim folder and file
$pathWimFolder = "$PSScriptRoot\wim"
$pathWimFile = "$pathWimFolder\install.wim"
$pathSwmFile = "$pathWimFolder\install.swm"

# unattend.xml file
$pathUnattendXml = "$PSScriptRoot\unattend.xml"
$useUnattendFile = $true

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

# Check if the iso folder exists and is not empty
if ( !(Test-Path -Path "$pathIsofolder") ) {
    Write-Host "The iso folder does not exists! Script cannot proceed!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathIsofolder").Count -eq 0 ) {
    Write-Host "The iso folder is EMPTY! Script cannot proceed!" -ForegroundColor Yellow
    Write-Host "Put a SINGLE ISO, ESD, or WIM file with Windows 11 Pro in this folder" -ForegroundColor Yellow
    Write-Host "and run this script again!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathIsofolder").Count -gt 1 ) {
    Write-Host "Feature to handle multiple files not implemented yet! Script cannot proceed!" -ForegroundColor Yellow
    Write-Host "Ensure a SINGLE ISO, ESD, or WIM file with Windows 11 Pro is in this folder" -ForegroundColor Yellow
    Write-Host "and run this script again!" -ForegroundColor Yellow
    Exit
}
elseif ( (Get-ChildItem -Path "$pathIsofolder").Count -eq 1 ) {
    #Perform checks on ISO, wim, or ESD file
    $theFile = Get-ChildItem -Path "$pathIsofolder" -Recurse -Include "*.iso", "*.esd", "*.wim"
    if ($theFile.Count -eq 0) {
        Write-Host "ISO, ESD, or WIM file not present! Exiting!" -ForegroundColor Yellow
        Exit
    }

    $pathFile = $theFile.FullName

    # Delete the wim folder if it already exists and create a new one.
    if (Test-Path -Path "$pathWimFolder") {
        Write-Host "Removing existing wim folder..." -ForegroundColor DarkGreen
        Remove-Item -Path "$pathWimFolder" -Recurse -Force
    }
    Write-Host "Creating new wim folder..." -ForegroundColor DarkGreen
    New-Item -Path "$pathWimFolder" -ItemType Directory

    if ( ($theFile.Extension -ilike "*esd") -or ($theFile.Extension -ilike "*wim") ) {
        # Export Windows 11 Pro from install.wim
        $nameImage = "Windows 11 Pro"
        $indexImage = (Get-WindowsImage -Name $nameImage -ImagePath "$pathFile").ImageIndex
        Write-Host "Exporting $nameImage at index $indexImage." -ForegroundColor DarkBlue
        Write-Host "Source = $pathFile"
        Write-Host "Destination = $pathWimFile"
        Export-WindowsImage -SourceImagePath "$pathFile" -SourceIndex $indexImage -DestinationImagePath "$pathWimFile"
    }
    elseif ( ($theFile.Extension -ilike "*iso") ) {
        # Mount ISO file
        Write-Host "Mounting the ISO file." -ForegroundColor DarkGreen
        try {
            $isoMountPointDriveLetter = (Mount-DiskImage -StorageType ISO -ImagePath "$pathFile" -ErrorAction Stop -PassThru | Get-Volume).DriveLetter
            $pathISOWimFile = Join-Path -Path "${isoMountPointDriveLetter}:" -ChildPath "sources\install.wim"

            # Export Windows 11 Pro from install.wim
            $nameImage = "Windows 11 Pro"
            $indexImage = (Get-WindowsImage -Name $nameImage -ImagePath "$pathISOWimFile").ImageIndex
            Write-Host "Exporting $nameImage at index $indexImage." -ForegroundColor DarkBlue
            Write-Host "Source = $pathISOWimFile"
            Write-Host "Destination = $pathWimFile"
            Export-WindowsImage -SourceImagePath "$pathISOWimFile" -SourceIndex $indexImage -DestinationImagePath "$pathWimFile"
        }
        catch {
            Write-Warning $_
        }
        finally {
            # Unmount the ISO.
            Write-Host "Unmounting the ISO image." -ForegroundColor DarkGreen
            Dismount-DiskImage -ImagePath "$pathFile" -ErrorAction Stop | Out-Null
        }
    }
}
else {
    Write-Host "Unknown error involving iso folder! Exiting!" -ForegroundColor Yellow
    Exit
}

# Delete the mount folder if it already exists and create a new one.
if ( (Test-Path -Path "$pathMount") -and ((Get-ChildItem -Path "$pathMount").Count -eq 0) ) {
    Write-Host "Deleting existing Mount folder..." -ForegroundColor DarkGreen
    Remove-Item -Path "$pathMount" -Force
}
elseif ((Test-Path -Path "$pathMount") -and ((Get-ChildItem -Path "$pathMount").Count -gt 0)) {
    Write-Host "Reboot the computer and run the command below with admin privileges!" -ForegroundColor Yellow
    Write-Host "Dismount-WindowsImage -Path "$pathMount" -Discard" -ForegroundColor Yellow
    Exit
}
Write-Host "Creating new Mount folder..." -ForegroundColor DarkGreen
New-Item -Path "$pathMount" -ItemType Directory

# Mount image to mount folder.
Write-Host "Mounting the wim file." -ForegroundColor DarkGreen
Mount-WindowsImage -Path "$pathMount" -ImagePath "$pathWimFile" -Index 1 -Verbose -ErrorAction Stop  # Index MUST BE 1

#Remove app packages from the mounted image
foreach ($app in $listApps){
    try {
        Write-Host "Removing $app" -ForegroundColor DarkCyan
        $app = '*' + $app + '*'
        Get-AppxProvisionedPackage -Path "$pathMount" | Where-Object { $_.DisplayName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -PackageName $_.PackageName -Path "$pathMount" }
    }
    catch {
        Write-Host "Unable to remove $app from the mounted image" -ForegroundColor Yellow
    }
}

# Disable Windows Optional Features
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/enable-or-disable-windows-features-using-dism?view=windows-11
# Disable-WindowsOptionalFeature -Path "$pathMount" -FeatureName MicrosoftWindowsPowerShellV2Root, MicrosoftWindowsPowerShellV2
foreach ($feature in $listFeatures){
    Write-Host "Removing $feature" -ForegroundColor DarkCyan
    Disable-WindowsOptionalFeature -Path "$pathMount" -FeatureName $feature -ErrorAction Ignore
}

# Add drivers to boot image (optional)
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-and-remove-drivers-to-an-offline-windows-image?view=windows-11
if ((Test-Path -Path $pathDrivers) -and ((Get-ChildItem -Path "$pathDrivers").Count -ne 0)) {
    # Add drivers if folder is not empty. It does not check whether the files are actually drivers.
    Write-Host "Adding drivers..." -ForegroundColor DarkGreen
    Add-WindowsDriver -Path "$pathMount" -Driver "$pathDrivers" -Recurse
}
else {
    Write-Host "Drivers folder does not exists or it is empty." -ForegroundColor DarkMagenta
}

# Add cumulative update (CU)
# It's important to apply the latest cumulative update last, to ensure Features on Demand,
# Optional Components, and Languages are updated from their initial release state.
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/servicing-the-image-with-windows-updates-sxs?view=windows-11
# https://learn.microsoft.com/en-us/windows/deployment/update/media-dynamic-update
# https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
# https://catalog.update.microsoft.com/
# https://aka.ms/Windows11UpdateHistory
# Add-WindowsPackage -PackagePath "<Path_to_CU_MSU_update>\<CU>.msu" -Path "<Mount_folder_path>" -Verbose
if ( (Test-Path -Path "$pathCU") -and ((Get-ChildItem -Path "$pathCU").Count -ne 0) -and ($listCUs.Count -gt 0) ) {
    Write-Host "Adding cumulative update(s)..." -ForegroundColor DarkGreen
    foreach ($cu in $listCUs) {
        if (Test-Path -Path "$pathCU\*$cu*") {
            Write-Host "Adding $cu" -ForegroundColor DarkCyan

            $nameCU = (Get-ChildItem -Path "$pathCU\*$cu*").Name
            $pathTemp = "$pathCU\$nameCU"
            Add-WindowsPackage -Path "$pathMount" -PackagePath "$pathTemp"
        }
        else {
            Write-Host "$cu does not exist!" -ForegroundColor DarkMagenta
        }

    }
}
else {
    Write-Host "Cumulative updates folder does not exist or no updates to add." -ForegroundColor DarkMagenta
}

# Perform component cleanup
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder?view=windows-11
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/mount-and-modify-a-windows-image-using-dism?view=windows-11#reduce-the-size-of-an-image
Write-Host "Performing component cleanup..." -ForegroundColor DarkGreen
Start-Process "$pathADKDism" -ArgumentList " /Image:${pathMount} /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile -NoNewWindow


# Make the Panther folder and copy the unattend file to it
# Set $useUnattendFile to $false if not using unattend file
if ( $useUnattendFile -and (Test-Path -Path $pathUnattendXml) ) {
    if (!(Test-Path -Path ".\Mount\Windows\Panther")) {
        Write-Host "Creating the Panther folder."
        Mkdir ".\Mount\Windows\Panther"
    }

    Write-Host "Copying the unattend file to the Panther folder."
    Copy-Item "$pathUnattendXml" -Destination ".\Mount\Windows\Panther\unattend.xml"
}
else {
    Write-Host "unattend.xml does not exists or `$useUnattendFile is false!"
}


# Unmount the image and save changes
# https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/mount-and-modify-a-windows-image-using-dism?view=windows-11#unmounting-an-image
Write-Host "Unmounting and saving changes to the wim file..." -ForegroundColor DarkGreen
Dismount-WindowsImage -Path "$pathMount" -Save -Verbose

Write-Host "Script completed at $(Get-Date) and took $( (New-TimeSpan -Start $StartDateTime).Hours ) hours, $( (New-TimeSpan -Start $StartDateTime).Minutes ) minutes, $( (New-TimeSpan -Start $StartDateTime).Seconds ) seconds" -ForegroundColor Red

# Useful commands to run.
Write-Host "Run:"
Write-Host "Dism /Split-Image /ImageFile:$pathWimFile /SWMFile:$pathSwmFile /FileSize:3800" -ForegroundColor DarkCyan