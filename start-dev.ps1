param(
  [switch]$NoDocker,
  [switch]$NoMobile,
  [switch]$SkipInstall,
  [switch]$Restart,
  [string]$HostName = "127.0.0.1",
  [int]$AdminPort = 5173,
  [int]$MobilePort = 5174
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$BackendDir = Join-Path $Root "backend"
$AdminDir = Join-Path $Root "front/admin"
$MobileDir = Join-Path $Root "front/mobile"
$RunRoot = Join-Path $Root ".codex-run"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$RunDir = Join-Path $RunRoot $Stamp

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Checked {
  param(
    [string]$Command,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & cmd.exe /c $Command
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code ${LASTEXITCODE}: $Command"
    }
  }
  finally {
    Pop-Location
  }
}

function Test-ListeningPort {
  param([int]$Port)
  try {
    return [bool](Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
  }
  catch {
    return $false
  }
}

function Get-PortOwners {
  param([int[]]$Ports)
  try {
    return @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
      Where-Object { $Ports -contains $_.LocalPort } |
      Select-Object -ExpandProperty OwningProcess -Unique)
  }
  catch {
    return @()
  }
}

function Stop-DevPorts {
  param([int[]]$Ports)

  $owners = @(Get-PortOwners -Ports $Ports | Where-Object { $_ })
  if ($owners.Count -eq 0) {
    Write-Host "No app ports are listening."
    return
  }

  $processes = @(Get-CimInstance Win32_Process | Where-Object { $owners -contains $_.ProcessId })
  foreach ($process in $processes) {
    Write-Host "Stopping $($process.Name) PID $($process.ProcessId)"
  }

  Stop-Process -Id $owners -Force -ErrorAction SilentlyContinue

  $deadline = (Get-Date).AddSeconds(15)
  do {
    $remaining = @(Get-PortOwners -Ports $Ports | Where-Object { $_ })
    if ($remaining.Count -eq 0) {
      Write-Host "App ports stopped."
      return
    }
    Start-Sleep -Milliseconds 500
  } while ((Get-Date) -lt $deadline)

  Write-Warning "Some app ports are still listening: $($remaining -join ',')"
}

function Wait-Http {
  param(
    [string]$Name,
    [string]$Url,
    [int]$Seconds = 60
  )

  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
      if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 500) {
        Write-Host "$Name ready: $Url"
        return $true
      }
    }
    catch {
      Start-Sleep -Milliseconds 1000
    }
  }

  Write-Warning "$Name did not respond before timeout: $Url"
  return $false
}

function Start-DevProcess {
  param(
    [string]$Name,
    [int]$Port,
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  $stdout = Join-Path $RunDir "$Name.out.log"
  $stderr = Join-Path $RunDir "$Name.err.log"

  if (Test-ListeningPort $Port) {
    Write-Host "$Name already listening on port $Port"
    return [pscustomobject]@{
      Name = $Name
      Status = "already_listening"
      Port = $Port
      ProcessId = $null
      Stdout = $stdout
      Stderr = $stderr
    }
  }

  $process = Start-Process `
    -FilePath $FilePath `
    -ArgumentList $Arguments `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -WindowStyle Hidden `
    -PassThru

  Write-Host "$Name started with PID $($process.Id), logs: $stdout"
  return [pscustomobject]@{
    Name = $Name
    Status = "started"
    Port = $Port
    ProcessId = $process.Id
    Stdout = $stdout
    Stderr = $stderr
  }
}

Write-Step "Checking tools"
Require-Command "go"
Require-Command "node"
Require-Command "cmd.exe"
if (-not $NoDocker) {
  Require-Command "docker"
}
if (-not $NoMobile) {
  Require-Command "flutter"
}

if ($Restart) {
  Write-Step "Stopping app ports"
  Stop-DevPorts -Ports @(8080, $AdminPort, $MobilePort)
}

if (-not $NoDocker) {
  Write-Step "Starting Docker services"
  Push-Location $Root
  try {
    docker compose up -d postgres minio redis
  }
  finally {
    Pop-Location
  }
}

if (-not $SkipInstall) {
  if (-not (Test-Path (Join-Path $AdminDir "node_modules"))) {
    Write-Step "Installing admin dependencies"
    Invoke-Checked -Command "npm install" -WorkingDirectory $AdminDir
  }

  if (-not $NoMobile -and -not (Test-Path (Join-Path $MobileDir ".dart_tool/package_config.json"))) {
    Write-Step "Installing mobile dependencies"
    Invoke-Checked -Command "flutter pub get" -WorkingDirectory $MobileDir
  }
}

$services = @()

if (-not (Test-ListeningPort 8080)) {
  Write-Step "Building backend"
  $backendExe = Join-Path $RunDir "backend-server.exe"
  Invoke-Checked -Command "go build -o `"$backendExe`" ./cmd/server" -WorkingDirectory $BackendDir
}
else {
  $backendExe = Join-Path $RunDir "backend-server.exe"
}

Write-Step "Starting backend"
$services += Start-DevProcess `
  -Name "backend" `
  -Port 8080 `
  -FilePath $backendExe `
  -Arguments @("-config", "config/local.yml") `
  -WorkingDirectory $BackendDir

Write-Step "Starting admin web"
$viteBin = Join-Path $AdminDir "node_modules/vite/bin/vite.js"
$services += Start-DevProcess `
  -Name "admin" `
  -Port $AdminPort `
  -FilePath "node" `
  -Arguments @($viteBin, "--host", $HostName, "--port", [string]$AdminPort) `
  -WorkingDirectory $AdminDir

if (-not $NoMobile) {
  Write-Step "Starting mobile web"
  $services += Start-DevProcess `
    -Name "mobile" `
    -Port $MobilePort `
    -FilePath "cmd.exe" `
    -Arguments @("/c", "flutter run -d web-server --web-hostname $HostName --web-port $MobilePort") `
    -WorkingDirectory $MobileDir
}

$pidFile = Join-Path $RunRoot "pids.json"
$services | ConvertTo-Json -Depth 4 | Set-Content -Path $pidFile -Encoding UTF8

Write-Step "Checking services"
[void](Wait-Http -Name "Backend" -Url "http://$HostName`:8080/api/health" -Seconds 60)
[void](Wait-Http -Name "Admin" -Url "http://$HostName`:$AdminPort/" -Seconds 60)
if (-not $NoMobile) {
  [void](Wait-Http -Name "Mobile" -Url "http://$HostName`:$MobilePort/" -Seconds 120)
}

$ports = if ($NoMobile) { @(8080, $AdminPort) } else { @(8080, $AdminPort, $MobilePort) }
$ownerIds = @(Get-PortOwners -Ports $ports)

Write-Host ""
Write-Host "Ready"
Write-Host "  Backend: http://$HostName`:8080/api/health"
Write-Host "  Admin:   http://$HostName`:$AdminPort/"
if (-not $NoMobile) {
  Write-Host "  Mobile:  http://$HostName`:$MobilePort/"
}
Write-Host "  Logs:    $RunDir"
Write-Host "  PIDs:    $pidFile"
if ($ownerIds.Count -gt 0) {
  Write-Host ""
  Write-Host "Stop app ports:"
  Write-Host "  Stop-Process -Id $($ownerIds -join ',')"
}
