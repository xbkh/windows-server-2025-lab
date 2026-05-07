# TP08 — Sécurité offensive contrôlée / Purple Team

> Objectif : réaliser la partie offensive du lab `satom.local` sans collecte de secrets, avec des scénarios contrôlés, des traces défensives et un nettoyage simple.

---

## 1. Principe

Ce TP ajoute une couche **purple team** au lab Windows Server 2025. Il ne lance pas d'exploitation réelle et ne récupère pas de hash, ticket Kerberos, mot de passe LAPS ou certificat abusif.

Le script :

- crée une OU dédiée `OffensiveLab`
- crée des comptes de test isolés
- ajoute un compte de service avec SPN pour la revue Kerberos
- active l'audit avancé utile aux scénarios AD
- simule des comportements offensifs par marqueurs d'événements
- collecte les événements Windows et objets AD sensibles
- génère des rapports Markdown et CSV
- nettoie les objets créés quand le TP est terminé

---

## 2. Fichier principal

```powershell
lab\TP_08_Securite-Offensive.ps1
```

À exécuter sur `DC01` dans une console PowerShell Administrateur.

---

## 3. Exécution rapide

```powershell
cd C:\Formation\lab
Set-ExecutionPolicy Bypass -Scope Process -Force

.\TP_08_Securite-Offensive.ps1
```

Cette commande exécute :

1. `Prepare` : prépare l'OU et les comptes
2. `Audit` : active les catégories d'audit
3. `Simulate` : génère les simulations contrôlées
4. `Detect` : collecte les signaux défensifs
5. `Validate` : calcule le score du TP

---

## 4. Modules disponibles

| Module | Rôle |
|--------|------|
| `Prepare` | Crée l'OU `OffensiveLab`, le groupe `GRP_OffensiveLab_Testers`, `olab.audit` et `svc-ol-web` |
| `Audit` | Active les audits Windows/AD utiles : logon, Kerberos, objets, DS Access, policy change |
| `Simulate` | Produit des actions de reconnaissance locale et des marqueurs d'événements contrôlés |
| `Detect` | Génère un rapport Markdown et des exports CSV |
| `Validate` | Vérifie que la partie offensive est prête |
| `Cleanup` | Supprime uniquement l'OU `OffensiveLab` et ses objets |

---

## 5. Commandes utiles

```powershell
# Préparer uniquement les objets de test
.\TP_08_Securite-Offensive.ps1 -Module Prepare

# Activer uniquement l'audit
.\TP_08_Securite-Offensive.ps1 -Module Audit

# Simuler les scénarios sans exploitation
.\TP_08_Securite-Offensive.ps1 -Module Simulate

# Générer le rapport de détection
.\TP_08_Securite-Offensive.ps1 -Module Detect

# Valider l'état du TP
.\TP_08_Securite-Offensive.ps1 -Module Validate

# Nettoyer les objets créés par le TP
.\TP_08_Securite-Offensive.ps1 -Module Cleanup
```

---

## 6. Mode vulnérable volontaire

Pour illustrer l'AS-REP Roasting côté défense, le TP peut créer un compte de test avec la préauthentification Kerberos désactivée :

```powershell
.\TP_08_Securite-Offensive.ps1 -Module Prepare -EnableVulnerableAccounts
```

Ce mode doit rester temporaire. Après l'exercice :

```powershell
.\TP_08_Securite-Offensive.ps1 -Module Detect
.\TP_08_Securite-Offensive.ps1 -Module Cleanup
```

Le rapport `ad_users_no_preauth.csv` doit montrer le compte volontairement vulnérable, puis redevenir vide après nettoyage.

---

## 7. Rapports générés

Par défaut :

```text
C:\Formation\Reports\Offensive
```

Contenu attendu :

| Fichier | Utilité |
|---------|---------|
| `offensive_detection_report_*.md` | Synthèse lisible du TP |
| `ad_users_with_spn.csv` | Comptes de service avec SPN |
| `ad_users_no_preauth.csv` | Comptes sans préauthentification Kerberos |
| `ad_users_password_never_expires.csv` | Comptes avec mot de passe sans expiration |
| `ad_privileged_group_members.csv` | Membres des groupes privilégiés suivis |
| `smb_security.csv` | État du durcissement SMB |
| `windows_security_events.csv` | Événements Windows Security récents |
| `offensive_lab_simulation_events.csv` | Marqueurs de simulation du TP |

---

## 8. Scénarios couverts

| Scénario | Réalisation dans ce TP |
|----------|------------------------|
| Reconnaissance AD | Inventaire contrôlé du domaine, des DCs et de l'OU `OffensiveLab` |
| Reconnaissance réseau | Test des ports AD locaux sur DC01 |
| Accès SMB | Vérification d'accès à `SYSVOL` et `NETLOGON` |
| Password spraying | Simulation par événement, sans tentative de mot de passe |
| Kerberoasting | Revue des comptes avec SPN, sans extraction de ticket |
| AS-REP Roasting | Détection des comptes sans préauthentification |
| AD CS abuse review | Marqueur de revue, sans demande abusive de certificat |
| DCSync review | Marqueur de revue, sans réplication de secrets |

---

## 9. Journaux à consulter

```powershell
# Événements de simulation du TP
Get-WinEvent -FilterHashtable @{
    LogName='Application'
    ProviderName='SATOM-OffensiveLab'
    StartTime=(Get-Date).AddHours(-4)
} | Select-Object TimeCreated,Id,Message

# Signaux sécurité récents
Get-WinEvent -FilterHashtable @{
    LogName='Security'
    Id=4624,4625,4672,4768,4769,4771,5140,5145,7045,1102
    StartTime=(Get-Date).AddHours(-4)
} -MaxEvents 50
```

---

## 10. Nettoyage

```powershell
.\TP_08_Securite-Offensive.ps1 -Module Cleanup
```

Le nettoyage supprime uniquement :

- `OU=OffensiveLab`
- les comptes créés dans cette OU
- le groupe `GRP_OffensiveLab_Testers`

Les rapports restent conservés dans `C:\Formation\Reports\Offensive`.
