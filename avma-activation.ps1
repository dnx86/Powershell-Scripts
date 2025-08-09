# Quick and dirty script to install the appropriate AVMA key on
# Windows Server 2012 R2, 2016, 2019, 2022, and 2025
# Standard and Datacenter editions.
# Server Core NOT supported.
# https://learn.microsoft.com/en-us/windows-server/get-started/automatic-vm-activation
# https://learn.microsoft.com/en-us/windows-server/get-started/upgrade-conversion-options

#Requires -RunAsAdministrator

$isServer = (Get-CimInstance Win32_OperatingSystem).Caption -match "Server"
$isCore = (Get-CimInstance Win32_OperatingSystem).Caption -match "Server Core"
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption

# Determine if script is running in Hyper-V.
$biosName = (Get-CimInstance Win32_BIOS).Name
if ($biosName -notlike "Hyper-V*") {
    Write-Host "This script only runs in a Hyper-V VM! Exiting!"
    Exit
}
# Check if OS name has "Server" in it.
elseif ($isServer -eq $false) {
  Write-Host "Windows Server not detected! Exiting!"
  Exit
}
# Check if it is Windows Server Core.
elseif ($isCore) {
  Write-Host "Windows Server Core not supported! Exiting!"
  Exit
}
# Check Windows Server edition.
elseif ($osCaption -notmatch ("Standard|Datacenter")) {
  Write-Host "Only Standard or Datacenter editions are supported! Exiting!"
  Exit
}
else {
  $osCaption -match ("Standard|Datacenter")
  $serverEdition = $Matches[0]
  $setEdition

  $avmaKey
  if ($serverEdition -match "Standard") {
    $setEdition = "ServerStandard"
    switch -Regex ($osCaption) {
      "2012 R2" {
        $avmaKey = "DBGBW-NPF86-BJVTX-K3WKJ-MTB6V"
        break
      }
      "2016" {
        $avmaKey = "C3RCX-M6NRP-6CXC9-TW2F2-4RHYD"
        break
      }
      "2019" {
        $avmaKey = "TNK62-RXVTB-4P47B-2D623-4GF74"
        break
      }
      "2022" {
        $avmaKey = "YDFWN-MJ9JR-3DYRK-FXXRW-78VHK"
        break
      }
      "2025" {
        $avmaKey = "WWVGQ-PNHV9-B89P4-8GGM9-9HPQ4"
        break
      }
    }
  }
  elseif ($serverEdition -match "Datacenter") {
    $setEdition = "ServerDatacenter"
    switch -Regex ($osCaption) {
      "2012 R2" { 
        $avmaKey = "Y4TGP-NPTV9-HTC2H-7MGQ3-DV4TW"
        break 
      }
        "2016" {
          $avmaKey = "TMJ3Y-NTRTM-FJYXT-T22BY-CWG3J"
          break 
      }
        "2019" {
          $avmaKey = "H3RNG-8C32Q-Q8FRX-6TDXV-WMBMW"
          break 
      }
        "2022" {
          $avmaKey = "W3GNR-8DDXR-2TFRP-H8P33-DV9BG"
          break 
      }
        "2025" {
          $avmaKey = "YQB4H-NKHHJ-Q6K4R-4VMY6-VCH67"
          break 
      }
    }
  }

  Write-Host "Installing the AVMA key. Windows Server will automatically reboot!"
  DISM /Quiet /Online /Set-Edition:$setEdition /ProductKey:$avmaKey /AcceptEula
}