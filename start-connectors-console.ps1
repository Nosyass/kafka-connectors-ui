param(
  [int] $Port = 8095,
  [string] $ConfigPath = "$PSScriptRoot\connectors-env.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConfigPath)) {
  Copy-Item "$PSScriptRoot\connectors-env.example.json" $ConfigPath
  Write-Host "Created $ConfigPath - edit endpoint URLs before using UAT/STA/PROD."
}

function Read-EnvConfig {
  $json = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  $map = @{}
  foreach ($p in $json.PSObject.Properties) {
    $map[$p.Name.ToLowerInvariant()] = [string]$p.Value.url
  }
  return $map
}

function Send-Text($ctx, [int]$status, [string]$text, [string]$contentType = "text/plain; charset=utf-8") {
  $bytes = [Text.Encoding]::UTF8.GetBytes($text)
  $ctx.Response.StatusCode = $status
  $ctx.Response.ContentType = $contentType
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}

function Send-File($ctx, [string]$path, [string]$contentType) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $ctx.Response.StatusCode = 200
  $ctx.Response.ContentType = $contentType
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}

function Content-TypeFor([string]$path) {
  switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8" }
    ".css"  { "text/css; charset=utf-8" }
    ".js"   { "application/javascript; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    default { "application/octet-stream" }
  }
}

function Proxy-Request($ctx, [string]$env, [string]$tail) {
  $envs = Read-EnvConfig
  if (-not $envs.ContainsKey($env)) {
    Send-Text $ctx 404 "Unknown env '$env'."
    return
  }
  $base = $envs[$env].TrimEnd("/")
  if ([string]::IsNullOrWhiteSpace($base)) {
    Send-Text $ctx 400 "No URL configured for env '$env' in $ConfigPath."
    return
  }

  $path = "/" + $tail.TrimStart("/")
  $target = $base + $path + $ctx.Request.Url.Query
  $req = [Net.HttpWebRequest]::Create($target)
  $req.Method = $ctx.Request.HttpMethod
  $req.Accept = "application/json"

  foreach ($h in $ctx.Request.Headers.AllKeys) {
    if ($h -match "^(Host|Connection|Content-Length|Transfer-Encoding|Keep-Alive|Proxy-Connection)$") { continue }
    try { $req.Headers[$h] = $ctx.Request.Headers[$h] } catch {}
  }

  if ($ctx.Request.HasEntityBody) {
    $req.ContentType = $ctx.Request.ContentType
    $ctx.Request.InputStream.CopyTo($req.GetRequestStream())
  }

  try {
    $resp = $req.GetResponse()
  } catch [Net.WebException] {
    $resp = $_.Exception.Response
    if ($null -eq $resp) {
      Send-Text $ctx 502 $_.Exception.Message
      return
    }
  }

  $ctx.Response.StatusCode = [int]$resp.StatusCode
  $ctx.Response.ContentType = $resp.ContentType
  $ctx.Response.Headers["Access-Control-Allow-Origin"] = "*"
  $ctx.Response.Headers["Access-Control-Allow-Headers"] = "authorization,content-type"
  $ctx.Response.Headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
  $resp.GetResponseStream().CopyTo($ctx.Response.OutputStream)
  $ctx.Response.Close()
  $resp.Close()
}

$listener = [Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host ("Kafka Connect Console: {0}connectors.html" -f $prefix)
Write-Host ("Proxy pattern: " + $prefix + "proxy/{dev|uat|sta|prod}/connectors")
Write-Host "Press Ctrl+C to stop."

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($ctx.Request.HttpMethod -eq "OPTIONS") {
      $ctx.Response.Headers["Access-Control-Allow-Origin"] = "*"
      $ctx.Response.Headers["Access-Control-Allow-Headers"] = "authorization,content-type"
      $ctx.Response.Headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
      $ctx.Response.StatusCode = 204
      $ctx.Response.Close()
      continue
    }
    if ($path -match "^/proxy/([^/]+)(/.*)?$") {
      Proxy-Request $ctx (($matches[1]).ToLowerInvariant()) ($matches[2] -replace "^/", "")
      continue
    }
    if ($path -eq "/") { $path = "/connectors.html" }
    $file = Join-Path $PSScriptRoot ($path.TrimStart("/") -replace "/", "\")
    $root = [IO.Path]::GetFullPath($PSScriptRoot)
    $full = [IO.Path]::GetFullPath($file)
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full)) {
      Send-Text $ctx 404 "Not found"
      continue
    }
    Send-File $ctx $full (Content-TypeFor $full)
  } catch {
    Send-Text $ctx 500 $_.Exception.Message
  }
}
