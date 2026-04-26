param(
  [Parameter(Mandatory=$true)]
  [string[]]$Urls
)

function Invoke-Vm {
  param([string]$WsUrl, [hashtable]$Payload)
  $ws = [System.Net.WebSockets.ClientWebSocket]::new()
  $ws.ConnectAsync([Uri]::new($WsUrl), [Threading.CancellationToken]::None).Wait()
  $json = ($Payload | ConvertTo-Json -Compress -Depth 10)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
  $sb = [Text.StringBuilder]::new()
  $buf = [byte[]]::new(16384)
  do {
    $seg = [ArraySegment[byte]]::new($buf)
    $r = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).Result
    [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Count))
  } while (-not $r.EndOfMessage)
  $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", [Threading.CancellationToken]::None).Wait()
  return ($sb.ToString() | ConvertFrom-Json)
}

foreach ($u in $Urls) {
  Write-Host "[*] $u"
  try {
    $vm = Invoke-Vm -WsUrl $u -Payload @{ jsonrpc = "2.0"; id = 1; method = "getVM"; params = @{} }
    foreach ($iso in $vm.result.isolates) {
      Write-Host "    isolate: $($iso.id) ($($iso.name))"
      $reload = Invoke-Vm -WsUrl $u -Payload @{ jsonrpc = "2.0"; id = 2; method = "reloadSources"; params = @{ isolateId = $iso.id; force = $true } }
      Write-Host "    reloadSources -> $($reload.result.type) success=$($reload.result.success)"
      $reassemble = Invoke-Vm -WsUrl $u -Payload @{ jsonrpc = "2.0"; id = 3; method = "ext.flutter.reassemble"; params = @{ isolateId = $iso.id } }
      Write-Host "    reassemble    -> done"
    }
  } catch {
    Write-Host "    ERROR: $_"
  }
}
