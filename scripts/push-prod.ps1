<#
.SYNOPSIS
  Deliberately pushes pending migrations (and optionally Edge Functions) to RATED PROD.

.DESCRIPTION
  The Supabase CLI is linked to DEV by default, so a plain `supabase db push` is always safe.
  This script is the only sanctioned way to reach PROD. It:
    1. refuses to run with uncommitted changes (prod only receives committed migrations),
    2. links the CLI to PROD and shows `migration list` + a dry run,
    3. requires you to type "prod" before applying anything,
    4. ALWAYS relinks the CLI to DEV afterwards — on success, failure, abort, or Ctrl+C.

  `supabase link` may prompt for the database password of each project.

.PARAMETER Functions
  Edge Functions to deploy to PROD after the migrations, e.g. elo-recalculate,send-notification.

.PARAMETER DryRunOnly
  Show what would be applied to PROD, then stop.

.EXAMPLE
  ./scripts/push-prod.ps1 -DryRunOnly
  ./scripts/push-prod.ps1
  ./scripts/push-prod.ps1 -Functions elo-recalculate,send-notification
#>
[CmdletBinding()]
param(
  [string[]] $Functions = @(),
  [switch] $DryRunOnly
)

$ErrorActionPreference = 'Stop'

$PROD = 'jkjndgcjyalmglnvvdrd'
$DEV  = 'ikjdfsjflzwkhlbootbx'

$repoRoot = Split-Path -Parent $PSScriptRoot
$refFile  = Join-Path $repoRoot 'supabase\.temp\project-ref'

function Get-LinkedRef {
  if (Test-Path $refFile) { return (Get-Content $refFile -Raw).Trim() }
  return ''
}

function Invoke-Supabase {
  & supabase @args
  if ($LASTEXITCODE -ne 0) { throw "supabase $($args -join ' ') failed (exit code $LASTEXITCODE)" }
}

function Set-Link([string] $ref) {
  Invoke-Supabase link --project-ref $ref
  $actual = Get-LinkedRef
  if ($actual -ne $ref) { throw "Expected the CLI to be linked to $ref, but project-ref says '$actual'." }
}

# ── Pre-flight: only committed work goes to prod ─────────────────────────────
$dirty = git -C $repoRoot status --porcelain
if ($dirty) {
  Write-Host 'Working tree has uncommitted changes. Commit or stash them first.' -ForegroundColor Red
  exit 1
}

$branch = (git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') {
  Write-Warning "You are on '$branch', not 'main'. Prod should normally receive only merged work."
  if ((Read-Host 'Continue anyway? (y/N)') -ne 'y') { exit 1 }
}

# ── Push ─────────────────────────────────────────────────────────────────────
Push-Location $repoRoot
try {
  Write-Host "`nLinking CLI to PROD ($PROD)..." -ForegroundColor Yellow
  Set-Link $PROD

  Invoke-Supabase migration list
  Invoke-Supabase db push --dry-run

  if ($DryRunOnly) {
    Write-Host "`nDry run only - nothing was applied to PROD." -ForegroundColor Cyan
    return
  }

  $confirm = Read-Host "`nType 'prod' to apply the migrations above to PRODUCTION"
  if ($confirm -ne 'prod') {
    Write-Host 'Aborted - nothing was applied to PROD.' -ForegroundColor Cyan
    return
  }

  Invoke-Supabase db push --yes

  foreach ($fn in $Functions) {
    Write-Host "`nDeploying Edge Function '$fn' to PROD..." -ForegroundColor Yellow
    Invoke-Supabase functions deploy $fn --project-ref $PROD
  }

  Write-Host "`nProduction push complete." -ForegroundColor Green
}
finally {
  Write-Host "`nRelinking CLI to DEV ($DEV)..." -ForegroundColor Cyan
  try {
    Set-Link $DEV
    Write-Host "CLI is linked to DEV again." -ForegroundColor Cyan
  }
  catch {
    Write-Host "WARNING: relinking to DEV failed. The CLI may still point at PROD." -ForegroundColor Red
    Write-Host "Fix it now: supabase link --project-ref $DEV" -ForegroundColor Red
  }
  Pop-Location
}
