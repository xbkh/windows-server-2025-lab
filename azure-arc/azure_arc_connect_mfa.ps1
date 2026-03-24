param(
    [string]$SubscriptionId = '',          # auto-detecte si vide
    [string]$ResourceGroup  = 'rg-ws2025-lab',
    [string]$Location       = 'francecentral',
    [string]$TenantId       = ''          # auto-detecte si vide
)

$ErrorActionPreference = 'Stop'

# ── Modules ────────────────────────────────────────────────────────────────
foreach ($mod in @('Az.Accounts','Az.Resources')) {
    if (-not (Get-Module -ListAvailable $mod)) {
        Write-Host "[AzureArc] Installation module $mod ..." -ForegroundColor Yellow
        Install-Module $mod -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
    }
    Import-Module $mod -ErrorAction Stop
}

# ── Nettoyer toute session précédente ──────────────────────────────────────
try { Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null } catch {}
Clear-AzContext -Force -ErrorAction SilentlyContinue | Out-Null

# ── Connexion Azure étape 1 : authentification initiale ───────────────────
Write-Host "`n[AzureArc] === AUTHENTIFICATION AZURE (etape 1/2) ===" -ForegroundColor Cyan
Write-Host "[AzureArc] Ouvrir https://microsoft.com/devicelogin et entrer le code ci-dessous" -ForegroundColor Yellow

$connectParams = @{ UseDeviceAuthentication = $true; ErrorAction = 'Stop' }
if ($TenantId) { $connectParams['Tenant'] = $TenantId }
$account = Connect-AzAccount @connectParams

Write-Host "[AzureArc] Connecte en tant que : $($account.Context.Account.Id)" -ForegroundColor Green

# Récupérer le tenant depuis le contexte si non fourni
if (-not $TenantId) { $TenantId = $account.Context.Tenant.Id }
Write-Host "[AzureArc] Tenant ID : $TenantId" -ForegroundColor Green

# Récupérer la subscription si non fournie
if (-not $SubscriptionId) {
    $subs = Get-AzSubscription -TenantId $TenantId -ErrorAction Stop
    $activeSubs = $subs | Where-Object { $_.State -eq 'Enabled' }
    if ($activeSubs.Count -eq 0) {
        Write-Host "[AzureArc] Toutes les subscriptions disponibles :" -ForegroundColor Red
        $subs | ForEach-Object { Write-Host "  [$($_.State)] [$($_.Id)] $($_.Name)" }
        throw "Aucune subscription ACTIVE trouvee. Verifiez votre compte Azure."
    }
    Write-Host "[AzureArc] Subscriptions actives trouvees :" -ForegroundColor Green
    $activeSubs | ForEach-Object { Write-Host "  [$($_.Id)] $($_.Name)" }
    $SubscriptionId = $activeSubs[0].Id
    Write-Host "[AzureArc] Utilisation de : [$SubscriptionId] $($activeSubs[0].Name)" -ForegroundColor Green
}
Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop | Out-Null
Write-Host "[AzureArc] Subscription selectionnee : $SubscriptionId" -ForegroundColor Green

# ── Connexion Azure étape 2 : MFA step-up for ARM ─────────────────────────
Write-Host "`n[AzureArc] === AUTHENTIFICATION AZURE (etape 2/2 - MFA ARM) ===" -ForegroundColor Cyan
Write-Host "[AzureArc] Ouvrir https://microsoft.com/devicelogin et entrer le NOUVEAU code ci-dessous" -ForegroundColor Yellow
$claimsChallenge = 'eyJhY2Nlc3NfdG9rZW4iOnsiYWNycyI6eyJlc3NlbnRpYWwiOnRydWUsInZhbHVlcyI6WyJwMSJdfX19'
Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication -ClaimsChallenge $claimsChallenge -ErrorAction Stop | Out-Null
Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop | Out-Null
Write-Host "[AzureArc] MFA step-up valide" -ForegroundColor Green

# ── Resource Group ─────────────────────────────────────────────────────────
Write-Host "`n[AzureArc] Verification du resource group '$ResourceGroup'..." -ForegroundColor Cyan
$rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "[AzureArc] Creation du resource group..." -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroup -Location $Location -ErrorAction Stop | Out-Null
    Write-Host "[AzureArc] Resource group cree : $ResourceGroup ($Location)" -ForegroundColor Green
} else {
    Write-Host "[AzureArc] Resource group existant : $ResourceGroup" -ForegroundColor Green
}

# ── Token ARM ─────────────────────────────────────────────────────────────
Write-Host "`n[AzureArc] Obtention du token d'acces ARM..." -ForegroundColor Cyan
$tokenObj = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/' -ErrorAction Stop
$token = $tokenObj.Token
if (-not $token -or $token.Length -lt 100) {
    throw "Token ARM invalide ou vide. Verifiez votre authentification."
}
Write-Host "[AzureArc] Token obtenu (longueur: $($token.Length) chars)" -ForegroundColor Green

# ── Connexion azcmagent ────────────────────────────────────────────────────
Write-Host "`n[AzureArc] === CONNEXION A AZURE ARC ===" -ForegroundColor Cyan
$azcmagent = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'

& $azcmagent connect `
    --subscription-id $SubscriptionId `
    --resource-group  $ResourceGroup `
    --location        $Location `
    --tenant-id       $TenantId `
    --access-token    $token

if ($LASTEXITCODE -ne 0) {
    throw "azcmagent connect a echoue (exit code $LASTEXITCODE)"
}

# ── Statut final ───────────────────────────────────────────────────────────
Write-Host "`n[AzureArc] === STATUT FINAL ===" -ForegroundColor Cyan
& $azcmagent show

Write-Host "`n[AzureArc] TERMINE avec succes !" -ForegroundColor Green
