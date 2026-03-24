# Windows Server 2025 Lab

> Lab complet Windows Server 2025 avec Active Directory, DNS, DHCP, GPO, LAPS, PKI, DFS/FSRM, NPS/RADIUS, Hyper-V, scripts PowerShell et 44 captures de validation.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2025-0078D4?logo=windows&logoColor=white)
![Status](https://img.shields.io/badge/Lab-Completed-success)
![Screenshots](https://img.shields.io/badge/Screenshots-44-blue)

## Aperçu

Ce dépôt regroupe un lab d'administration Windows Server 2025 prêt à être rejoué ou présenté.

Il contient :

- les scripts de TP PowerShell
- la documentation complète du parcours
- les correctifs et scripts de validation
- les captures finales du rendu

## Points forts

- Active Directory multi-serveurs avec `DC01`, `DC02` et `PC01`
- services d'infrastructure : DNS, DHCP, GPO, LAPS, PKI, LDAPS
- services fichiers : SMB, DFS Namespace, FSRM, quotas, filtres
- sécurité : PSO, durcissement SMB, `WDigest=0`, `LmCompatibilityLevel=5`
- accès réseau : NPS / RADIUS / règles pare-feu
- validation finale automatisée avec `check_all.ps1`

## Galerie

| AD / DNS | DHCP / GPO |
|---|---|
| ![AD](screenshots/01_AD-Domain-Controllers.png) | ![DHCP](screenshots/06_DHCP-Scope-Config.png) |
| ![DNS](screenshots/02_DNS-Manager.png) | ![GPO](screenshots/11_GPO-List.png) |

| PKI / LAPS | File Server / NPS |
|---|---|
| ![PKI](screenshots/16_CertSrv-CA-Console.png) | ![DFS](screenshots/29_DFS-Namespace.png) |
| ![LAPS](screenshots/43_LAPS-GPO-Config.png) | ![NPS](screenshots/34_NPS-Console.png) |

## Sommaire

- [Structure du dossier](#structure-du-dossier)
- [Architecture du lab](#architecture-du-lab)
- [Livrables présents](#livrables-présents)
- [État du lab](#état-du-lab)
- [Exécution des TPs](#exécution-des-tps)
- [Vérification globale du lab](#vérification-globale-du-lab)
- [Captures d'écran livrées](#captures-décran-livrées)
- [Dépannage](#dépannage)

## Structure du dossier

```
windows server/
├── README.md
│
├── docs/                              ← documentation
│   ├── formation_ws2025.md            ← contenu complet du cours (17 modules)
│   ├── formation_ws2025.pdf           ← PDF du cours
│   └── lab-satom.pdf                  ← support du lab
│
├── lab/                               ← scripts TP (doivent rester ensemble)
│   ├── START-Formation.ps1            ← point d'entrée unique (TPs + documentation)
│   ├── Doc-Module.psm1                ← module screenshots + rapports HTML/PDF
│   ├── TP_00_Setup-Lab.ps1            ← Modules 00/02 – Post-install, IP, AD DS
│   ├── TP_01_DHCP-DNS-Client.ps1      ← Module 03  – DHCP, DNS, jonction domaine
│   ├── TP_02_AD-OUs-Users-GPO.ps1     ← Modules 04/05/06 – OUs, utilisateurs, GPOs
│   ├── TP_03_Securite-LAPS-HyperV.ps1 ← Modules 07–15 – LAPS, Sites, sécurité, Hyper-V
│   ├── TP_04_AzureArc-Synthese.ps1    ← Module 16 – Azure Arc + validation avec score
│   ├── TP_05_PKI-CA.ps1               ← Module 17 – PKI, CA, LDAPS, auto-enrôlement
│   ├── TP_06_FileServer-DFS-FSRM.ps1  ← Module 18 – SMB, DFS, FSRM, lecteurs réseau
│   └── TP_07_NPS-RADIUS.ps1           ← Module 19 – NPS, RADIUS, policies, GPO
│
├── azure-arc/                         ← scripts Azure Arc
│   ├── azure_arc_prepare.ps1          ← prérequis (modules Az + agent azcmagent)
│   └── azure_arc_connect_mfa.ps1      ← connexion avec double auth MFA
│
├── screenshots/                       ← 44 captures finales du lab
│   ├── 01_AD-Domain-Controllers.png
│   ├── 02_DNS-Manager.png
│   ├── ...
│   └── 44_Check-All-Script.png
│
├── scripts/                           ← scripts temporaires de correction / validation
│   ├── check_all.ps1                  ← vérification globale de l'état du lab
│   ├── create_pso.ps1                 ← création de la PSO admins
│   ├── create_nps_policies.ps1        ← création des policies NPS
│   └── ...
│
└── archives/                          ← scripts one-shot exécutés (référence)
    ├── setup.bat
    ├── promote-dc.ps1
    ├── dc01_finalize_lab.ps1
    ├── dc01_dhcp_cleanup_failover.ps1
    ├── dc2_prepare.ps1
    ├── dc2_join_stage.ps1
    ├── dc2_promote.ps1
    ├── dc2_promote_startup.ps1
    ├── dc2_finalize.ps1
    ├── pc01_join.ps1
    └── pc01_join_scheduled.ps1
```

---

## Architecture du lab

```
Réseau KVM : 192.168.122.0/24
├── DC01  192.168.122.10   – Windows Server 2025 (PDC Emulator, DNS, DHCP)
│                            Domaine : satom.local
├── DC02  192.168.122.20   – Windows Server 2025 (DC secondaire, DHCP failover)
└── PC01  192.168.122.50   – Windows Server 2025 (client domaine, IP via DHCP)
                             OU : OU=Paris,OU=_SATOM,DC=satom,DC=local
```

**Credentials :**

| Machine | Compte | Mot de passe |
|---------|--------|--------------|
| DC01 / DC02 | `Administrateur` | `formation123.` |
| PC01 (local LAPS) | `admin` | géré par LAPS — voir ci-dessous |
| Utilisateurs domaine | `satom\<user>` | `Satom@2025!Lab` |

```powershell
# Récupérer le mot de passe LAPS de PC01 depuis DC01 :
Get-LapsADPassword -Identity PC01 -AsPlainText
```

---

## Livrables présents

- 44 captures finales dans [screenshots](screenshots)
- documentation complète dans [docs/formation_ws2025.md](docs/formation_ws2025.md)
- support PDF dans [docs/formation_ws2025.pdf](docs/formation_ws2025.pdf)
- scripts de TP dans [lab](lab)
- scripts de contrôle et correction dans [scripts](scripts)

---

## État du lab

| Module | Composant | État |
|--------|-----------|------|
| M00/02 | AD DS, DNS, DC01 promu PDC | ✅ |
| M03 | DHCP scope + failover FO-DC01-DC02 (LoadBalance) | ✅ |
| M04/05 | OUs _SATOM + 12 utilisateurs + 10 GPOs | ✅ |
| M06 | Politique MDP + verrouillage + PSO admins | ✅ |
| M07 | LAPS opérationnel sur PC01 | ✅ |
| M08 | Sites AD : Site-Paris + Site-Bordeaux + 3 subnets | ✅ |
| M11 | WinGet, PS7, VSCode, Notepad++ + tâche Rapport_AD_Quotidien | ✅ |
| M12/13 | Plan hautes performances + tâche Monitoring_Serveur | ✅ |
| M14 | SMBv1=off, Signing=on, Encrypt=on, LmCompat=5, WDigest=0 | ✅ |
| M15 | Hyper-V : vmms Running, 2 vSwitches, VM-Demo-WS2025 (Gen2) | ✅ |
| M16 | Azure Arc | ⏸️ subscription inactive |
| M17 | PKI interne : ADCS + CA + LDAPS + Auto-enrôlement | ✅ 10/10 A Excellent |
| M18 | File Server : DFS-N, FSRM, quotas, filtrage, GPO lecteurs | ✅ 12/12 A Excellent |
| M19 | NPS/RADIUS : NPAS, clients RADIUS, policies, GPO, logs | ✅ 12/12 A Excellent |

Validation finale observée via `check_all.ps1` :

- DHCP failover `FO-DC01-DC02` en état `Normal`
- LAPS fonctionnel sur `PC01`
- SMB durci : `SMBv1=False`, `Signing=True`, `Encrypt=True`
- registre sécurité conforme : `LmCompatibilityLevel=5`, `WDigest=0`
- PSO `PSO-Admins` appliquée
- Hyper-V actif avec 2 vSwitches et 1 VM de démonstration

---

## Exécution des TPs

### Démarrage rapide (documentation automatique)

```powershell
# Sur DC01 — PowerShell Administrateur
Set-ExecutionPolicy Bypass -Scope Process -Force
cd C:\Formation\lab

.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module 0    # AD DS
.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module 1    # DHCP/DNS
.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module 2    # OUs/GPOs
.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module 3    # LAPS/Sécurité/Hyper-V
.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module 4    # Azure Arc

# Tout enchaîner avec export PDF :
.\START-Formation.ps1 -NomEtudiant "Prénom Nom" -Module Tous -GeneratePDF
```

Rapports générés dans : `C:\Users\Administrateur\Desktop\Rapports_Formation\`

---

### Exécution manuelle par script

```powershell
# Se placer dans lab/ sur DC01
cd C:\Formation\lab

# TP00 — AD DS (redémarre automatiquement)
.\TP_00_Setup-Lab.ps1 -DomainName "satom.local" -ServerName "DC01" `
    -InterfaceAlias "Ethernet" -StaticIP "192.168.122.10"

# TP01 — DHCP + DNS (après redémarrage)
.\TP_01_DHCP-DNS-Client.ps1

# TP02 — OUs / Utilisateurs / GPOs
.\TP_02_AD-OUs-Users-GPO.ps1

# TP03 — Sécurité / LAPS / Hyper-V
.\TP_03_Securite-LAPS-HyperV.ps1                        # tout
.\TP_03_Securite-LAPS-HyperV.ps1 -Module LAPS
.\TP_03_Securite-LAPS-HyperV.ps1 -Module Securite
.\TP_03_Securite-LAPS-HyperV.ps1 -Module HyperV

# TP04 — Validation sans Azure
.\TP_04_AzureArc-Synthese.ps1 -ValidationOnly

# TP04 — Avec Azure Arc (subscription active requise)
.\TP_04_AzureArc-Synthese.ps1 `
    -SubscriptionId "votre-guid" `
    -TenantId "votre-tenant" `
    -ResourceGroup "rg-ws2025-lab" `
    -Location "francecentral"

# TP05 — PKI interne complète (CA + GPO + LDAPS)
.\TP_05_PKI-CA.ps1

# TP05 — Par module
.\TP_05_PKI-CA.ps1 -Module CA        # Installer la CA uniquement
.\TP_05_PKI-CA.ps1 -Module LDAPS     # Activer LDAPS uniquement
.\TP_05_PKI-CA.ps1 -Module GPO       # GPO auto-enrôlement uniquement
.\TP_05_PKI-CA.ps1 -Module Validate  # Validation uniquement

# TP06 — File Server : DFS + FSRM + Partages + GPO lecteurs
.\TP_06_FileServer-DFS-FSRM.ps1                          # tout
.\TP_06_FileServer-DFS-FSRM.ps1 -Module Roles            # Rôles uniquement
.\TP_06_FileServer-DFS-FSRM.ps1 -Module Shares           # Partages SMB uniquement
.\TP_06_FileServer-DFS-FSRM.ps1 -Module DFS              # Namespace DFS uniquement
.\TP_06_FileServer-DFS-FSRM.ps1 -Module FSRM             # Quotas + filtrage uniquement
.\TP_06_FileServer-DFS-FSRM.ps1 -Module GPO              # GPO lecteurs uniquement
.\TP_06_FileServer-DFS-FSRM.ps1 -Module Validate         # Validation uniquement
```

---

### TP07 — NPS/RADIUS : authentification réseau (NPAS + 802.1x)

```powershell
.\TP_07_NPS-RADIUS.ps1                       # tout
.\TP_07_NPS-RADIUS.ps1 -Module Roles         # Installer NPAS uniquement
.\TP_07_NPS-RADIUS.ps1 -Module Config        # Clients RADIUS + journalisation
.\TP_07_NPS-RADIUS.ps1 -Module Policy        # Stratégies réseau (Network Policies)
.\TP_07_NPS-RADIUS.ps1 -Module GPO           # GPO + règles pare-feu RADIUS
.\TP_07_NPS-RADIUS.ps1 -Module Validate      # Validation uniquement
```

---

### Azure Arc (Module 16)

```powershell
# Se placer dans azure-arc/ sur DC01
cd C:\Formation\azure-arc

# Étape 1 — Installer les prérequis
.\azure_arc_prepare.ps1

# Étape 2 — Connecter DC01 à Azure Arc (double auth MFA)
.\azure_arc_connect_mfa.ps1
# → Code 1 : authentification initiale  (https://microsoft.com/devicelogin)
# → Code 2 : MFA step-up pour les opérations ARM
```

---

## Vérification globale du lab

```powershell
# Depuis le host Linux :
sshpass -p 'formation123.' ssh Administrateur@192.168.122.10 \
    'powershell -ExecutionPolicy Bypass -File C:\Formation\scripts\check_all.ps1'
```

Sur DC01 :

```powershell
powershell -ExecutionPolicy Bypass -File C:\Formation\scripts\check_all.ps1
```

---

## Captures d'écran livrées

Les captures finales sont stockées dans [screenshots](screenshots) avec la numérotation complète de `01` à `44`.

### 01 à 10 — AD, DNS, DHCP, OU, utilisateurs

<p>
    <img src="screenshots/01_AD-Domain-Controllers.png" width="48%" alt="01 AD Domain Controllers" />
    <img src="screenshots/02_DNS-Manager.png" width="48%" alt="02 DNS Manager" />
</p>
<p>
    <img src="screenshots/03_DNS-Zone-Directe.png" width="48%" alt="03 DNS Zone Directe" />
    <img src="screenshots/04_DNS-Zone-Inverse.png" width="48%" alt="04 DNS Zone Inverse" />
</p>
<p>
    <img src="screenshots/05_PowerShell-Domain-Info.png" width="48%" alt="05 PowerShell Domain Info" />
    <img src="screenshots/06_DHCP-Scope-Config.png" width="48%" alt="06 DHCP Scope Config" />
</p>
<p>
    <img src="screenshots/07_DHCP-Failover.png" width="48%" alt="07 DHCP Failover" />
    <img src="screenshots/08_DHCP-Active-Leases.png" width="48%" alt="08 DHCP Active Leases" />
</p>
<p>
    <img src="screenshots/09_AD-OU-Structure.png" width="48%" alt="09 AD OU Structure" />
    <img src="screenshots/10_AD-Users-IT.png" width="48%" alt="10 AD Users IT" />
</p>

### 11 à 21 — GPO, LAPS, sites, PKI, LDAPS

<p>
    <img src="screenshots/11_GPO-List.png" width="48%" alt="11 GPO List" />
    <img src="screenshots/12_GPO-Password-Policy.png" width="48%" alt="12 GPO Password Policy" />
</p>
<p>
    <img src="screenshots/13_Registry-LAPS-Config.png" width="48%" alt="13 Registry LAPS Config" />
    <img src="screenshots/14_AD-Sites-Subnets.png" width="48%" alt="14 AD Sites Subnets" />
</p>
<p>
    <img src="screenshots/15_PowerShell-PSO.png" width="48%" alt="15 PowerShell PSO" />
    <img src="screenshots/16_CertSrv-CA-Console.png" width="48%" alt="16 CertSrv CA Console" />
</p>
<p>
    <img src="screenshots/17_CertSrv-CA-Properties.png" width="48%" alt="17 CertSrv CA Properties" />
    <img src="screenshots/18_Certmgr-Root-Store.png" width="48%" alt="18 Certmgr Root Store" />
</p>
<p>
    <img src="screenshots/19_CertSrv-Issued-Certs.png" width="48%" alt="19 CertSrv Issued Certs" />
    <img src="screenshots/20_PowerShell-LDAPS-Test.png" width="48%" alt="20 PowerShell LDAPS Test" />
</p>
<p>
    <img src="screenshots/21_LDP-LDAPS-Connection.png" width="48%" alt="21 LDP LDAPS Connection" />
</p>

### 22 à 27 — Groupes, FSMO, réplication, GPO de sécurité

<p>
    <img src="screenshots/22_AD-Groupes.png" width="48%" alt="22 AD Groupes" />
    <img src="screenshots/23_PowerShell-FSMO.png" width="48%" alt="23 PowerShell FSMO" />
</p>
<p>
    <img src="screenshots/24_AD-Replication.png" width="48%" alt="24 AD Replication" />
    <img src="screenshots/25_GPO-Verrouillage-Compte.png" width="48%" alt="25 GPO Verrouillage Compte" />
</p>
<p>
    <img src="screenshots/26_Default-Domain-Policy.png" width="48%" alt="26 Default Domain Policy" />
    <img src="screenshots/27_GPO-AutoEnrollement.png" width="48%" alt="27 GPO AutoEnrollement" />
</p>

### 28 à 33 — SMB, DFS, FSRM, lecteurs réseau

<p>
    <img src="screenshots/28_SMB-Partages.png" width="48%" alt="28 SMB Partages" />
    <img src="screenshots/29_DFS-Namespace.png" width="48%" alt="29 DFS Namespace" />
</p>
<p>
    <img src="screenshots/30_SMB-ABE-Commun.png" width="48%" alt="30 SMB ABE Commun" />
    <img src="screenshots/31_FSRM-Filtre.png" width="48%" alt="31 FSRM Filtre" />
</p>
<p>
    <img src="screenshots/32_FSRM-Quotas.png" width="48%" alt="32 FSRM Quotas" />
    <img src="screenshots/33_GPO-Lecteurs-Reseau.png" width="48%" alt="33 GPO Lecteurs Reseau" />
</p>

### 34 à 41 — NPS, pare-feu, sécurité SMB et registre

<p>
    <img src="screenshots/34_NPS-Console.png" width="48%" alt="34 NPS Console" />
    <img src="screenshots/35_NPS-Clients-RADIUS.png" width="48%" alt="35 NPS Clients RADIUS" />
</p>
<p>
    <img src="screenshots/36_NPS-Politique-Reseau.png" width="48%" alt="36 NPS Politique Reseau" />
    <img src="screenshots/37_NPS-Politique-Connexion.png" width="48%" alt="37 NPS Politique Connexion" />
</p>
<p>
    <img src="screenshots/38_FW-RADIUS-Ports.png" width="48%" alt="38 FW RADIUS Ports" />
    <img src="screenshots/39_SMB-Securite.png" width="48%" alt="39 SMB Securite" />
</p>
<p>
    <img src="screenshots/40_Registre-LSA-WDigest.png" width="48%" alt="40 Registre LSA WDigest" />
    <img src="screenshots/41_Firewall-Profils.png" width="48%" alt="41 Firewall Profils" />
</p>

### 42 à 44 — LAPS et validation finale

<p>
    <img src="screenshots/42_LAPS-Password-PC01.png" width="48%" alt="42 LAPS Password PC01" />
    <img src="screenshots/43_LAPS-GPO-Config.png" width="48%" alt="43 LAPS GPO Config" />
</p>
<p>
    <img src="screenshots/44_Check-All-Script.png" width="48%" alt="44 Check All Script" />
</p>

---

## Dépannage

| Problème | Solution |
|----------|----------|
| AD non disponible après reboot | Attendre 2-3 min : `Get-Service ADWS,Netlogon` |
| DHCP ne distribue pas d'IP | `Get-DhcpServerInDC` → autoriser si vide |
| Jonction domaine échoue | Vérifier que le DNS du client pointe vers DC01 |
| GPO non appliquée | `gpresult /r` sur le client |
| LAPS schéma introuvable | `Update-LapsADSchema` (compte Schema Admin) |
| ExecutionPolicy error | `Set-ExecutionPolicy Bypass -Scope Process -Force` |
| Azure Arc — MFA step-up | Utiliser `azure_arc_connect_mfa.ps1` (double device code) |
| Azure Arc — subscription disabled | Réactiver sur portal.azure.com ou changer de compte |
| Score validation < 100% | Relancer le module concerné, vérifier les logs |
