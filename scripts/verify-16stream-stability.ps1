param(
    [int]$Streams = 16,
    [int]$DurationSeconds = 60,
    [string]$GatewayIp = "192.168.1.1"
)

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host " 5 GHz Wi-Fi $Streams-Akisli (Speedtest Simülasyonu) Stabilite Testi" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

netsh wlan show interfaces | Select-String "State|SSID|Radio|Channel|Receive|Transmit|Signal" | ForEach-Object { Write-Host $_.Line }
$wifiIp = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if (-not $wifiIp) {
    Write-Host "[HATA] Wi-Fi arayuzunde IPv4 adresi bulunamadi!" -ForegroundColor Red
    exit 1
}
Write-Host "Wi-Fi IPv4: $wifiIp | Paralel TCP Akisi: $Streams | Sure: $DurationSeconds sn`n" -ForegroundColor Yellow

$urls = @(
    "http://cachefly.cachefly.net/100mb.test",
    "https://proof.ovh.net/files/100Mb.dat"
)
$procs = @()
for ($i = 0; $i -lt $Streams; $i++) {
    $u = $urls[$i % 2]
    $procs += Start-Process -FilePath "curl.exe" -ArgumentList "-4 --interface $wifiIp -s -o NUL `"$u`" `"$u`" `"$u`" `"$u`"" -PassThru -WindowStyle Hidden
}

$stat0 = Get-NetAdapterStatistics -Name "Wi-Fi"
$prevRx = $stat0.ReceivedBytes
$prevTx = $stat0.SentBytes
$prevTime = Get-Date
$steps = [int]($DurationSeconds / 5)

for ($s = 1; $s -le $steps; $s++) {
    Start-Sleep -Seconds 5
    $now = Get-Date
    $stat = Get-NetAdapterStatistics -Name "Wi-Fi"
    $dt = ($now - $prevTime).TotalSeconds
    $rxMbps = [math]::Round((($stat.ReceivedBytes - $prevRx) * 8 / 1e6) / $dt, 2)
    $txMbps = [math]::Round((($stat.SentBytes - $prevTx) * 8 / 1e6) / $dt, 2)
    $totMB = [math]::Round(($stat.ReceivedBytes - $stat0.ReceivedBytes) / 1MB, 2)
    $prevRx = $stat.ReceivedBytes
    $prevTx = $stat.SentBytes
    $prevTime = $now

    $pOut = ping.exe -n 1 -w 1000 -S $wifiIp $GatewayIp 2>&1 | Out-String
    $pStr = if ($pOut -match "time[=<](\d+ms)") { "OK ($($Matches[1]))" } else { "TIMEOUT" }
    Write-Host ("[{0,2}s] {1}-Stream RX: {2,6} Mbps | TX: {3,5} Mbps | Total: {4,6} MB | Gateway Ping: {5}" -f ($s * 5), $Streams, $rxMbps, $txMbps, $totMB, $pStr)
}

foreach ($p in $procs) {
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n--- YUK SONRASI MODEM PING KONTROLU ---" -ForegroundColor Cyan
ping.exe -n 4 -w 1000 -S $wifiIp $GatewayIp
