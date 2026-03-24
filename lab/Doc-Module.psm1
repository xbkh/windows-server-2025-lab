#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Module de documentation automatique - Captures d'ecran + Rapport HTML/PDF
    Formation Windows Server 2025

.DESCRIPTION
    Ce module s'utilise en COMPLEMENT des scripts TP_0x_*.ps1.
    Il capture automatiquement les ecrans a chaque etape cle et genere
    un rapport HTML professionnel avec les screenshots integres.

    Utilisation :
        1. Importer ce module au debut de chaque TP :
               Import-Module .\Doc-Module.psm1
        2. Les screenshots sont pris automatiquement a chaque Write-Step
        3. A la fin, appeler : New-LabReport

.EXAMPLE
    # Intgration complte (wrapper autour d'un TP) :
    Import-Module .\Doc-Module.psm1
    Start-LabDoc -Title "TP Module 02 - Active Directory" -StudentName "Jean Dupont"

    # Lancer le TP normalement  les screenshots sont capturs automatiquement
    .\TP_00_Setup-Lab.ps1

    # Gnrer le rapport  la fin :
    New-LabReport -OutputPath "C:\Rapports\TP_AD.html"
    
    # Ou en PDF (ncessite Chromium ou wkhtmltopdf) :
    New-LabReport -OutputPath "C:\Rapports\TP_AD.pdf" -AsPdf
#>

#region --- Variables globales du module --------------------------------------
$script:DocSteps    = [System.Collections.Generic.List[hashtable]]::new()
$script:DocTitle    = "Formation Windows Server 2025"
$script:StudentName = "Etudiant"
$script:StartTime   = Get-Date
$script:ImgFolder   = "$env:TEMP\LabDoc_Screenshots"
$script:StepIndex   = 0

# Crer le dossier pour les screenshots
if (-not (Test-Path $script:ImgFolder)) {
    New-Item -ItemType Directory -Path $script:ImgFolder -Force | Out-Null
}
#endregion

#region --- Fonction : Capture d'cran ----------------------------------------
function Get-Screenshot {
    <#
    .SYNOPSIS
        Capture l'ecran entier ou une fenetre specifique et retourne le chemin du fichier.
    #>
    param(
        [string]$Name = "screenshot",
        [switch]$ActiveWindowOnly    # Capturer seulement la fenetre active
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $filename = "$script:ImgFolder\${Name}_$(Get-Date -Format 'HHmmss').png"

    if ($ActiveWindowOnly) {
        # Capturer la fentre PowerShell active
        Add-Type @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class ScreenCapture {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@ -ErrorAction SilentlyContinue

        try {
            $hwnd = [ScreenCapture]::GetForegroundWindow()
            $rect = New-Object ScreenCapture+RECT
            [ScreenCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

            $width  = $rect.Right  - $rect.Left
            $height = $rect.Bottom - $rect.Top

            $bmp = New-Object System.Drawing.Bitmap($width, $height)
            $g   = [System.Drawing.Graphics]::FromImage($bmp)
            $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
            $bmp.Save($filename, [System.Drawing.Imaging.ImageFormat]::Png)
            $g.Dispose()
            $bmp.Dispose()
        } catch {
            # Fallback : capture plein cran
            $ActiveWindowOnly = $false
        }
    }

    if (-not $ActiveWindowOnly) {
        # Capture plein cran
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp    = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $g      = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
        $bmp.Save($filename, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose()
        $bmp.Dispose()
    }

    return $filename
}
#endregion

#region --- Fonction : Dmarrer la documentation ------------------------------
function Start-LabDoc {
    <#
    .SYNOPSIS
        Initialise la session de documentation.
    #>
    param(
        [string]$Title       = "Formation Windows Server 2025",
        [string]$StudentName = "Etudiant",
        [string]$Module      = ""
    )

    $script:DocTitle    = if ($Module) { "$Title - $Module" } else { $Title }
    $script:StudentName = $StudentName
    $script:StartTime   = Get-Date
    $script:DocSteps    = [System.Collections.Generic.List[hashtable]]::new()
    $script:StepIndex   = 0

    # Nettoyer les anciens screenshots
    Get-ChildItem $script:ImgFolder -Filter "*.png" | Remove-Item -Force

    Write-Host "`n   Documentation automatique demarree pour : $($script:DocTitle)" -ForegroundColor Cyan
    Write-Host "     Etudiant : $StudentName" -ForegroundColor Cyan
    Write-Host "     Screenshots -> $script:ImgFolder`n" -ForegroundColor Gray

    # Capture initiale (tat avant)
    Add-DocStep -Title "Etat initial du systeme" -Description "Capture de l'etat du systeme avant configuration" -Screenshot
}
#endregion

#region --- Fonction : Ajouter une tape documente --------------------------
function Add-DocStep {
    <#
    .SYNOPSIS
        Ajoute une etape a la documentation avec screenshot optionnel.

    .EXAMPLE
        Add-DocStep -Title "Installation AD DS" -Description "Resultat de l'installation" -Screenshot
        Add-DocStep -Title "Test DNS" -Command "Resolve-DnsName dc01.satom.local" -Screenshot
    #>
    param(
        [string]  $Title,
        [string]  $Description = "",
        [string]  $Command     = "",       # Commande a executer + documenter
        [string]  $Output      = "",       # Sortie de commande pre-capturee
        [switch]  $Screenshot,             # Capturer l'ecran
        [ValidateSet("info","success","warning","error")]
        [string]  $Status      = "info",
        [string[]]$CheckItems  = @()       # Liste de points verifies
    )

    $script:StepIndex++
    $imgPath = $null
    $cmdOutput = $Output

    # Excuter la commande si fournie et capturer la sortie
    if ($Command) {
        try {
            $cmdOutput = (Invoke-Expression $Command 2>&1) | Out-String
        } catch {
            $cmdOutput = "Erreur : $($_.Exception.Message)"
            $Status = "error"
        }
    }

    # Capture d'cran avec dlai pour laisser le terminal s'afficher
    if ($Screenshot) {
        Start-Sleep -Milliseconds 500
        $safeName = ($Title -replace '[^\w]','_').Substring(0, [Math]::Min(30, $Title.Length))
        $imgPath  = Get-Screenshot -Name "step$($script:StepIndex)_$safeName"
    }

    # Convertir l'image en Base64 pour l'embed dans HTML
    $imgBase64 = $null
    if ($imgPath -and (Test-Path $imgPath)) {
        $imgBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($imgPath))
    }

    $step = @{
        Index       = $script:StepIndex
        Timestamp   = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        Title       = $Title
        Description = $Description
        Command     = $Command
        Output      = $cmdOutput
        Status      = $Status
        ImgBase64   = $imgBase64
        CheckItems  = $CheckItems
    }

    $script:DocSteps.Add($step)

    # Feedback visuel
    $icon = switch ($Status) { "success"{"[OK]"} "warning"{"[!]"} "error"{""} default{""} }
    Write-Host "  $icon [$($script:StepIndex)] $Title documente" -ForegroundColor $(
        switch ($Status) { "success"{"Green"} "warning"{"Yellow"} "error"{"Red"} default{"Cyan"} }
    )
}
#endregion

#region --- Fonction : Captures automatiques des tests cls ------------------
function Invoke-DocCheck {
    <#
    .SYNOPSIS
        Execute une serie de tests et les documente automatiquement.
    .EXAMPLE
        Invoke-DocCheck -Module "DHCP" -Checks @(
            @{Title="Etendue active"; Command='Get-DhcpServerv4Scope | Format-Table -AutoSize'},
            @{Title="Baux actifs";    Command='Get-DhcpServerv4Lease -ScopeId 192.168.100.0'}
        )
    #>
    param(
        [string]$Module = "",
        [array]$Checks  = @()
    )

    Write-Host "`n  -- Verifications documentees : $Module --" -ForegroundColor White

    foreach ($check in $Checks) {
        $output = ""
        $status = "success"
        try {
            $output = (Invoke-Expression $check.Command 2>&1) | Out-String
            if (-not $output.Trim()) { $output = "(aucune sortie)" }
        } catch {
            $output = "Erreur : $($_.Exception.Message)"
            $status = "error"
        }

        Add-DocStep -Title $check.Title `
                    -Command $check.Command `
                    -Output $output `
                    -Screenshot `
                    -Status $status
    }
}
#endregion

#region --- Fonction : Gnrer le rapport HTML --------------------------------
function New-LabReport {
    <#
    .SYNOPSIS
        Genere le rapport HTML/PDF final avec tous les screenshots.

    .EXAMPLE
        New-LabReport -OutputPath "C:\Rapports\TP_AD.html"
        New-LabReport -OutputPath "C:\Rapports\TP_AD.pdf" -AsPdf
        New-LabReport  # Genere sur le Bureau
    #>
    param(
        [string]$OutputPath = "$env:USERPROFILE\Desktop\Rapport_TP_$(Get-Date -Format 'yyyy-MM-dd_HHmm').html",
        [switch]$AsPdf,
        [string]$StudentName = $script:StudentName
    )

    $endTime  = Get-Date
    $duration = [math]::Round(($endTime - $script:StartTime).TotalMinutes, 1)
    $pdfPath  = [IO.Path]::ChangeExtension($OutputPath, ".pdf")

    # -- CSS du rapport --------------------------------------------------------
    $css = @"
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
    background: #f0f2f5;
    color: #1a1a2e;
    line-height: 1.6;
}
.page-header {
    background: linear-gradient(135deg, #003087 0%, #0078d4 60%, #00bcf2 100%);
    color: white;
    padding: 40px;
    display: flex;
    align-items: center;
    gap: 30px;
}
.page-header .logo { font-size: 60px; }
.page-header h1 { font-size: 2em; margin-bottom: 6px; }
.page-header .meta { font-size: 0.9em; opacity: 0.85; }
.summary-bar {
    background: white;
    display: flex;
    justify-content: space-around;
    padding: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}
.stat-box { text-align: center; }
.stat-num { font-size: 2em; font-weight: bold; color: #0078d4; }
.stat-label { font-size: 0.8em; color: #666; text-transform: uppercase; letter-spacing: 1px; }
.main { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
.step-card {
    background: white;
    border-radius: 10px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.07);
    margin-bottom: 24px;
    overflow: hidden;
    border-left: 5px solid #0078d4;
}
.step-card.success { border-left-color: #107c10; }
.step-card.warning { border-left-color: #ff8c00; }
.step-card.error   { border-left-color: #e81123; }
.step-header {
    padding: 16px 20px;
    display: flex;
    align-items: center;
    gap: 14px;
    cursor: pointer;
    user-select: none;
}
.step-header:hover { background: #f8f9fa; }
.step-num {
    background: #0078d4;
    color: white;
    border-radius: 50%;
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 0.9em;
    flex-shrink: 0;
}
.step-card.success .step-num { background: #107c10; }
.step-card.warning .step-num { background: #ff8c00; }
.step-card.error   .step-num { background: #e81123; }
.step-title { font-weight: 600; font-size: 1.05em; flex: 1; }
.step-time { color: #888; font-size: 0.8em; }
.step-body { padding: 0 20px 20px; display: none; }
.step-body.open { display: block; }
.step-desc { color: #555; margin-bottom: 12px; }
pre.cmd-output {
    background: #1e1e1e;
    color: #d4d4d4;
    padding: 14px;
    border-radius: 6px;
    font-family: 'Cascadia Code', 'Consolas', monospace;
    font-size: 0.85em;
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-word;
    max-height: 350px;
    overflow-y: auto;
}
code.cmd-inline {
    background: #f0f0f0;
    color: #0078d4;
    padding: 2px 8px;
    border-radius: 4px;
    font-family: 'Consolas', monospace;
    font-size: 0.9em;
}
.screenshot-container {
    margin-top: 16px;
    border: 2px solid #e0e0e0;
    border-radius: 8px;
    overflow: hidden;
    position: relative;
}
.screenshot-label {
    background: #f0f0f0;
    padding: 6px 12px;
    font-size: 0.8em;
    color: #666;
    display: flex;
    align-items: center;
    gap: 6px;
}
.screenshot-container img {
    width: 100%;
    display: block;
    cursor: zoom-in;
}
.screenshot-container img.zoomed { cursor: zoom-out; }
.checklist { list-style: none; margin-top: 12px; }
.checklist li { padding: 4px 0; }
.checklist li::before { content: " "; color: #107c10; font-weight: bold; }
.tag {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 0.75em;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 600;
    margin-left: 8px;
}
.tag-info    { background: #e3f2fd; color: #0078d4; }
.tag-success { background: #e8f5e9; color: #107c10; }
.tag-warning { background: #fff3e0; color: #ff8c00; }
.tag-error   { background: #fce4ec; color: #e81123; }
.lightbox {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.9);
    z-index: 1000;
    cursor: zoom-out;
    align-items: center;
    justify-content: center;
}
.lightbox.active { display: flex; }
.lightbox img { max-width: 95vw; max-height: 95vh; border-radius: 4px; }
footer {
    text-align: center;
    padding: 30px;
    color: #888;
    font-size: 0.85em;
}
@media print {
    .step-body { display: block !important; }
    .step-header { cursor: default; }
    .lightbox { display: none !important; }
}"@

    # -- JavaScript ------------------------------------------------------------
    $js = @"
function toggleStep(el) {
    const body = el.nextElementSibling;
    body.classList.toggle('open');
}
function zoomImg(img) {
    const lb = document.getElementById('lightbox');
    document.getElementById('lbImg').src = img.src;
    lb.classList.add('active');
}
document.addEventListener('DOMContentLoaded', function() {
    // Ouvrir les etapes avec erreur automatiquement
    document.querySelectorAll('.step-card.error .step-body').forEach(b => b.classList.add('open'));
    // Lightbox
    document.getElementById('lightbox').addEventListener('click', function() {
        this.classList.remove('active');
    });
    // Ouvrir le premier step par defaut
    const first = document.querySelector('.step-body');
    if (first) first.classList.add('open');
});
"@

    # -- Gnrer les cartes d'tapes ------------------------------------------
    $stepsHtml = ""
    foreach ($step in $script:DocSteps) {
        $statusClass = $step.Status
        $tagClass    = "tag-$($step.Status)"
        $tagLabels   = @{info="Info"; success="OK"; warning="Avertissement"; error="Erreur"}
        $tagLabel    = $tagLabels[$step.Status]

        $cmdBlock = ""
        if ($step.Command) {
            $cmdBlock = @"
<p style='margin:12px 0 4px'><strong>Commande :</strong> <code class='cmd-inline'>$([System.Web.HttpUtility]::HtmlEncode($step.Command))</code></p>
"@
        }

        $outputBlock = ""
        if ($step.Output) {
            $encodedOutput = [System.Web.HttpUtility]::HtmlEncode($step.Output.Trim())
            $outputBlock = @"
<pre class='cmd-output'>$encodedOutput</pre>
"@
        }

        $imgBlock = ""
        if ($step.ImgBase64) {
            $imgBlock = @"
<div class='screenshot-container'>
    <div class='screenshot-label'> Capture d'ecran - $($step.Timestamp)</div>
    <img src='data:image/png;base64,$($step.ImgBase64)' 
         alt='Screenshot $($step.Index)' 
         onclick='zoomImg(this)' 
         title='Cliquer pour agrandir' />
</div>
"@
        }

        $checkHtml = ""
        if ($step.CheckItems -and $step.CheckItems.Count -gt 0) {
            $items = ($step.CheckItems | ForEach-Object { "<li>$_</li>" }) -join ""
            $checkHtml = "<ul class='checklist' style='margin-top:12px'>$items</ul>"
        }

        $stepsHtml += @"
<div class='step-card $statusClass'>
    <div class='step-header' onclick='toggleStep(this)'>
        <div class='step-num'>$($step.Index)</div>
        <div class='step-title'>
            $([System.Web.HttpUtility]::HtmlEncode($step.Title))
            <span class='tag $tagClass'>$tagLabel</span>
        </div>
        <div class='step-time'>$($step.Timestamp)</div>
    </div>
    <div class='step-body'>
        $(if ($step.Description) { "<p class='step-desc'>$([System.Web.HttpUtility]::HtmlEncode($step.Description))</p>" })
        $cmdBlock
        $outputBlock
        $checkHtml
        $imgBlock
    </div>
</div>
"@
    }

    # -- Statistiques ---------------------------------------------------------
    $total   = $script:DocSteps.Count
    $success = @($script:DocSteps | Where-Object {$_.Status -eq "success"}).Count
    $errors  = @($script:DocSteps | Where-Object {$_.Status -eq "error"}).Count
    $withImg = @($script:DocSteps | Where-Object {$_.ImgBase64}).Count

    # -- HTML final ------------------------------------------------------------
    $html = @"
<!DOCTYPE html>
<html lang='fr'>
<head>
<meta charset='UTF-8'>
<meta name='viewport' content='width=device-width, initial-scale=1.0'>
<title>$($script:DocTitle)</title>
<style>$css</style>
</head>
<body>

<div class='page-header'>
    <div class='logo'></div>
    <div>
        <h1>$([System.Web.HttpUtility]::HtmlEncode($script:DocTitle))</h1>
        <div class='meta'>
             Etudiant : <strong>$([System.Web.HttpUtility]::HtmlEncode($StudentName))</strong> &nbsp;|&nbsp;
             Date : <strong>$(Get-Date -Format 'dd/MM/yyyy')</strong> &nbsp;|&nbsp;
             Duree : <strong>$duration min</strong>
        </div>
    </div>
</div>

<div class='summary-bar'>
    <div class='stat-box'><div class='stat-num'>$total</div><div class='stat-label'>Etapes</div></div>
    <div class='stat-box'><div class='stat-num' style='color:#107c10'>$success</div><div class='stat-label'>Succes</div></div>
    <div class='stat-box'><div class='stat-num' style='color:#e81123'>$errors</div><div class='stat-label'>Erreurs</div></div>
    <div class='stat-box'><div class='stat-num'>$withImg</div><div class='stat-label'>Screenshots</div></div>
    <div class='stat-box'><div class='stat-num'>$(Get-Date -Format 'HH:mm')</div><div class='stat-label'>Heure fin</div></div>
</div>

<div class='main'>
$stepsHtml
</div>

<div id='lightbox' class='lightbox'>
    <img id='lbImg' src='' alt='Zoom' />
</div>

<footer>
    Genere automatiquement par PowerShell · Formation Windows Server 2025 · $(Get-Date -Format 'dd/MM/yyyy HH:mm')
</footer>

<script>$js</script>
</body>
</html>
"@

    # crire le fichier HTML
    $html | Out-File -Encoding UTF8 -FilePath $OutputPath
    Write-Host "`n  [OK] Rapport HTML genere : $OutputPath" -ForegroundColor Green

    # -- Conversion PDF (si demande) ------------------------------------------
    if ($AsPdf) {
        $chromePaths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles\Chromium\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        $chrome = $chromePaths | Where-Object {Test-Path $_} | Select-Object -First 1

        if ($chrome) {
            $args = @(
                "--headless", "--no-sandbox", "--disable-gpu",
                "--print-to-pdf=`"$pdfPath`"",
                "--print-to-pdf-no-header",
                "`"file:///$($OutputPath.Replace('\','/'))`""
            )
            Start-Process -FilePath $chrome -ArgumentList $args -Wait -NoNewWindow
            Write-Host "  [OK] Rapport PDF  genere : $pdfPath" -ForegroundColor Green
        } else {
            Write-Host "  [!] Chrome non trouve pour PDF. HTML disponible : $OutputPath" -ForegroundColor Yellow
        }
    }

    # Ouvrir dans le navigateur
    Start-Process $OutputPath

    return $OutputPath
}
#endregion

#region --- Fonctions utilitaires d'intgration -------------------------------
function Save-DocCheckpoint {
    <#
    .SYNOPSIS
        Sauvegarde un point de controle (rapport intermediaire).
    #>
    param([string]$Label = "checkpoint")
    $path = "$script:ImgFolder\rapport_${Label}_$(Get-Date -Format 'HHmm').html"
    New-LabReport -OutputPath $path
    Write-Host "  [SAVE] Point de controle sauvegarde : $path" -ForegroundColor Cyan
}

function Add-DocManualScreenshot {
    <#
    .SYNOPSIS
        Ajoute manuellement une capture avec titre personnalise.
        Appuyer sur Entree pour declencher la capture.
    .EXAMPLE
        Add-DocManualScreenshot -Title "Console Active Directory Users"
    #>
    param([string]$Title = "Capture manuelle")

    Write-Host "   Positionnez la fenetre a capturer et appuyez sur [Entree]..." -ForegroundColor Yellow
    Read-Host | Out-Null
    Add-DocStep -Title $Title -Screenshot -Status "info"
}

# Export des fonctions publiques du module
Export-ModuleMember -Function @(
    "Start-LabDoc",
    "Add-DocStep",
    "Invoke-DocCheck",
    "New-LabReport",
    "Save-DocCheckpoint",
    "Add-DocManualScreenshot",
    "Get-Screenshot"
)
#endregion
