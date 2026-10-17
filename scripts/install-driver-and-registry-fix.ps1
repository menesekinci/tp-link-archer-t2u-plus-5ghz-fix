# Self-elevate to Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host " TP-Link Archer T2U Plus (RTL8811AU) - Surucu ve Kayit Defteri Araci" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$driverInf = Join-Path $repoDir "driver\netrtwlanu.inf"

if (-not (Test-Path $driverInf)) {
    Write-Host "[HATA] Surucu INF dosyasi bulunamadi: $driverInf" -ForegroundColor Red
    exit 1
}

Write-Host "[1/4] Eski OEM surucu paketleri temizleniyor..." -ForegroundColor Yellow
$oemDrivers = & pnputil /enum-drivers | Select-String -Pattern "oem\d+\.inf" -Context 0, 4
foreach ($match in $oemDrivers) {
    if ($match.Context.PostContext -match "1030\.52\.1101\.2025|1030\.29\.1102\.2017") {
        $oemName = $match.Line.Trim() -replace ".*:\s*", ""
        Write-Host "      -> Kaldiriliyor: $oemName" -ForegroundColor Gray
        & pnputil /delete-driver $oemName /uninstall /force 2>$null
    }
}

Write-Host "[2/4] Resmi Realtek WHQL Surucusu (v1030.52.1216.2025) kuruluyor..." -ForegroundColor Yellow
& pnputil /add-driver $driverInf /install | Out-Null

Write-Host "[3/4] rtwlanu.sys 5 GHz 40MHz ve DMA/TX kararlilik parametreleri uygulaniyor..." -ForegroundColor Yellow
$adapters = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.DriverDesc -like "*TP-Link*" -or $_.DriverDesc -like "*Realtek*8811*" -or $_.MatchingDeviceId -like "*vid_2357&pid_0120*" }

foreach ($ad in $adapters) {
    $p = $ad.PSPath
    # Lock 5 GHz channel width to 40 MHz (prevents USB 2.0 480 Mbps bus saturation)
    Set-ItemProperty -Path $p -Name "BWSetting" -Value "1" -Type String -Force
    New-ItemProperty -Path $p -Name "BW40MHzFor5G" -Value "1" -PropertyType String -Force | Out-Null

    # Disable Firmware Low-Power Sleep (LPS) & Low Power PHY transitions
    Set-ItemProperty -Path $p -Name "bFwCtrlLPS" -Value "0" -Type String -Force
    Set-ItemProperty -Path $p -Name "bLowPowerEnable" -Value "0" -Type String -Force
    New-ItemProperty -Path $p -Name "bLeisurePs" -Value "0" -PropertyType String -Force | Out-Null

    # Disable thermal TX duty cycle throttling & runtime overwrite (0x1C13D3)
    Set-ItemProperty -Path $p -Name "TxDutyEnable" -Value "0" -Type String -Force
    New-ItemProperty -Path $p -Name "DynamicTxDutySW" -Value "0" -PropertyType String -Force | Out-Null
    Set-ItemProperty -Path $p -Name "EnableTxPowerLimit" -Value "0" -Type String -Force

    # Keep USB 2.0 8821A/8811A TX/RX aggregation & internal queue recovery active
    Set-ItemProperty -Path $p -Name "UsbRxAggMode" -Value "1" -Type String -Force
    New-ItemProperty -Path $p -Name "EnableUsbagga" -Value "1" -PropertyType String -Force | Out-Null
    Set-ItemProperty -Path $p -Name "SendPacketByTimer" -Value "1" -Type String -Force
    Set-ItemProperty -Path $p -Name "TcpReorder" -Value "1" -Type String -Force
    Set-ItemProperty -Path $p -Name "HangDetection" -Value "1" -Type String -Force
    Set-ItemProperty -Path $p -Name "USBResetTxHang" -Value "0" -Type String -Force
    Set-ItemProperty -Path $p -Name "BeamformCap" -Value "0" -Type String -Force
    Set-ItemProperty -Path $p -Name "EnableAdaptivity" -Value "0" -Type String -Force
}

Write-Host "[4/4] USB Secmeli Askiya Alma kapatiliyor ve Wi-Fi yeniden baslatiliyor..." -ForegroundColor Yellow
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
Restart-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

netsh wlan show interfaces
Write-Host "[BASARILI] Surucu ve kayit defteri optimizasyonu tamamlandi!" -ForegroundColor Green
