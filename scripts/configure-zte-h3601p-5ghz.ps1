param(
    [string]$RouterIp = "192.168.1.1",
    [string]$Username = "admin",
    [string]$Password = "admin",
    [string]$Channel = "44",
    [string]$BandWidth = "40MHz",
    [string]$Standard = "a,n",
    [string]$Ssid5G = "TurkNet1000Mbps_309BA_5G"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\router_lib.ps1"
$script:base = "http://$RouterIp"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " ZTE ZXHN H3601P V9.0 - 5 GHz (DEV.WIFI.RD2) Stabilite Yapilandirici" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

Write-Host "[1/3] Modeme ($RouterIp) giris yapiliyor..." -ForegroundColor Yellow
Router-Login -User $Username -Pass $Password
Router-View 'wlanBasic' | Out-Null

$stdEncoded = [uri]::EscapeDataString($Standard)
$postData = "_InstID=DEV.WIFI.RD2&BasicDataRates=6%2C9%2C12%2C18%2C24%2C36%2C48%2C54&OpDataRates=6%2C9%2C12%2C18%2C24%2C36%2C48%2C54&11nMode=1&GreenField=0&AutoChannelEnabled=0&Band=5GHz&Channel=$Channel&Standard=$stdEncoded&ChannelList=36%2C40%2C44%2C48%2C52%2C56%2C60%2C64%2C100%2C104%2C108%2C112%2C116%2C120%2C124%2C128%2C132%2C136&BandWidth=$BandWidth&CardMode=a%2Cn%2Can%2Canac%2Canacax&PowerEnhance=1&TxPower=100%25"

Write-Host "[2/3] 5 GHz Radyo (DEV.WIFI.RD2) -> Kanal: $Channel | Bant Genisligi: $BandWidth | Mod: $Standard uygulaniyor..." -ForegroundColor Yellow
Router-Apply 'wlan_basicadconf_lua.lua' $postData | Out-Null
Router-Logout

Write-Host "      -> Modem 5 GHz radyosunun yeniden baslamasi icin 8 saniye bekleniyor..." -ForegroundColor Gray
Start-Sleep -Seconds 8

Write-Host "[3/3] Windows 5 GHz profili ($Ssid5G) yeniden baglaniyor ve 1. oncelige aliniyor..." -ForegroundColor Yellow
netsh wlan set profileparameter name="$Ssid5G" connectionmode=auto | Out-Null
netsh wlan set profileorder name="$Ssid5G" interface="Wi-Fi" priority=1 | Out-Null
netsh wlan disconnect interface="Wi-Fi" | Out-Null
Start-Sleep -Seconds 2
netsh wlan connect name="$Ssid5G" interface="Wi-Fi" | Out-Null
Start-Sleep -Seconds 5

netsh wlan show interfaces
Write-Host "[BASARILI] Modem 5 GHz radyosu ve Windows Wi-Fi profili optimize edildi!" -ForegroundColor Green
