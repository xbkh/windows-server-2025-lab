// ============================================================
//  DOCUMENTATION COMPLETE - LAB WINDOWS SERVER 2025
//  Satom IT & Learning Solutions
//  Formation Administration Systeme
// ============================================================

#set document(
  title: "Lab Windows Server 2025 — Documentation Complète",
  author: "Satom IT & Learning Solutions",
)

#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2cm),
  header: context {
    if counter(page).get().first() > 1 {
      set text(size: 9pt, fill: luma(120))
      grid(
        columns: (1fr, 1fr),
        align(left)[Lab Windows Server 2025 — satom.local],
        align(right)[Satom IT & Learning Solutions],
      )
      line(length: 100%, stroke: 0.5pt + luma(180))
    }
  },
  footer: context {
    if counter(page).get().first() > 1 {
      set text(size: 9pt, fill: luma(120))
      line(length: 100%, stroke: 0.5pt + luma(180))
      align(center)[Page #counter(page).display("1 / 1", both: true)]
    }
  },
)

#set text(font: "Liberation Serif", size: 11pt, lang: "fr")
#set par(justify: true, leading: 0.7em)
#set heading(numbering: "1.1.")

// ---- Couleurs de theme ----
#let accent   = rgb("#1a5276")
#let accent2  = rgb("#2980b9")
#let success  = rgb("#1e8449")
#let warn     = rgb("#b7950b")
#let danger   = rgb("#922b21")
#let codebg   = rgb("#f4f4f4")
#let tabhead  = rgb("#d6eaf8")

// ---- Macros utilitaires ----
#let badge(label, color) = box(
  fill: color.lighten(70%),
  stroke: 0.5pt + color,
  radius: 3pt,
  inset: (x: 5pt, y: 2pt),
  text(size: 9pt, weight: "bold", fill: color)[#label],
)

#let score(label) = badge(label, success)
#let paused(label) = badge(label, warn)
#let info-box(title, body) = block(
  fill: accent.lighten(90%),
  stroke: 1pt + accent.lighten(40%),
  radius: 4pt,
  inset: 12pt,
  width: 100%,
)[
  #text(weight: "bold", fill: accent)[#title] \
  #body
]

#let warn-box(title, body) = block(
  fill: warn.lighten(85%),
  stroke: 1pt + warn.lighten(30%),
  radius: 4pt,
  inset: 12pt,
  width: 100%,
)[
  #text(weight: "bold", fill: warn)[⚠ #title] \
  #body
]

#let codeline(content) = block(
  fill: codebg,
  stroke: 0.5pt + luma(180),
  radius: 3pt,
  inset: (x: 8pt, y: 6pt),
  width: 100%,
)[#text(font: "Liberation Mono", size: 9.5pt)[#content]]

// ============================================================
//  PAGE DE TITRE
// ============================================================
#page(
  margin: (top: 3cm, bottom: 3cm, left: 3cm, right: 3cm),
  header: none,
  footer: none,
)[
  #align(center)[
    #v(1cm)
    #block(
      fill: accent,
      radius: 8pt,
      inset: (x: 24pt, y: 16pt),
    )[
      #text(size: 28pt, weight: "bold", fill: white)[
        Windows Server 2025
      ]
    ]
    #v(0.5cm)
    #text(size: 20pt, weight: "bold", fill: accent2)[
      Documentation Complète du Laboratoire
    ]
    #v(0.3cm)
    #text(size: 14pt, fill: luma(80))[
      Administration Système — Formation Pro
    ]

    #v(1.5cm)
    #line(length: 80%, stroke: 2pt + accent.lighten(50%))
    #v(0.8cm)

    #grid(
      columns: (120pt, 1fr),
      gutter: 8pt,
      text(weight: "bold", fill: accent)[Organisation :],
      text[Satom IT & Learning Solutions],
      text(weight: "bold", fill: accent)[Domaine :],
      text[`satom.local`],
      text(weight: "bold", fill: accent)[Environnement :],
      text[KVM/QEMU — Host Linux Pop!\_OS],
      text(weight: "bold", fill: accent)[Version OS :],
      text[Windows Server 2025 Standard],
      text(weight: "bold", fill: accent)[Modules :],
      text[M00 → M19 (16 modules validés)],
      text(weight: "bold", fill: accent)[Statut global :],
      score[A EXCELLENT — 100 %],
    )

    #v(1.5cm)
    #line(length: 80%, stroke: 2pt + accent.lighten(50%))
    #v(0.5cm)
    #text(size: 10pt, fill: luma(100))[
      Version : 2025-03 — Confidentiel — Usage formation interne
    ]
  ]
]

// ============================================================
//  TABLE DES MATIERES
// ============================================================
#page[
  #outline(
    title: [Table des matières],
    indent: 1.5em,
    depth: 2,
  )
]

// ============================================================
//  1. INTRODUCTION
// ============================================================
= Introduction et Objectifs Pédagogiques

Ce document constitue la référence technique complète du laboratoire *Windows Server 2025* déployé dans le cadre de la formation *Administration Système* de Satom IT & Learning Solutions.

La formation alterne modules théoriques et travaux pratiques automatisés via des scripts PowerShell. Chaque module est validé par un script de vérification automatique produisant un score et une note.

== Objectifs de la Formation

- Maîtriser l'installation et la configuration de Windows Server 2025 en environnement Active Directory
- Comprendre les rôles fondamentaux (AD DS, DNS, DHCP, File Server, GPO, LAPS, PKI, etc.)
- Automatiser les tâches d'administration avec PowerShell
- Appliquer les bonnes pratiques de sécurité (durcissement SMB, NTLMv2, PKI, NPS)
- Mettre en œuvre la virtualisation avec Hyper-V
- Préparer l'intégration cloud hybride avec Azure Arc

== Conventions du Document

#grid(
  columns: (80pt, 1fr),
  gutter: 6pt,
  score[A EXCELLENT],  [100 % des critères validés],
  score[12/12],        [Score maximum d'un TP],
  paused[PAUSE],       [Module non déployé (contrainte externe)],
  badge("code", accent2), [Commande ou valeur technique],
)

// ============================================================
//  2. ARCHITECTURE DU LABORATOIRE
// ============================================================
= Architecture du Laboratoire

== Topologie Réseau

Le laboratoire est hébergé intégralement sur un hôte Linux (Pop!\_OS) via KVM/QEMU. Trois machines virtuelles constituent l'infrastructure :

#figure(
  table(
    columns: (80pt, 100pt, 90pt, 90pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    align: (left, center, center, center, left),
    [*Machine*], [*Rôle*], [*Adresse IP*], [*RAM / vCPU*], [*Description*],
    [`DC01`], [PDC], [`192.168.122.10`], [4 Go / 2], [Contrôleur de domaine principal, DNS, DHCP, PKI, NPS],
    [`DC02`], [BDC], [`192.168.122.20`], [2 Go / 2], [Contrôleur de domaine secondaire, réplica AD],
    [`PC01`], [Client], [`192.168.122.50`], [2 Go / 2], [Poste client Windows Server 2025, membre du domaine],
  ),
  caption: "Machines virtuelles du laboratoire",
)

== Paramètres Réseau

#figure(
  table(
    columns: (140pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Réseau KVM], [`virbr0` — 192.168.122.0/24],
    [Passerelle], [`192.168.122.1`],
    [Domaine AD], [`satom.local`],
    [NetBIOS], [`SATOM`],
    [DNS primaire], [`192.168.122.10` (DC01)],
    [DNS secondaire], [`192.168.122.20` (DC02)],
    [Plage DHCP], [`192.168.122.100 — 192.168.122.200`],
    [Failover DHCP], [DC01 ↔ DC02 — mode `LoadBalance`],
  ),
  caption: "Configuration réseau",
)

== Credentials du Laboratoire

#warn-box("Avertissement")[
  Les identifiants ci-dessous sont destinés exclusivement à l'environnement de formation isolé. Ne jamais utiliser ces mots de passe en production.
]

#figure(
  table(
    columns: (130pt, 120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Compte*], [*Mot de passe*], [*Usage*],
    [`Administrateur`], [`formation123.`], [Compte local et domaine sur toutes les VMs],
    [`SATOM\Administrateur`], [`formation123.`], [Administrateur entreprise du domaine],
    [RADIUS Secret], [`RadiusSecret123!`], [Clients NPS/RADIUS (SW-CORE-01, AP-WIFI-01, VPN-GW-01)],
  ),
  caption: "Credentials",
)

== Accès SSH depuis le Host Linux

Les scripts sont déployés par SSH depuis le host Linux vers DC01. Commandes types :

#codeline("sshpass -p 'formation123.' scp -o StrictHostKeyChecking=no <fichier_local> \\")
#codeline("    'Administrateur\@192.168.122.10:C:\\Formation\\lab\\<fichier>'")

#codeline("sshpass -p 'formation123.' ssh -o StrictHostKeyChecking=no \\")
#codeline("    Administrateur\@192.168.122.10 \\")
#codeline("    \"powershell -ExecutionPolicy Bypass -File C:\\\\Formation\\\\lab\\\\<script>\"")

#info-box("Important — Encodage des scripts")[
  PowerShell 5.1 via SSH requiert des fichiers en *ASCII pur*. Aucun accent, emoji ou caractère non-ASCII dans les scripts `.ps1`. La génération via Python avec `errors='replace'` garantit cette conformité.
]

== Structure des Répertoires

#figure(
  table(
    columns: (200pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Chemin*], [*Contenu*],
    [`C:\Formation\lab\`], [Scripts PowerShell TP_00 à TP_07 + check_all.ps1],
    [`C:\Partages\`], [Partages réseau DFS (Paris, Bordeaux, Direction, IT, Software, Commun)],
    [`C:\Windows\system32\LogFiles\NPS\`], [Journaux NPS/RADIUS],
    [Host : `~/Documents/GIT/windows server/`], [Workspace Git local (scripts sources, docs)],
  ),
  caption: "Répertoires importants",
)

// ============================================================
//  3. MODULES DE FORMATION
// ============================================================
= Modules de Formation

// -------- M00 --------
== Module 00 — Environnement de Laboratoire #h(1fr) #score[Validé]

=== Objectifs
Construire l'infrastructure de laboratoire isolée : machines virtuelles, réseau, préparation des OS Windows Server 2025.

=== Infrastructure Déployée

- *Hyperviseur* : KVM/QEMU sur host Linux Pop!\_OS
- *3 VMs* : DC01 (PDC), DC02 (BDC), PC01 (client)
- *Réseau* : pont virtuel `virbr0`, plage 192.168.122.0/24
- *SSH activé* sur DC01 et DC02 pour l'automatisation

=== Script : `TP_00_Init-Lab.ps1`

Ce script initialise l'environnement de base : renommage des VMs, configuration IP statique, activation WinRM et SSH, installation des prérequis.

// -------- M02 --------
== Module 02 — Active Directory Domain Services #h(1fr) #score[Validé]

=== Objectifs
Déployer la forêt Active Directory `satom.local`, promouvoir DC01 comme PDC, DC02 comme BDC.

=== Configuration AD DS

#figure(
  table(
    columns: (160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Nom de la forêt], [`satom.local`],
    [Niveau fonctionnel forêt], [Windows Server 2016 (niveau 7)],
    [Niveau fonctionnel domaine], [Windows Server 2016 (niveau 7)],
    [PDC Emulator], [`DC01.satom.local`],
    [RID Master], [`DC01.satom.local`],
    [Schema Master], [`DC01.satom.local`],
    [Infrastructure Master], [`DC01.satom.local`],
    [Domain Naming Master], [`DC01.satom.local`],
    [Corbeille AD], [Activée],
  ),
  caption: "Configuration Active Directory",
)

=== Mécanisme d'Authentification Kerberos

+ L'utilisateur saisit ses identifiants sur PC01
+ PC01 interroge DC01 (enregistrement SRV `_kerberos._tcp.satom.local`)
+ DC01 émet un *Ticket Granting Ticket* (TGT) valide 10 h
+ Pour chaque ressource, le TGT permet d'obtenir un ticket de service
+ Authentification mutuelle client ↔ serveur (Kerberos v5)

=== Script : `START-Formation.ps1`

Script de bootstrap principal qui orchestre le déploiement complet du lab en appelant les TP dans l'ordre.

// -------- M03 --------
== Module 03 — DHCP avec Failover #h(1fr) #score[Validé]

=== Objectifs
Déployer le service DHCP sur DC01, configurer une étendue, mettre en place le failover avec DC02.

=== Configuration DHCP

#figure(
  table(
    columns: (160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Étendue], [`192.168.122.0/24`],
    [Plage d'attribution], [`192.168.122.100 — 192.168.122.200`],
    [Exclusions], [`192.168.122.1 — 192.168.122.99` (serveurs/infra)],
    [Durée du bail], [8 jours],
    [Passerelle (opt. 3)], [`192.168.122.1`],
    [DNS (opt. 6)], [`192.168.122.10`, `192.168.122.20`],
    [Domaine (opt. 15)], [`satom.local`],
    [Failover], [DC01 ↔ DC02 — mode `LoadBalance` 50/50],
    [Nom du partenariat], [`FO-DC01-DC02`],
  ),
  caption: "Configuration DHCP",
)

=== Processus DORA

#figure(
  table(
    columns: (80pt, 90pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Étape*], [*Direction*], [*Description*],
    [*Discover*], [Client → Broadcast], [Recherche d'un serveur DHCP (255.255.255.255:67)],
    [*Offer*], [Serveur → Client], [Proposition d'une adresse IP et durée de bail],
    [*Request*], [Client → Broadcast], [Acceptation de l'offre],
    [*Acknowledge*], [Serveur → Client], [Confirmation et attribution des paramètres complets],
  ),
  caption: "Processus DORA",
)

// -------- M04/05 --------
== Module 04/05 — OUs, Utilisateurs et GPO #h(1fr) #score[Validé]

=== Objectifs
Créer la structure organisationnelle d'entreprise dans AD, créer les utilisateurs, déployer 7 GPOs.

=== Structure des Unités d'Organisation

#codeline("\_SATOM")
#codeline("├── Direction")
#codeline("│   └── Marie.Bernard (Directrice)")
#codeline("├── IT")
#codeline("│   ├── Jean.Dupont (Admin IT)")
#codeline("│   └── Sophie.Martin (Tech Support)")
#codeline("├── RH")
#codeline("│   └── Pierre.Leroy (DRH)")
#codeline("├── Finance")
#codeline("│   └── Isabelle.Moreau (DAF)")
#codeline("├── Paris")
#codeline("│   └── (utilisateurs site Paris)")
#codeline("└── Bordeaux")
#codeline("    └── (utilisateurs site Bordeaux)")

=== Utilisateurs Créés (12 comptes)

#figure(
  table(
    columns: (160pt, 120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 6pt,
    [*SamAccountName*], [*OU*], [*Groupes*],
    [`jean.dupont`], [`\_SATOM\IT`], [GRP-IT-Admins, GRP-Direction],
    [`sophie.martin`], [`\_SATOM\IT`], [GRP-IT-Support],
    [`marie.bernard`], [`\_SATOM\Direction`], [GRP-Direction, GRP-DFS-Direction],
    [`pierre.leroy`], [`\_SATOM\RH`], [GRP-RH],
    [`isabelle.moreau`], [`\_SATOM\Finance`], [GRP-Finance, GRP-DFS-Finance],
    [`thomas.petit`], [`\_SATOM\Paris`], [GRP-Paris],
    [`claire.rousseau`], [`\_SATOM\Paris`], [GRP-Paris],
    [`nicolas.blanc`], [`\_SATOM\Bordeaux`], [GRP-Bordeaux],
    [`emilie.noir`], [`\_SATOM\Bordeaux`], [GRP-Bordeaux],
    [`lucas.grand`], [`\_SATOM\IT`], [GRP-IT-Admins],
    [`chloe.petit`], [`\_SATOM\RH`], [GRP-RH],
    [`alex.martin`], [`\_SATOM\Finance`], [GRP-Finance],
  ),
  caption: "Comptes utilisateurs du domaine",
)

=== Stratégies de Groupe Déployées (7 GPOs)

#figure(
  table(
    columns: (200pt, 90pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Nom de la GPO*], [*Liée à*], [*Paramètres principaux*],
    [`GPO-Securite-Domaine`], [Domaine], [Politique de mot de passe, audit, Credential Guard],
    [`GPO-Configuration-IT`], [`\_SATOM\IT`], [Droits admin, accès MMC, outils d'admin réseau],
    [`GPO-Restrictions-Users`], [`\_SATOM`], [Panneaux de configuration restreints, USB limité],
    [`GPO-Lecteurs-Reseau`], [`\_SATOM`], [Mappage lecteur Z: → `\\satom.local\data`],
    [`GPO-Firewall-Serveurs`], [`Domain Controllers`], [Règles pare-feu strictes, RDP limité IT],
    [`GPO-LAPS-Activation`], [`\_SATOM` (PC01)], [LAPS activé, rotation mot de passe local 30 j],
    [`GPO-NPS-RADIUS-Clients`], [Domaine], [Règles FW UDP/1812 + UDP/1813 pour RADIUS],
  ),
  caption: "GPOs déployées",
)

// -------- M06 --------
== Module 06 — Politique de Mots de Passe #h(1fr) #score[Validé]

=== Objectifs
Configurer la politique de mot de passe du domaine et une Fine-Grained Password Policy pour les administrateurs.

=== Politique Domaine (Default Domain Policy)

#figure(
  table(
    columns: (200pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Longueur minimale], [12 caractères],
    [Complexité], [Activée (maj + min + chiffre + symbole)],
    [Durée maximale], [60 jours],
    [Historique], [10 mots de passe mémorisés],
    [Verrouillage], [5 échecs → verrouillage 30 min],
    [Compteur remis à zéro après], [30 minutes],
  ),
  caption: "Politique de mot de passe du domaine",
)

=== Fine-Grained Password Policy (FGPP) — Administrateurs

Politique `PSO-Admins` appliquée au groupe `GRP-IT-Admins` :

- Longueur minimale : *16 caractères*
- Durée maximale : *30 jours*
- Verrouillage : *3 échecs → 60 min*
- Priorité : 10 (supplante la politique domaine)

// -------- M07 --------
== Module 07 — LAPS (Local Administrator Password Solution) #h(1fr) #score[Validé]

=== Objectifs
Déployer Windows LAPS pour gérer automatiquement le mot de passe Administrateur local de PC01.

=== Configuration LAPS

#figure(
  table(
    columns: (160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Schéma AD étendu], [Oui (`Update-LapsADSchema`)],
    [Machines gérées], [`PC01` (OU `\_SATOM`)],
    [Rotation du MDP], [Tous les 30 jours],
    [Compte géré], [`Administrateur` (local)],
    [Stockage], [Active Directory (attribut `ms-Mcs-AdmPwd`)],
    [GPO appliquée], [`GPO-LAPS-Activation`],
  ),
  caption: "Configuration LAPS",
)

=== Lecture du Mot de Passe LAPS

#codeline("Get-LapsADPassword -Identity PC01 -AsPlainText | Select-Object Password, ExpirationTimestamp")

// -------- M08 --------
== Module 08 — Sites et Subnets Active Directory #h(1fr) #score[Validé]

=== Objectifs
Créer les sites AD, sous-réseaux et liens de site pour optimiser la réplication et la localisation des services.

=== Sites Configurés

#figure(
  table(
    columns: (130pt, 120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Site AD*], [*Subnet*], [*Description*],
    [`Paris`], [`192.168.10.0/24`], [Siège social — DC01 assigné à ce site],
    [`Bordeaux`], [`192.168.20.0/24`], [Agence — DC02 assigné à ce site],
    [`DMZ`], [`192.168.30.0/24`], [Zone démilitarisée — serveurs exposés],
  ),
  caption: "Sites et sous-réseaux AD",
)

=== Liens de Site

- `DEFAULTIPSITELINK` : Paris ↔ Bordeaux, coût = 100, réplication toutes les 180 min
- Les DCs s'authentifient localement (DC01 pour machines du site Paris, DC02 pour Bordeaux)

// -------- M11 --------
== Module 11 — Automatisation PowerShell et Logiciels #h(1fr) #score[Validé]

=== Objectifs
Installer des logiciels via WinGet, déployer PowerShell 7, VSCode, créer une tâche planifiée de rapport AD.

=== Logiciels Installés via WinGet

#figure(
  table(
    columns: (180pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Package*], [*ID WinGet*],
    [PowerShell 7], [`Microsoft.PowerShell`],
    [Visual Studio Code], [`Microsoft.VisualStudioCode`],
    [Notepad++], [`Notepad++.Notepad++`],
    [Git], [`Git.Git`],
  ),
  caption: "Logiciels déployés via WinGet",
)

=== Tâche Planifiée : `Rapport\_AD`

- *Déclencheur* : tous les jours à 07h00
- *Action* : script PowerShell générant un rapport CSV des utilisateurs AD inactifs depuis 30 jours
- *Exécution* : sous `SYSTEM`, niveau le plus élevé
- *Chemin de sortie* : `C:\Formation\rapports\`

// -------- M12/13 --------
== Module 12/13 — Performance et Monitoring #h(1fr) #score[Validé]

=== Objectifs
Configurer le plan d'alimentation haute performance, créer une tâche de monitoring système.

=== Configuration Réalisée

- *Plan d'alimentation* : `Performances élevées` activé sur DC01 et DC02
- *Collecteur de données* : ensemble `SystemMonitor` — CPU, RAM, disque, réseau — intervalle 5 min
- *Tâche planifiée `Monitoring`* : collecte journalière des métriques vers `C:\Formation\monitoring\`
- *Alertes* : événement Windows si CPU > 90 % pendant 5 min (EventID 100, source `LabMonitor`)

// -------- M14 --------
== Module 14 — Sécurité Réseau et Durcissement #h(1fr) #score[Validé]

=== Objectifs
Appliquer le durcissement SMB, désactiver les protocoles d'authentification faibles (LM/NTLMv1), durcir les stratégies de sécurité locales.

=== Paramètres de Durcissement Appliqués

#figure(
  table(
    columns: (200pt, 120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*], [*Justification*],
    [SMBv1], [`Désactivé`], [Vulnérable (EternalBlue, WannaCry)],
    [SMB Signing], [`Obligatoire`], [Prévient les attaques MITM sur partages],
    [LmCompatibilityLevel], [`5` (NTLMv2 uniquement)], [Bannit LM et NTLMv1 obsolètes],
    [WDigest Authentication], [`Désactivé` (reg = 0)], [Supprime les creds en clair dans LSASS],
    [Credential Guard], [`Activé`], [Isole les identifiants dans un enclave VBS],
    [Audit des connexions], [`Réussite + Échec`], [Détection des tentatives d'accès non autorisées],
    [RDP NLA], [`Requis`], [Authentification avant ouverture de session RDP],
  ),
  caption: "Paramètres de durcissement sécurité",
)

=== Commandes PowerShell Clés

#codeline("Set-SmbServerConfiguration -EnableSMB1Protocol \$false -Force")
#codeline("Set-SmbServerConfiguration -RequireSecuritySignature \$true -Force")
#codeline("Set-ItemProperty HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa -Name LmCompatibilityLevel -Value 5")
#codeline("Set-ItemProperty HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\WDigest -Name UseLogonCredential -Value 0")

// -------- M15 --------
== Module 15 — Hyper-V et Virtualisation #h(1fr) #score[Validé]

=== Objectifs
Installer Hyper-V sur DC01 (virtualisation imbriquée), créer des commutateurs virtuels, déployer une VM de démonstration.

=== Configuration Hyper-V

#figure(
  table(
    columns: (160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Élément*], [*Configuration*],
    [Hyperviseur], [Hyper-V installé sur DC01 (virtualisation imbriquée KVM)],
    [vSwitch Interne], [`vSwitch-Interne` — type Internal],
    [vSwitch Externe], [`vSwitch-Externe` — type External (lié à l'adaptateur physique)],
    [VM de démo], [`VM-Demo-WS2025`, Génération 2, 2 Go RAM dynamique],
    [Disque VM], [VHDX 40 Go dynamique],
    [OS invité], [Windows Server 2025 (ISO monté)],
    [Points de contrôle], [Activés — type Standard],
  ),
  caption: "Configuration Hyper-V",
)

=== Nouveautés Hyper-V Windows Server 2025

- Support jusqu'à *240 To de RAM par VM* et *2048 vCPU*
- Génération 2 par défaut (UEFI/Secure Boot)
- Compatibilité dynamique de processeurs pour Live Migration inter-génération
- VBS (Virtualization-Based Security) activée par défaut dans les VMs invitées

// -------- M16 --------
== Module 16 — Azure Arc #h(1fr) #paused[En Pause — Subscription Inactive]

=== Statut

Ce module est suspendu en raison de l'inactivité de la souscription Azure associée. L'inscription Azure Arc nécessite une souscription valide pour onboarder les serveurs on-premises.

=== Objectifs Prévus

- Onboarder DC01 et DC02 dans Azure Arc
- Activer le *Hotpatching* (mises à jour sans redémarrage)
- Utiliser Azure Policy pour la conformité des serveurs on-premises
- Accéder aux logs via Azure Monitor / Log Analytics Workspace

=== Commande d'Onboarding (pour référence)

#codeline("Invoke-WebRequest -Uri https://aka.ms/azcmagent-windows -OutFile \".\\install_windows_azcmagent.ps1\"")
#codeline(".\\install_windows_azcmagent.ps1")
#codeline("azcmagent connect --subscription-id <ID> --resource-group <RG> --location westeurope --tenant-id <TENANT>")

// -------- M17 --------
== Module 17 — PKI / ADCS et LDAPS #h(1fr) #score[10/10 — A Excellent]

=== Objectifs
Déployer une Autorité de Certification d'entreprise (ADCS), publier le certificat racine dans AD, activer LDAPS et activer l'auto-enrôlement.

=== Autorité de Certification — SATOM-CA

#figure(
  table(
    columns: (180pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Nom de la CA], [`SATOM-CA`],
    [Type], [Enterprise Root CA],
    [Algorithme de clé], [RSA 4096 bits],
    [Algorithme de hachage], [SHA-256],
    [Validité], [10 ans (expire 24/03/2036)],
    [Thumbprint], [`4CE4D6FE4617EAC569A6EED78688BA33334A6A1F`],
    [Publication AD], [Oui — partition `CN=Public Key Services,CN=Services,CN=Configuration`],
    [CDP (CRL Distribution Point)], [`ldap:///CN=SATOM-CA,CN=satom,CN=CDP,...`],
    [AIA (Authority Information Access)], [Publié dans AD],
  ),
  caption: "Paramètres de l'Autorité de Certification SATOM-CA",
)

=== LDAPS (LDAP over SSL/TLS)

- *Port* : TCP/636
- *Certificat* : émis par SATOM-CA, lié au service LDAP de DC01
- *Vérification* : `Test-NetConnection -ComputerName DC01 -Port 636` → `TcpTestSucceeded : True`
- *Impact* : toutes les authentifications AD peuvent désormais être signées et chiffrées via TLS 1.2+

=== Auto-Enrôlement des Certificats

- GPO `GPO-Securite-Domaine` active l'auto-enrôlement (`User Configuration > Certificate Services Client`)
- Les ordinateurs et utilisateurs reçoivent automatiquement leurs certificats au démarrage/connexion
- Modèles activés : `Computer`, `User`, `DomainController`

=== Script : `TP_05_PKI-CA.ps1`

Le script exécute 4 modules séquentiels :

+ *Roles* — Installation de `ADCS-Cert-Authority` et `ADCS-Web-Enrollment`
+ *CA* — Configuration CA Enterprise Root avec RSA 4096 / SHA-256 / 10 ans
+ *GPO* — Création et liaison de la GPO d'auto-enrôlement
+ *LDAPS* — Redémarrage LDAP, vérification port 636
+ *Validate* — 10 critères : CA configurée, certificat racine AD, LDAPS actif, etc.

#info-box("Fix technique — Détection CA")[
  La détection de la CA via `Get-Service CertSvc` était insuffisante (le service peut exister sans CA configurée). Le script utilise désormais la clé de registre `HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration` pour confirmer la configuration effective.
]

// -------- M18 --------
== Module 18 — File Server, DFS et FSRM #h(1fr) #score[12/12 — A Excellent]

=== Objectifs
Déployer un serveur de fichiers avec DFS Namespaces, FSRM (quotas et filtrage de fichiers), mappage des lecteurs via GPO.

=== Partages Créés

#figure(
  table(
    columns: (120pt, 160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Partage*], [*Chemin local*], [*Description / ACL*],
    [`Paris`], [`C:\Partages\Paris`], [Groupe GRP-Paris — Modify ; Admins — Full Control],
    [`Bordeaux`], [`C:\Partages\Bordeaux`], [Groupe GRP-Bordeaux — Modify],
    [`Direction`], [`C:\Partages\Direction`], [GRP-Direction — Modify ; lecture Direction uniquement],
    [`IT`], [`C:\Partages\IT`], [GRP-IT-Admins — Full Control ; GRP-IT-Support — Modify],
    [`Software`], [`C:\Partages\Software`], [Tous — Read ; IT — Modify (dépôt logiciels)],
    [`Commun`], [`C:\Partages\Commun`], [Utilisateurs authentifiés — Modify (espace commun)],
  ),
  caption: "Partages réseau",
)

=== DFS Namespace

- *Namespace DFS* : `\\satom.local\data` (type Domain-based)
- *6 liens DFS* mappés vers les partages physiques sur DC01 :

#codeline("\\\\satom.local\\data\\Paris     → \\\\DC01\\Paris")
#codeline("\\\\satom.local\\data\\Bordeaux  → \\\\DC01\\Bordeaux")
#codeline("\\\\satom.local\\data\\Direction → \\\\DC01\\Direction")
#codeline("\\\\satom.local\\data\\IT        → \\\\DC01\\IT")
#codeline("\\\\satom.local\\data\\Software  → \\\\DC01\\Software")
#codeline("\\\\satom.local\\data\\Commun    → \\\\DC01\\Commun")

=== FSRM — Quotas et Filtrage

#figure(
  table(
    columns: (160pt, 90pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Partage*], [*Quota*], [*Alerte*],
    [Paris, Bordeaux, Commun], [5 Go], [Avertissement à 80 %],
    [Direction, IT], [10 Go], [Avertissement à 85 %],
    [Software], [20 Go], [Avertissement à 90 %],
  ),
  caption: "Quotas FSRM par partage",
)

- *Filtrage de fichiers* : groupe `Executables-Bloques` bloquant `.exe`, `.bat`, `.cmd`, `.msi`, `.ps1` dans tous les partages sauf `Software` et `IT`

=== GPO de Mappage des Lecteurs

- `GPO-Lecteurs-Reseau` liée à `\_SATOM`
- Lecteur *Z:* → `\\satom.local\data\Commun` (pour tous les utilisateurs)
- Lecteur *W:* → `\\satom.local\data\<département>` (ciblage par appartenance au groupe)

=== Script : `TP_06_FileServer-DFS-FSRM.ps1`

5 modules : Roles → Shares → DFS → FSRM → Validate (12 critères).

// -------- M19 --------
== Module 19 — NPS / RADIUS #h(1fr) #score[12/12 — A Excellent]

=== Objectifs
Déployer le rôle NPS (Network Policy Server) sur DC01 pour l'authentification RADIUS des équipements réseau (switches, bornes Wi-Fi, VPN).

=== Configuration NPS

#figure(
  table(
    columns: (160pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Paramètre*], [*Valeur*],
    [Rôle installé], [`NPAS` (Network Policy and Access Services)],
    [Service], [`IAS` (Internet Authentication Service) — Running],
    [Enregistrement AD], [Oui — DC01 enregistré comme serveur NPS dans AD],
    [Port RADIUS Auth.], [UDP/1812],
    [Port RADIUS Accounting], [UDP/1813],
    [Journaux], [`C:\Windows\system32\LogFiles\NPS\`],
    [Secret RADIUS], [`RadiusSecret123!` (commun à tous les clients)],
  ),
  caption: "Configuration NPS",
)

=== Clients RADIUS

#figure(
  table(
    columns: (130pt, 120pt, 80pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Nom*], [*IP*], [*Type*], [*Usage*],
    [`SW-CORE-01`], [`192.168.122.1`], [Switch], [Authentification 802.1X switch cœur de réseau],
    [`AP-WIFI-01`], [`192.168.122.5`], [AP Wi-Fi], [Authentification WPA2-Enterprise réseau sans-fil],
    [`VPN-GW-01`], [`192.168.122.2`], [VPN], [Authentification des sessions VPN distantes],
  ),
  caption: "Clients RADIUS configurés",
)

=== Politiques Réseau NPS

#figure(
  table(
    columns: (180pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Politique*], [*Conditions / Résultat*],
    [`NP-Domain-Admins`], [Groupe `SATOM\Domain Admins` → Accès accordé, session illimitée],
    [`NP-IT-Staff`], [Groupe `SATOM\GRP-IT-Admins` ou `GRP-IT-Support` → Accès accordé],
    [`NP-Wireless-Users`], [Groupe `SATOM\Domain Users` + type accès Wireless → Accès accordé],
    [`NP-Deny-Others`], [Tous les autres → Accès refusé],
  ),
  caption: "Politiques réseau NPS",
)

=== Politique de Requête de Connexion

- `CRP-Local-Auth` : traitement local des requêtes RADIUS (pas de proxy vers serveur distant)
- Méthodes d'authentification autorisées : MS-CHAPv2, EAP (TLS, PEAP)

=== GPO Associée

- `GPO-NPS-RADIUS-Clients` liée au domaine
- Règles de pare-feu entrantes : UDP/1812 et UDP/1813 autorisés pour les IPs des clients RADIUS

=== Script : `TP_07_NPS-RADIUS.ps1`

5 modules séquentiels :

+ *Roles* — Installation NPAS, démarrage IAS
+ *Config* — Enregistrement dans AD, configuration journaux
+ *Policy* — 3 clients RADIUS + 4 politiques réseau + 1 CRP
+ *GPO* — Règles pare-feu UDP/1812 et 1813
+ *Validate* — 12 critères : NPAS installé, IAS Running, enregistrement AD, clients présents, politiques actives, ports ouverts

#info-box("Comportement du service IAS")[
  Le service NPS s'appelle `IAS` (Internet Authentication Service) en PowerShell — héritage historique de Windows Server 2003. La vérification correcte est `Get-Service IAS | Where-Object Status -eq 'Running'`.
]

// ============================================================
//  4. SCRIPTS DE DEPLOIEMENT
// ============================================================
= Scripts de Déploiement

== Vue d'Ensemble

#figure(
  table(
    columns: (200pt, 70pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Script*], [*Lignes*], [*Modules couverts*],
    [`START-Formation.ps1`], [~80], [Orchestrateur principal — appelle tous les TP],
    [`TP_00_Init-Lab.ps1`], [~150], [M00 — Bootstrap VMs, IP, SSH, WinRM],
    [`TP_01_AD-DNS.ps1`], [~200], [M02 — AD DS, DNS, promotion DC01 et DC02],
    [`TP_02_DHCP.ps1`], [~100], [M03 — DHCP, failover FO-DC01-DC02],
    [`TP_03_OU-Users-GPO.ps1`], [~350], [M04/05/06/07/08 — OUs, users, 7 GPOs, LAPS, sites],
    [`TP_04_Securite.ps1`], [~180], [M11/12/13/14/15 — WinGet, perf., monitoring, durcissement, Hyper-V],
    [`TP_05_PKI-CA.ps1`], [452], [M17 — ADCS, SATOM-CA, LDAPS, auto-enrôlement],
    [`TP_06_FileServer-DFS-FSRM.ps1`], [~320], [M18 — File Server, DFS-N, FSRM, quotas, GPO],
    [`TP_07_NPS-RADIUS.ps1`], [338], [M19 — NPS, RADIUS, clients, politiques, GPO],
    [`check_all.ps1`], [~300], [Validation globale — tous modules],
  ),
  caption: "Scripts PowerShell du lab",
)

== Procédure de Déploiement Complète

#codeline("# 1. Copier tous les scripts sur DC01")
#codeline("sshpass -p 'formation123.' scp -o StrictHostKeyChecking=no lab/*.ps1 \\")
#codeline("    'Administrateur\@192.168.122.10:C:\\Formation\\lab\\'")
#v(0.3em)
#codeline("# 2. Lancer l'orchestrateur")
#codeline("sshpass -p 'formation123.' ssh Administrateur\@192.168.122.10 \\")
#codeline("    \"powershell -ExecutionPolicy Bypass -File C:\\\\Formation\\\\lab\\\\START-Formation.ps1\"")
#v(0.3em)
#codeline("# 3. Vérification globale")
#codeline("sshpass -p 'formation123.' ssh Administrateur\@192.168.122.10 \\")
#codeline("    \"powershell -ExecutionPolicy Bypass -File C:\\\\Formation\\\\lab\\\\check_all.ps1\"")

== Script d'Orchestration — `START-Formation.ps1`

Le script `START-Formation.ps1` déploie l'ensemble du lab en séquence :

+ Vérifie les prérequis (connexion réseau, espace disque)
+ Crée l'arborescence `C:\Formation\lab\`
+ Appelle chaque TP dans l'ordre
+ Attend la confirmation de réussite avant de passer au suivant
+ Génère un rapport final en `C:\Formation\rapport-final.txt`

// ============================================================
//  5. VALIDATION ET SCORES
// ============================================================
= Récapitulatif des Scores et Validations

== Tableau de Bord des Modules

#figure(
  table(
    columns: (50pt, 170pt, 60pt, 70pt, 1fr),
    fill: (_, row) => {
      if row == 0 { tabhead }
      else if row > 0 and row <= 16 { white }
      else { white }
    },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Module*], [*Titre*], [*Score*], [*Note*], [*Éléments clés validés*],
    [M00], [Environnement Lab], [—], [Validé], [VMs KVM, réseau virbr0, SSH],
    [M02], [AD DS + DNS], [—], [Validé], [satom.local, DC01 PDC, DC02 BDC],
    [M03], [DHCP + Failover], [—], [Validé], [Étendue 100-200, failover LoadBalance],
    [M04], [OUs + Utilisateurs], [—], [Validé], [\_SATOM, 12 users, groupes],
    [M05], [GPO], [—], [Validé], [7 GPOs déployées et liées],
    [M06], [Politique MDP], [—], [Validé], [12 chars / 60j / PSO admins 16 chars],
    [M07], [LAPS], [—], [Validé], [PC01 géré, rotation 30j],
    [M08], [Sites AD], [—], [Validé], [Paris + Bordeaux + DMZ + 3 subnets],
    [M11], [Automatisation PS], [—], [Validé], [WinGet, PS7, VSCode, tâche Rapport\_AD],
    [M12], [Performance], [—], [Validé], [Plan haute perf., collecteur données],
    [M13], [Monitoring], [—], [Validé], [Tâche Monitoring, alertes CPU],
    [M14], [Sécurité avancée], [—], [Validé], [SMBv1 off, signing on, LM=5, WDigest=0],
    [M15], [Hyper-V], [—], [Validé], [2 vSwitches, VM-Demo-WS2025 Gen2],
    [M16], [Azure Arc], [—], [Pause], [Subscription inactive],
    [M17], [PKI / ADCS], [10/10], [A Excellent], [SATOM-CA RSA4096/SHA256, LDAPS port 636],
    [M18], [File Server DFS], [12/12], [A Excellent], [DFS-N \\satom.local\data, 6 quotas FSRM],
    [M19], [NPS / RADIUS], [12/12], [A Excellent], [3 clients, 4 politiques, GPO FW UDP 1812/1813],
  ),
  caption: "Tableau de bord de la formation",
)

== Critères de Validation — M17 PKI (10/10)

#figure(
  table(
    columns: (1fr, 70pt),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Critère*], [*Statut*],
    [Rôle ADCS-Cert-Authority installé], [OK],
    [Service CertSvc Running], [OK],
    [CA configurée dans le registre (clé CertSvc\Configuration)], [OK],
    [Certificat racine publié dans AD (NTAuthCertificates)], [OK],
    [Certificat dans le magasin LocalMachine\Root], [OK],
    [Algorithme RSA 4096 bits confirmé], [OK],
    [Hachage SHA-256 confirmé], [OK],
    [Port LDAPS 636 accessible (TCP)], [OK],
    [GPO auto-enrôlement liée à l'OU \_SATOM], [OK],
    [CRL publiée et accessible], [OK],
  ),
  caption: "Critères de validation M17 PKI",
)

== Critères de Validation — M19 NPS (12/12)

#figure(
  table(
    columns: (1fr, 70pt),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Critère*], [*Statut*],
    [Rôle NPAS installé], [OK],
    [Service IAS Running], [OK],
    [DC01 enregistré comme serveur NPS dans AD], [OK],
    [Client RADIUS SW-CORE-01 (192.168.122.1) présent], [OK],
    [Client RADIUS AP-WIFI-01 (192.168.122.5) présent], [OK],
    [Client RADIUS VPN-GW-01 (192.168.122.2) présent], [OK],
    [Politique réseau NP-Domain-Admins présente], [OK],
    [Politique réseau NP-IT-Staff présente], [OK],
    [Politique réseau NP-Wireless-Users présente], [OK],
    [Politique de requête CRP-Local-Auth présente], [OK],
    [Port UDP/1812 autorisé dans le pare-feu], [OK],
    [Port UDP/1813 autorisé dans le pare-feu], [OK],
  ),
  caption: "Critères de validation M19 NPS",
)

// ============================================================
//  6. COMMANDES DE VERIFICATION RAPIDE
// ============================================================
= Commandes de Vérification Rapide

== Active Directory

#codeline("# Vérifier les DCs du domaine")
#codeline("Get-ADDomainController -Filter * | Select-Object Name, IPv4Address, IsGlobalCatalog, OperationMasterRoles")
#v(0.3em)
#codeline("# Vérifier les rôles FSMO")
#codeline("netdom query fsmo")
#v(0.3em)
#codeline("# Lister les utilisateurs avec leur OU")
#codeline("Get-ADUser -Filter * -Properties DistinguishedName | Select-Object SamAccountName, DistinguishedName")

== PKI / ADCS

#codeline("# Vérifier la CA")
#codeline("certutil -ping SATOM-CA")
#codeline("certutil -CA.cert C:\\temp\\satom-ca.cer")
#v(0.3em)
#codeline("# Tester LDAPS")
#codeline("Test-NetConnection -ComputerName DC01 -Port 636")
#v(0.3em)
#codeline("# Vérifier le certificat racine dans AD")
#codeline("certutil -viewstore -enterprise Root")

== File Server / DFS

#codeline("# Lister les namespaces DFS")
#codeline("Get-DfsnRoot | Select-Object Path, State, Type")
#v(0.3em)
#codeline("# Lister les liens DFS")
#codeline("Get-DfsnFolder -Path '\\\\satom.local\\data\\*' | Select-Object Path, State")
#v(0.3em)
#codeline("# Vérifier les quotas FSRM")
#codeline("Get-FsrmQuota | Select-Object Path, Size, SoftLimit")

== NPS / RADIUS

#codeline("# Vérifier le service NPS")
#codeline("Get-Service IAS | Select-Object Status, StartType")
#v(0.3em)
#codeline("# Lister les clients RADIUS")
#codeline("netsh nps show client")
#v(0.3em)
#codeline("# Lister les politiques réseau")
#codeline("netsh nps show np")
#v(0.3em)
#codeline("# Vérifier l'enregistrement dans AD")
#codeline("netsh nps show registeredserver | Select-String 'Enregistr'")

== Vérification Globale

#codeline("# Lancer le script de validation complet")
#codeline("powershell -ExecutionPolicy Bypass -File C:\\Formation\\lab\\check_all.ps1")

// ============================================================
//  7. DEPANNAGE
// ============================================================
= Guide de Dépannage

== Problèmes Courants et Solutions

#figure(
  table(
    columns: (180pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 8pt,
    [*Problème*], [*Solution*],
    [CertSvc ne démarre pas (erreur 1058)],
    [Exécuter : `Set-Service CertSvc -StartupType Automatic ; Start-Service CertSvc`. Vérifier le registre `HKLM:\SYSTEM\...\CertSvc\Configuration`.],
    [Script PS refusé : caractères non-ASCII],
    [Régénérer le script avec Python en ASCII pur. Utiliser `errors='replace'` lors de l'encodage. Vérifier avec `file -i script.ps1`.],
    [LDAPS port 636 fermé],
    [Redémarrer le service LDAP : `Restart-Service NTDS`. Vérifier que le certificat DC est émis par SATOM-CA.],
    [DFS namespace inaccessible],
    [Vérifier que le service `DFS Namespace` est Running. Tester avec `dfsdiag /TestDFSIntegrity /DFSRoot:\\satom.local\data`.],
    [Client RADIUS refusé (Access-Reject)],
    [Vérifier le secret RADIUS (casse sensible). Consulter `C:\Windows\system32\LogFiles\NPS\`. Vérifier les politiques NPS (ordre de priorité).],
    [IAS ne démarre pas],
    [Vérifier que NPAS est installé : `Get-WindowsFeature NPAS`. Réinstaller si nécessaire puis `Start-Service IAS`.],
    [check_all.ps1 : score partiel],
    [Identifier le critère échoué, re-exécuter le TP concerné, relancer check_all.ps1.],
    [SSH : connexion refusée depuis host Linux],
    [Vérifier que le service `sshd` est Running sur DC01 : `Get-Service sshd`. Vérifier le pare-feu TCP/22.],
    [`netsh nps add np accesstype=` — erreur],
    [Le paramètre `accesstype` n'est pas supporté en CLI. Supprimer le paramètre. Ce comportement est un WRN non-bloquant connu.],
    [DHCP failover — erreur de partenariat],
    [Vérifier que DC02 est joignable et que le service DHCP est Running sur DC02. Supprimer le partenariat existant avant de recréer : `Remove-DhcpServerv4Failover -Name FO-DC01-DC02`.],
  ),
  caption: "Problèmes courants et leurs solutions",
)

== Journaux Utiles

#figure(
  table(
    columns: (200pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Journal / Chemin*], [*Contenu*],
    [Observateur d'événements : `System`], [Démarrages/arrêts de services, erreurs critiques],
    [Observateur : `Application`], [Erreurs d'installation de rôles, ADCS],
    [Observateur : `Directory Service`], [Réplication AD, erreurs Kerberos],
    [Observateur : `DNS Server`], [Requêtes DNS, erreurs de résolution],
    [`C:\Windows\system32\LogFiles\NPS\`], [Authentifications RADIUS (Access-Accept/Reject)],
    [`C:\Windows\debug\netsetup.log`], [Problèmes de jonction au domaine],
    [`C:\Formation\rapports\`], [Rapports AD générés par la tâche planifiée Rapport\_AD],
  ),
  caption: "Sources de journaux importantes",
)

// ============================================================
//  8. GLOSSAIRE
// ============================================================
= Glossaire Technique

#figure(
  table(
    columns: (120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Terme*], [*Définition*],
    [AD DS], [Active Directory Domain Services — annuaire LDAP de Microsoft gérant l'authentification et l'autorisation dans un domaine Windows],
    [ADCS], [Active Directory Certificate Services — PKI intégrée à AD permettant l'émission et la gestion de certificats X.509],
    [CRL], [Certificate Revocation List — liste des certificats révoqués publiée par la CA],
    [DFS-N], [Distributed File System Namespaces — espace de noms unifié masquant l'emplacement physique des partages],
    [DHCP], [Dynamic Host Configuration Protocol — protocole d'attribution automatique d'adresses IP et paramètres réseau],
    [DNS], [Domain Name System — service de résolution de noms (FQDN ↔ IP)],
    [FGPP], [Fine-Grained Password Policy — politique de mot de passe granulaire applicable à des groupes spécifiques],
    [FSRM], [File Server Resource Manager — outil de gestion des quotas et filtrage de fichiers],
    [GPO], [Group Policy Object — objet de stratégie de groupe appliqué à des OUs, sites ou domaines],
    [KVM], [Kernel-based Virtual Machine — hyperviseur de type 1 intégré au noyau Linux],
    [LAPS], [Local Administrator Password Solution — gestion automatique du MDP administrateur local],
    [LDAP], [Lightweight Directory Access Protocol — protocole d'accès à l'annuaire AD (port 389)],
    [LDAPS], [LDAP over SSL/TLS — LDAP chiffré (port 636)],
    [NPS], [Network Policy Server — rôle Windows Server implémentant un serveur RADIUS],
    [NTLMv2], [NT LAN Manager version 2 — protocole d'authentification challengé-réponse (remplace LM et NTLMv1)],
    [OU], [Organizational Unit — unité d'organisation (conteneur AD) permettant la délégation et l'application de GPO],
    [PDC], [Primary Domain Controller — DC détenant les rôles FSMO critiques],
    [PKI], [Public Key Infrastructure — infrastructure à clé publique pour la gestion des certificats],
    [RADIUS], [Remote Authentication Dial-In User Service — protocole AAA (Authentification, Autorisation, Accounting) pour équipements réseau],
    [RSA], [Rivest-Shamir-Adleman — algorithme de chiffrement asymétrique (ici 4096 bits pour SATOM-CA)],
    [SMB], [Server Message Block — protocole de partage de fichiers Windows (version 3.1.1 sur WS2025)],
    [VBS], [Virtualization-Based Security — isolation des identifiants via hyperviseur (Hyper-V)],
    [WinGet], [Windows Package Manager — gestionnaire de paquets en ligne de commande intégré à WS2025],
  ),
  caption: "Glossaire des termes techniques",
)

// ============================================================
//  9. ARCHITECTURE WINDOWS SERVER 2025 — SYNTHESE
// ============================================================
= Nouvelles Fonctionnalités Windows Server 2025

== Évolutions Clés par Domaine

#figure(
  table(
    columns: (120pt, 1fr),
    fill: (_, row) => if row == 0 { tabhead } else { white },
    stroke: 0.5pt + luma(200),
    inset: 7pt,
    [*Domaine*], [*Évolutions Windows Server 2025*],
    [Active Directory], [Base de données 32 Ko (vs 8 Ko), jusqu'à 3 milliards d'objets, nouveau niveau fonctionnel WS2025 (niveau 10), dMSA (Delegate Managed Service Accounts), amélioration DC Locator],
    [Hyper-V], [240 To RAM / VM, 2048 vCPU / VM, Génération 2 par défaut, compatibilité dynamique CPU, VBS par défaut],
    [Sécurité], [Credential Guard activé par défaut, Hotpatching via Azure Arc, OSConfig pour baselines de sécurité, SAM RPC legacy bloqué par défaut],
    [SMB], [SMB over QUIC (non réservé Azure Edition), signing obligatoire par défaut, compression LZ4, audit connexions non-signées],
    [DNS], [DNSSEC renforcé, cache 50 000 req/sec, DNS Policy géo-localisé],
    [DHCP], [Failover Load Balance 50/50 natif, télémétrie WAC intégrée, DHCPv6 complet],
    [WinGet], [Intégré par défaut, accès Microsoft Store + packages tiers],
    [LAPS], [Génération de passphrases, restauration image détectée (msLAPS-CurrentPasswordVersion), compte admin personnalisé],
    [Divers], [SSH activé par défaut, Windows Terminal intégré, compression 7z/TAR native, Network ATC pour clusters],
  ),
  caption: "Évolutions Windows Server 2025 vs 2022",
)

// ============================================================
//  ANNEXE A — STRUCTURE DU WORKSPACE GIT
// ============================================================
= Annexe A — Structure du Workspace Git

#codeline("windows server/")
#codeline("├── lab/")
#codeline("│   ├── START-Formation.ps1        # Orchestrateur principal")
#codeline("│   ├── TP_00_Init-Lab.ps1         # Bootstrap VMs")
#codeline("│   ├── TP_01_AD-DNS.ps1           # AD DS + DNS")
#codeline("│   ├── TP_02_DHCP.ps1             # DHCP + failover")
#codeline("│   ├── TP_03_OU-Users-GPO.ps1     # OUs, users, GPOs, LAPS, sites")
#codeline("│   ├── TP_04_Securite.ps1         # WinGet, perf., Hyper-V, durcissement")
#codeline("│   ├── TP_05_PKI-CA.ps1           # ADCS / SATOM-CA / LDAPS")
#codeline("│   ├── TP_06_FileServer-DFS-FSRM.ps1  # File Server DFS FSRM")
#codeline("│   └── TP_07_NPS-RADIUS.ps1       # NPS RADIUS")
#codeline("├── tools/")
#codeline("│   └── check_all.ps1              # Validation globale de tous les modules")
#codeline("└── docs/")
#codeline("    ├── README.md                  # Guide de déploiement")
#codeline("    ├── formation_ws2025.md        # Contenu pédagogique des modules")
#codeline("    └── lab-satom.typ              # Ce document (documentation Typst)")

// ============================================================
//  ANNEXE B — REFERENCES
// ============================================================
= Annexe B — Références

- Documentation officielle Windows Server 2025 : #link("https://learn.microsoft.com/fr-fr/windows-server/")
- Nouveautés Windows Server 2025 : #link("https://learn.microsoft.com/fr-fr/windows-server/get-started/whats-new-windows-server-2025")
- Active Directory Certificate Services : #link("https://learn.microsoft.com/fr-fr/windows-server/identity/ad-cs/active-directory-certificate-services-overview")
- Windows LAPS : #link("https://learn.microsoft.com/fr-fr/windows-server/identity/laps/laps-scenarios-windows-server-active-directory")
- DFS Namespaces : #link("https://learn.microsoft.com/fr-fr/windows-server/storage/dfs-namespaces/dfs-overview")
- Network Policy Server : #link("https://learn.microsoft.com/fr-fr/windows-server/networking/technologies/nps/nps-top")
- FSRM File Server Resource Manager : #link("https://learn.microsoft.com/fr-fr/windows-server/storage/fsrm/fsrm-overview")
- OSConfig Security Baselines : #link("https://learn.microsoft.com/fr-fr/windows-server/security/osconfig/osconfig-how-to-configure-security-baselines")
- Typst Documentation : #link("https://typst.app/docs/")
