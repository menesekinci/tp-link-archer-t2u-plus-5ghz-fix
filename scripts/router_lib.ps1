# ZTE ZXHN H3601P V9.0 HTTP API Library (RSA PKCS#1 v1.5 + SHA-256 Check Header)
$script:base = 'http://192.168.1.1'
$script:ws = $null
$script:tmpTok = ''
$script:pubPem = @'
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAodPTerkUVCYmv28SOfRV
7UKHVujx/HjCUTAWy9l0L5H0JV0LfDudTdMNPEKloZsNam3YrtEnq6jqMLJV4ASb
1d6axmIgJ636wyTUS99gj4BKs6bQSTUSE8h/QkUYv4gEIt3saMS0pZpd90y6+B/9
hZxZE/RKU8e+zgRqp1/762TB7vcjtjOwXRDEL0w71Jk9i8VUQ59MR1Uj5E8X3WIc
fYSK5RWBkMhfaTRM6ozS9Bqhi40xlSOb3GBxCmliCifOJNLoO9kFoWgAIw5hkSIb
GH+4Csop9Uy8VvmmB+B3ubFLN35qIa5OG5+SDXn4L7FeAA5lRiGxRi8tsWrtew8w
nwIDAQAB
-----END PUBLIC KEY-----
'@

function Sha256Hex([string]$s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Router-Login([string]$User = 'admin', [string]$Pass = 'admin') {
    $script:ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    Invoke-WebRequest "$script:base/" -UseBasicParsing -WebSession $script:ws | Out-Null
    $j = Invoke-RestMethod "$script:base/?_type=loginData&_tag=login_entry" -WebSession $script:ws
    $tok = (Invoke-WebRequest "$script:base/?_type=loginData&_tag=login_token" -UseBasicParsing -WebSession $script:ws).Content
    $t = ([xml]$tok).DocumentElement.InnerText
    $r = Invoke-RestMethod "$script:base/?_type=loginData&_tag=login_entry" -Method Post -WebSession $script:ws -Body @{ Password = (Sha256Hex "$Pass$t"); Username = $User; _sessionTOKEN = $j.sess_token; action = 'login' }
    if (-not $r.login_need_refresh) { throw "Router login failed." }
    $page = (Invoke-WebRequest "$script:base/" -UseBasicParsing -WebSession $script:ws).Content
    $m = [regex]::Matches($page, '_sessionTmpToken\s*=\s*"([^"]*)"') | Select-Object -Last 1
    $script:tmpTok = [regex]::Replace($m.Groups[1].Value, '\\x([0-9a-fA-F]{2})', { param($mm) [string][char][Convert]::ToInt32($mm.Groups[1].Value,16) })
    if (-not $script:tmpTok) { throw "No session token found on router main page." }
}

function Router-Logout {
    try { Invoke-WebRequest "$script:base/?_type=loginData&_tag=logout_entry" -Method Post -Body @{ IF_LogOff = 1; _sessionTOKEN = $script:tmpTok } -UseBasicParsing -WebSession $script:ws | Out-Null } catch {}
}

function Router-View([string]$tag) {
    $v = (Invoke-WebRequest "$script:base/?_type=menuView&_tag=$tag&Menu3Location=0" -UseBasicParsing -WebSession $script:ws -Headers @{ Referer = "$script:base/" }).Content
    $mm = [regex]::Matches($v, '_sessionTmpToken\s*=\s*"([^"]*)"') | Select-Object -Last 1
    if ($mm) { $script:tmpTok = ([regex]::Matches($mm.Groups[1].Value, '\\x([0-9a-fA-F]{2})') | ForEach-Object { [char][Convert]::ToInt32($_.Groups[1].Value, 16) }) -join '' }
    return $v
}

function Router-Get([string]$dataTag) {
    (Invoke-WebRequest "$script:base/?_type=menuData&_tag=$dataTag" -UseBasicParsing -WebSession $script:ws -Headers @{ 'X-Requested-With' = 'XMLHttpRequest'; Referer = "$script:base/" }).Content
}

function Router-Parse([string]$xmlText) {
    $x = [xml]$xmlText
    $out = @()
    foreach ($obj in $x.DocumentElement.ChildNodes) {
        if ($obj.Name -notlike 'OBJ_*') { continue }
        foreach ($inst in $obj.SelectNodes('Instance')) {
            $h = [ordered]@{ _obj = $obj.Name }
            $names = @($inst.SelectNodes('ParaName')); $vals = @($inst.SelectNodes('ParaValue'))
            for ($i = 0; $i -lt $names.Count; $i++) { $h[$names[$i].InnerText] = $vals[$i].InnerText }
            $out += , $h
        }
    }
    return $out
}

function Router-Apply([string]$dataTag, [string]$postData) {
    $pd = "IF_ACTION=Apply&$postData&_sessionTOKEN=$script:tmpTok"
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportFromPem($script:pubPem)
    $check = [Convert]::ToBase64String($rsa.Encrypt([Text.Encoding]::UTF8.GetBytes((Sha256Hex $pd)), [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1))
    $r = Invoke-WebRequest "$script:base/?_type=menuData&_tag=$dataTag" -Method Post -Body $pd -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -WebSession $script:ws -Headers @{ Check = $check; 'X-Requested-With' = 'XMLHttpRequest'; Referer = "$script:base/" }
    $r.Content
}
