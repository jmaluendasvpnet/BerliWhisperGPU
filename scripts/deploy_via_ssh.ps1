# Deploy BerliWhisperGPU en Ser-IA (berlia@172.16.10.27:3108).
# Uso: .\scripts\deploy_via_ssh.ps1
# Lee BERLIONE_SSH_PASSWORD de Berlinas360BackEnd2\.env si no está en el entorno.
# GitHub: clave de solo lectura en ~/.ssh/berliwhisper_deploy (no va en la URL).

$ErrorActionPreference = 'Stop'
$Target = if ($env:BERLIONE_OCR_SSH) { $env:BERLIONE_OCR_SSH } else { 'berlia@172.16.10.27' }
$Ssh = Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe'
$Repo = if ($env:BERLIONE_WHISPER_REMOTE) { $env:BERLIONE_WHISPER_REMOTE } else { '$HOME/Documentos/BerliONE/BerliWhisperGPU' }

function Set-AskPass([string]$Password) {
    $secretFile = Join-Path $env:TEMP "berliwhisper-ssh-secret-$PID.txt"
    Set-Content -LiteralPath $secretFile -Value $Password -Encoding UTF8 -NoNewline
    $cmdPath = Join-Path $env:TEMP "berliwhisper-ssh-askpass-$PID.cmd"
    $escaped = $secretFile.Replace("'", "''")
    @(
        '@echo off',
        "powershell -NoProfile -WindowStyle Hidden -Command ""Write-Output (Get-Content -LiteralPath '$escaped' -Raw)"""
    ) | Set-Content -LiteralPath $cmdPath -Encoding ASCII
    $env:SSH_ASKPASS = $cmdPath
    $env:SSH_ASKPASS_REQUIRE = 'force'
    if (-not $env:DISPLAY) { $env:DISPLAY = '1' }
    return $secretFile, $cmdPath
}

$plain = $env:BERLIONE_SSH_PASSWORD
if (-not $plain) {
    $envFile = if ($env:BERLIONE_LOCAL_ENV_FILE) { $env:BERLIONE_LOCAL_ENV_FILE } else {
        Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Berlinas360BackEnd2\.env'
    }
    if (Test-Path -LiteralPath $envFile) {
        foreach ($line in [System.IO.File]::ReadAllLines($envFile)) {
            $t = $line.Trim()
            if ($t.StartsWith('BERLIONE_SSH_PASSWORD=')) {
                $plain = $t.Substring(22).Trim().Trim('"').Trim("'")
                break
            }
        }
    }
}
if (-not $plain) { throw 'Falta BERLIONE_SSH_PASSWORD en Berlinas360BackEnd2\.env' }
$temps = Set-AskPass $plain
$opts = @(
    '-o', 'PreferredAuthentications=password',
    '-o', 'PubkeyAuthentication=no',
    '-o', 'NumberOfPasswordPrompts=1',
    '-o', 'StrictHostKeyChecking=accept-new'
)
$remote = @"
set -e
cd $Repo
git remote set-url origin git@github.com:jmaluendasvpnet/BerliWhisperGPU.git
touch /home/berlia/.ssh/known_hosts
if ! grep -q github.com /home/berlia/.ssh/known_hosts; then ssh-keyscan -t ed25519 github.com >> /home/berlia/.ssh/known_hosts 2>/dev/null; fi
export GIT_SSH_COMMAND='ssh -i /home/berlia/.ssh/berliwhisper_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes'
git fetch origin
git checkout main
git reset --hard origin/main
echo COMMIT:`$(git log -1 --oneline)
if command -v fuser >/dev/null 2>&1; then fuser -k 3108/tcp >/dev/null 2>&1 || true; fi
ps -eo pid,cmd | grep 'env_whisper/bin/python' | grep 'app.py' | grep -v bash | grep -v grep | awk '{print `$1}' | while read -r wpid; do
  kill "`$wpid" >/dev/null 2>&1 || true
done
sleep 1
nohup ./env_whisper/bin/python app.py >>/tmp/berliwhisper.log 2>&1 &
echo STARTED
ok=
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if curl -sf http://127.0.0.1:3108/health >/dev/null; then ok=1; break; fi
  sleep 2
done
if [ -z "`$ok" ]; then echo HEALTH_FAIL; tail -n 30 /tmp/berliwhisper.log; exit 1; fi
echo HEALTH_OK
ps -eo pid,ppid,cmd | grep BerliWhisperGPU | grep -v grep || true
"@
$remote = $remote -replace "`r", ""
try {
    & $Ssh @opts $Target $remote
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Remove-Item -LiteralPath $temps -Force -ErrorAction SilentlyContinue
    Remove-Item Env:SSH_ASKPASS -ErrorAction SilentlyContinue
    Remove-Item Env:SSH_ASKPASS_REQUIRE -ErrorAction SilentlyContinue
}
