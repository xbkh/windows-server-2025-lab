# Comment fonctionne l'infrastructure du lab

> Document de référence — **satom.local** sur Windows Server 2025  
> Explique chaque composant, son rôle, ses termes clés et comment les blocs s'articulent entre eux.

---

## Sommaire

1. [Vue d'ensemble](#1-vue-densemble)
2. [La virtualisation — KVM](#2-la-virtualisation--kvm)
3. [Active Directory Domain Services (AD DS)](#3-active-directory-domain-services-ad-ds)
4. [DNS](#4-dns)
5. [DHCP et DHCP Failover](#5-dhcp-et-dhcp-failover)
6. [Objets de stratégie de groupe (GPO)](#6-objets-de-stratégie-de-groupe-gpo)
7. [LAPS — Local Administrator Password Solution](#7-laps--local-administrator-password-solution)
8. [PKI — Infrastructure à clés publiques](#8-pki--infrastructure-à-clés-publiques)
9. [Sites AD et réplication](#9-sites-ad-et-réplication)
10. [Sécurité AD — PSO, durcissement, protocoles](#10-sécurité-ad--pso-durcissement-protocoles)
11. [Hyper-V](#11-hyper-v)
12. [Services fichiers — SMB, DFS, FSRM](#12-services-fichiers--smb-dfs-fsrm)
13. [NPS / RADIUS](#13-nps--radius)
14. [Azure Arc](#14-azure-arc)
15. [Comment tout s'articule](#15-comment-tout-sarticule)
16. [Glossaire](#16-glossaire)

---

## 1. Vue d'ensemble

L'infrastructure est composée de **3 machines virtuelles** sur un hôte Linux (Pop OS) via KVM.

```
Réseau interne : 192.168.122.0/24
┌─────────────────────────────────────────────────────────┐
│  Hôte Linux (Pop OS)                                    │
│                                                         │
│   ┌──────────────┐   ┌──────────────┐   ┌───────────┐  │
│   │    DC01      │   │    DC02      │   │   PC01    │  │
│   │ .122.10      │   │ .122.20      │   │ .122.50   │  │
│   │ PDC, DNS     │   │ DC secondaire│   │ Client    │  │
│   │ DHCP, CA     │   │ DHCP failover│   │ domaine   │  │
│   │ NPS, Hyper-V │   │              │   │           │  │
│   └──────────────┘   └──────────────┘   └───────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Domaine :** `satom.local`  
**Tous les rôles tournent sur Windows Server 2025.**

---

## 2. La virtualisation — KVM

### Qu'est-ce que KVM ?

**KVM** (Kernel-based Virtual Machine) est l'hyperviseur intégré au noyau Linux. Il permet de créer des machines virtuelles directement sur un hôte Linux, comme VMware ou VirtualBox mais natif au système.

**Hyperviseur** : logiciel qui crée et gère des VMs en partageant les ressources physiques (CPU, RAM, disque, réseau) entre plusieurs systèmes invités.

### La couche réseau virtuelle

KVM crée un **réseau NAT virtuel** (par défaut `192.168.122.0/24`) via `virbr0` (virtual bridge). Les VMs communiquent entre elles via ce bridge comme si elles étaient branchées sur le même switch réseau physique.

- Les VMs voient la plage `192.168.122.x` comme leur réseau local
- L'hôte Linux peut également y accéder (il a l'IP `192.168.122.1`)
- Depuis l'hôte : `ssh Administrateur@192.168.122.10` atteint DC01

---

## 3. Active Directory Domain Services (AD DS)

### Concept de base

**Active Directory** est le service d'annuaire de Microsoft. C'est la colonne vertébrale de toute infrastructure Windows d'entreprise. Il centralise :

- l'**authentification** (qui a le droit de se connecter ?)
- l'**autorisation** (qu'est-ce que cet utilisateur a le droit de faire ?)
- la **gestion des objets** (utilisateurs, ordinateurs, groupes, GPO...)

### Domaine, forêt, arbre

| Terme | Définition |
|-------|-----------|
| **Domaine** | Unité d'administration de base. Ici : `satom.local`. Tous les objets (users, PCs) appartiennent à ce domaine. |
| **Arbre** | Ensemble de domaines partageant un espace de noms contigu (`satom.local`, `rh.satom.local`...). |
| **Forêt** | Ensemble d'arbres partageant un schéma commun. C'est la limite de sécurité ultime dans AD. |

Dans ce lab : **un seul domaine** = un seul arbre = une seule forêt.

### Contrôleurs de domaine (DC)

Un **contrôleur de domaine (DC)** est un serveur Windows qui héberge AD DS et maintient une copie de la base de données Active Directory (fichier `NTDS.dit`).

- **DC01** : le premier DC promu, il est **PDC Emulator** (voir FSMO ci-dessous)
- **DC02** : DC secondaire, synchronise sa base avec DC01

### Réplication AD

Toute modification faite sur DC01 (création d'un user, changement de mot de passe) est **répliquée automatiquement sur DC02**. Les deux DCs ont toujours (presque) la même base.

### FSMO — Flexible Single Master Operations

Certaines opérations AD ne peuvent pas être faites en parallèle sur plusieurs DCs (risque de conflit). Elles sont confiées à un seul DC appelé **maître d'opérations (FSMO)**.

Il existe 5 rôles FSMO :

| Rôle | Portée | Rôle dans le lab |
|------|--------|-----------------|
| **Schema Master** | Forêt | DC01 |
| **Domain Naming Master** | Forêt | DC01 |
| **PDC Emulator** | Domaine | DC01 — synchronisation des mots de passe, heure, verrouillages |
| **RID Master** | Domaine | DC01 — attribue des blocs de SIDs aux DCs |
| **Infrastructure Master** | Domaine | DC01 |

### Unités d'Organisation (OU)

Les **OU (Organizational Units)** sont des conteneurs dans AD qui permettent de regrouper les objets et d'y appliquer des GPO.

Structure dans le lab :
```
DC=satom,DC=local
├── OU=_SATOM
│   ├── OU=Serveurs       ← DC01, DC02, PC01 (machines)
│   └── OU=Paris          ← PC01 (applique les GPOs LAPS etc.)
└── CN=Users              ← utilisateurs par défaut AD
```

### SID — Security Identifier

Chaque objet AD (user, groupe, ordinateur) possède un **SID unique** (ex: `S-1-5-21-123456789-1001`). Windows utilise le SID, pas le nom, pour les ACL et permissions.

---

## 4. DNS

### Pourquoi DNS est indispensable dans AD ?

Active Directory **dépend entièrement de DNS**. Sans DNS fonctionnel, les machines ne peuvent pas trouver les DCs, et l'authentification Kerberos ne fonctionne pas. AD utilise DNS pour localiser les services via les **SRV records**.

### Zones DNS dans le lab

| Zone | Type | Contenu |
|------|------|---------|
| `satom.local` | Principale intégrée AD | Tous les enregistrements du domaine |
| `122.168.192.in-addr.arpa` | Reverse lookup | IP → nom de machine |

### Types d'enregistrements clés

| Type | Description | Exemple |
|------|-------------|---------|
| **A** | Nom → IPv4 | `DC01.satom.local` → `192.168.122.10` |
| **PTR** | IPv4 → Nom (reverse) | `192.168.122.10` → `DC01.satom.local` |
| **SRV** | Localisation de service | `_ldap._tcp.satom.local` → DC01 port 389 |
| **NS** | Serveur de noms de la zone | `satom.local` → `DC01.satom.local` |
| **SOA** | Paramètres d'autorité de la zone | Serial, TTL, responsable |

### DNS intégré AD

La zone `satom.local` est **stockée directement dans AD** (pas dans un fichier texte). Avantages :
- réplication automatique entre DCs via la réplication AD
- sécurité renforcée (authentification requise pour modifier)
- mises à jour dynamiques sécurisées (les machines enregistrent leur IP automatiquement)

---

## 5. DHCP et DHCP Failover

### Qu'est-ce que DHCP ?

**DHCP** (Dynamic Host Configuration Protocol) attribue automatiquement une configuration réseau aux machines qui se connectent :
- adresse IP
- masque de sous-réseau
- passerelle
- serveurs DNS

Sans DHCP, il faudrait configurer chaque machine manuellement.

### Scope DHCP dans le lab

| Paramètre | Valeur |
|-----------|--------|
| Nom | `LAN-Satom` |
| Plage | `192.168.122.100` à `192.168.122.199` |
| Masque | `255.255.255.0` |
| Passerelle | `192.168.122.1` |
| DNS | `192.168.122.10` (DC01) |
| Durée du bail | 8 jours |

**PC01** reçoit son IP `192.168.122.50` via ce scope (bail réservé ou dynamique actif).

### DHCP Failover — haute disponibilité sans cluster

Le **DHCP Failover** (depuis Windows Server 2012 R2) permet à deux serveurs DHCP de partager un scope et de se synchroniser automatiquement. Si l'un tombe, l'autre continue d'attribuer des IPs.

**Mode LoadBalance** (configuré dans le lab) :
- DC01 et DC02 répondent tous les deux aux requêtes DHCP
- Par défaut : 50% des requêtes chaque
- Si un DC tombe : l'autre prend 100% automatiquement

```
Relation de failover : FO-DC01-DC02
Mode               : LoadBalance
État               : Normal
Partenaire actif   : DC01 ↔ DC02
```

**Différence avec un cluster DHCP** : Le failover DHCP est plus simple (pas de stockage partagé, pas d'IP virtuelle, pas de Failover Clustering requis). Recommandé pour la majorité des cas.

---

## 6. Objets de stratégie de groupe (GPO)

### Concept

Les **GPO (Group Policy Objects)** sont des configurations qui s'appliquent automatiquement aux utilisateurs et aux ordinateurs du domaine. On les créé une fois, et tous les objets ciblés les reçoivent.

Sans GPO : il faudrait configurer chaque poste manuellement.

### Comment une GPO s'applique ?

1. La GPO est créée dans **GPMC** (Group Policy Management Console)
2. Elle est **liée** à une OU, un site ou le domaine entier
3. Quand un ordinateur (ou utilisateur) est dans cette OU, il **télécharge et applique** la GPO
4. L'application se fait au **démarrage** (ordinateurs) ou à l'**ouverture de session** (utilisateurs)
5. Elle est ensuite rafraîchie toutes les **90 minutes** (± 30 min aléatoire)

### Ordre d'application — LSDOU

Les GPO s'appliquent dans cet ordre (la dernière écrase les précédentes) :
```
L → Local (GPO locale de la machine)
S → Site
D → Domaine
O → OU (de la plus haute à la plus proche de l'objet)
```

### Les 10 GPOs du lab

| Nom de la GPO | Rôle |
|---------------|------|
| Default Domain Policy | Politique MDP minimale du domaine (longueur, complexité) |
| Default Domain Controllers Policy | Droits sur les DCs |
| GPO-LAPS-Configuration | Configure LAPS sur les postes (délai, complexité, sauvegarde AD) |
| GPO-Security-Hardening | Durcissement : LmCompat, WDigest, SMB |
| GPO-Software-Deployment | Déploiement logiciels (WinGet, VSCode...) |
| GPO-Monitoring-Tasks | Tâches planifiées de surveillance |
| GPO-Power-Plan | Plan d'alimentation Hautes Performances |
| GPO-FileServer-DriveMaps | Lecteurs réseau mappés pour les utilisateurs |
| GPO-NPS-Firewall | Règles pare-feu pour NPS/RADIUS |
| GPO-PKI-AutoEnroll | Auto-enrôlement certificats PKI |

### Héritage et blocage

- Par défaut, les OUs héritent des GPO des OUs parentes
- On peut **bloquer l'héritage** sur une OU
- On peut **forcer** (Enforced) une GPO pour qu'elle ne soit pas écrasée

**PC01** est dans `OU=Paris,OU=_SATOM` — il hérite des GPO liées à `_SATOM` ET à `Paris`.

### Registry.pol

Chaque GPO génère un fichier `Registry.pol` stocké dans le **SYSVOL** (dossier partagé sur tous les DCs). C'est ce fichier que les machines lisent pour connaître les paramètres à appliquer.

---

## 7. LAPS — Local Administrator Password Solution

### Problème résolu

Dans la plupart des environnements, tous les postes Windows ont le même mot de passe administrateur local. Si un attaquant le découvre sur un PC, il peut se connecter à **tous** les postes du domaine. C'est le **mouvement latéral**.

### Solution LAPS

**LAPS** génère automatiquement un mot de passe aléatoire et complexe pour le compte administrateur local de chaque poste, et le stocke dans AD (dans un attribut de l'objet ordinateur).

- Chaque poste a **son propre mot de passe unique**
- Le mot de passe **expire automatiquement** et est renouvelé
- Seuls les admins autorisés peuvent **lire le mot de passe** dans AD

### Comment ça fonctionne

```
PC01 démarre
    ↓
Extension LAPS vérifie l'expiration du mot de passe
    ↓
Si expiré → génère un nouveau mot de passe aléatoire
    ↓
Change le mot de passe du compte local "admin"
    ↓
Stocke le nouveau mot de passe dans AD (attribut ms-Mcs-AdmPwd)
    ↓
Met à jour la date d'expiration dans AD
```

Pour récupérer le mot de passe depuis DC01 :
```powershell
Get-LapsADPassword -Identity PC01 -AsPlainText
```

### Configuration via GPO (GPO-LAPS-Configuration)

| Paramètre | Valeur | Signification |
|-----------|--------|---------------|
| BackupDirectory | 1 | Stockage dans AD (pas Azure) |
| PasswordAgeDays | 30 | Renouvellement tous les 30 jours |
| PasswordLength | 14 | 14 caractères minimum |
| PasswordComplexity | 4 | Maj + min + chiffres + symboles |
| PostAuthenticationResetDelay | 24 | Après usage admin : reset dans 24h |

### Clé de registre exacte

```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS
```

---

## 8. PKI — Infrastructure à clés publiques

### Cryptographie asymétrique — la base

La PKI repose sur la **cryptographie asymétrique** : chaque entité possède deux clés mathématiquement liées :
- **Clé privée** : secrète, jamais partagée
- **Clé publique** : distribuée librement via un **certificat**

Ce qui est chiffré avec la clé publique ne peut être déchiffré qu'avec la clé privée, et vice versa.

### Qu'est-ce qu'un certificat ?

Un **certificat numérique** (X.509) est un document électronique qui contient :
- la clé publique d'une entité
- son identité (nom, domaine...)
- la signature d'une **Autorité de Certification (CA)** qui garantit l'authenticité

### AD CS — Active Directory Certificate Services

**ADCS** est le rôle Windows qui implémente une PKI interne. Dans le lab, DC01 est la **CA racine** du domaine `satom.local`.

```
CA Racine : satom-DC01-CA
    ↓ émet des certificats pour :
    ├── DC01.satom.local (LDAPS + authentification)
    ├── DC02.satom.local
    └── PC01.satom.local
```

### LDAPS — LDAP sécurisé

**LDAP** (Lightweight Directory Access Protocol) est le protocole utilisé pour interroger Active Directory. Par défaut, les échanges LDAP sont **en clair** sur le port 389.

**LDAPS** = LDAP sur TLS, port **636**. Les échanges sont chiffrés. Nécessite un certificat sur le DC.

Après déploiement de la PKI, DC01 possède un certificat et écoute sur le port 636 — les requêtes LDAP peuvent être sécurisées.

### Auto-enrôlement

L'**auto-enrôlement** permet aux machines et utilisateurs du domaine de recevoir automatiquement leurs certificats via une GPO (`GPO-PKI-AutoEnroll`), sans intervention manuelle. Les certificats sont renouvelés automatiquement avant expiration.

---

## 9. Sites AD et réplication

### Qu'est-ce qu'un site AD ?

Un **site Active Directory** représente un **emplacement physique** ou une subdivision réseau (un bâtiment, un bureau distant, un data center). Il est défini par un ou plusieurs sous-réseaux IP.

### Sites dans le lab

| Site | Sous-réseau | Usage |
|------|------------|-------|
| Site-Paris | 192.168.122.0/24 | Réseau principal (DC01, DC02, PC01) |
| Site-Bordeaux | 10.10.2.0/24 | Site distant simulé |
| DefaultFirstSiteName | (ancien défaut) | Site par défaut initial |

### Liens de sites et réplication

Les sites sont reliés par des **liens de sites (site links)** qui définissent :
- la **fréquence de réplication** (toutes les N minutes)
- le **coût** (pour prioriser les liaisons rapides)

La réplication AD entre DC01 et DC02 est ainsi contrôlée et planifiable — utile en WAN pour ne pas saturer les liaisons lentes.

### KCC — Knowledge Consistency Checker

Le **KCC** est un processus automatique qui calcule la **topologie de réplication optimale** entre DCs — quels DCs se répliquent avec qui, dans quel ordre. Il crée et maintient les **objets de connexion** AD automatiquement.

---

## 10. Sécurité AD — PSO, durcissement, protocoles

### PSO — Password Settings Objects

Les **PSO** (introduits dans Windows Server 2008) permettent d'appliquer des politiques de mot de passe **différenciées** selon les groupes ou utilisateurs.

Problème sans PSO : la Default Domain Policy applique une seule politique MDP à tous. Un compte admin devrait avoir des règles plus strictes qu'un utilisateur standard.

**PSO-Admins** dans le lab :

| Paramètre | Valeur |
|-----------|--------|
| Longueur minimale | 16 caractères |
| Âge maximum | 30 jours |
| Seuil de verrouillage | 3 tentatives |
| Durée de verrouillage | 5 minutes |
| Priorité | 10 (plus bas = prioritaire) |

Appliqué au groupe **Domain Admins** → les admins ont une politique plus stricte que les users.

### LmCompatibilityLevel

Contrôle le protocole d'authentification réseau utilisé :

| Valeur | Protocole | Sécurité |
|--------|-----------|---------|
| 0 | LM + NTLM | ❌ Très faible |
| 3 | NTLMv2 seulement | Moyen |
| **5** | **NTLMv2 obligatoire, refuse LM et NTLM** | ✅ Recommandé |

Dans le lab : `LmCompatibilityLevel = 5` — les authentifications LM et NTLM anciennes sont refusées.

Clé registre : `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LmCompatibilityLevel`

### WDigest

**WDigest** est un ancien protocole d'authentification qui stocke les mots de passe **en clair** en mémoire (dans le processus LSASS). Des outils comme Mimikatz exploitent cela pour voler des mots de passe.

Dans le lab : `WDigest = 0` — stockage en clair désactivé.

Clé registre : `HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential`

### Kerberos vs NTLM

| Protocole | Utilisation | Sécurité |
|-----------|-------------|---------|
| **Kerberos** | Authentification principale dans AD (tickets TGT/TGS) | ✅ Fort, pas de mot de passe sur le réseau |
| **NTLMv2** | Fallback si Kerberos impossible (ex: IP directe) | Moyen, vulnérable au relay |
| LM/NTLM | Anciens protocoles | ❌ Désactivés dans le lab |

### SMB Security

**SMB** (Server Message Block) est le protocole de partage de fichiers Windows.

| Paramètre | Valeur | Effet |
|-----------|--------|-------|
| SMBv1 | Désactivé | Supprime le protocole vulnérable (WannaCry exploitait SMBv1) |
| Signing | Activé | Chaque paquet SMB est signé — protège contre les attaques MITM |
| Encryption | Activé | Données chiffrées en transit |

---

## 11. Hyper-V

### Qu'est-ce que Hyper-V ?

**Hyper-V** est l'hyperviseur natif de Microsoft, disponible dans Windows Server. Il permet de créer des **machines virtuelles** directement sur Windows Server, tout comme KVM sur Linux.

Dans le lab, Hyper-V est installé sur **DC01** pour simuler un environnement de production complet.

### Configuration dans le lab

| Élément | Valeur |
|---------|--------|
| Service | `vmms` (Virtual Machine Management Service) — Running |
| vSwitches | 2 switches virtuels créés |
| VM démo | `VM-Demo-WS2025` — Génération 2, état Off |

### Génération 1 vs Génération 2

| Gen | BIOS | Secure Boot | Performance |
|-----|------|------------|-------------|
| Gen 1 | BIOS legacy | Non | Moins bonne |
| **Gen 2** | **UEFI** | **Oui** | **Meilleure — recommandée** |

### vSwitch — Switch virtuel

Un **vSwitch** est un switch réseau entièrement logiciel qui connecte les VMs entre elles et/ou à l'extérieur. Il fonctionne comme un switch physique mais dans la mémoire du serveur.

Types :
- **External** : les VMs communiquent avec le réseau physique
- **Internal** : les VMs communiquent entre elles + avec l'hôte
- **Private** : les VMs communiquent uniquement entre elles

---

## 12. Services fichiers — SMB, DFS, FSRM

### Partages SMB

Un **partage SMB** expose un dossier du serveur sur le réseau. Les utilisateurs y accèdent via `\\DC01\NomDuPartage`.

Les accès sont contrôlés par :
- les **permissions de partage** (niveau réseau)
- les **ACL NTFS** (niveau fichier — plus précises, toujours appliquées)

En cas de conflit : la règle la **plus restrictive** des deux s'applique.

### DFS — Distributed File System

**DFS Namespace** crée un espace de noms unifié pour les partages fichiers distribués.

Sans DFS :
```
\\DC01\Données-Paris
\\DC02\Données-Bordeaux
\\FILESERVER\Archives
```

Avec DFS :
```
\\satom.local\Partages
    ├── \Données      → pointe vers \\DC01\Données
    ├── \Archives     → pointe vers \\DC02\Archives
    └── \Commun       → pointe vers \\DC01\Commun
```

L'utilisateur n'a qu'un seul point d'entrée. Si le serveur cible change, on modifie le DFS sans toucher aux utilisateurs.

### FSRM — File Server Resource Manager

**FSRM** permet de contrôler et surveiller l'utilisation du stockage :

| Fonctionnalité | Description |
|---------------|-------------|
| **Quotas** | Limite la taille d'un dossier par utilisateur ou globalement |
| **File Screening** | Bloque certains types de fichiers (`.mp3`, `.exe`, `.avi`...) |
| **Rapports** | Génère des rapports sur l'utilisation du disque |
| **Notifications** | Alerte par email quand le quota est presque atteint |

Exemple dans le lab : quota de 500 MB sur les dossiers home, blocage des fichiers audio/vidéo.

### Lecteurs réseau mappés via GPO

La GPO `GPO-FileServer-DriveMaps` connecte automatiquement les lecteurs réseau à l'ouverture de session :

```
H: → \\DC01\Users\%username%  (dossier personnel)
S: → \\satom.local\Partages\Commun
```

---

## 13. NPS / RADIUS

### Qu'est-ce que RADIUS ?

**RADIUS** (Remote Authentication Dial-In User Service) est un protocole qui centralise l'authentification, l'autorisation et la comptabilité (AAA) pour les accès réseau :
- VPN
- WiFi d'entreprise (802.1X)
- commutateurs réseau
- accès distants

Au lieu que chaque équipement réseau gère ses propres utilisateurs, ils délèguent tous à un **serveur RADIUS central**.

### NPS — Network Policy Server

**NPS** est l'implémentation Microsoft du serveur RADIUS. Dans le lab, NPS tourne sur **DC01**.

### Flux d'authentification

```
Client (PC01) veut accéder au réseau
    ↓
Switch réseau / Point d'accès WiFi demande l'identité
    ↓
Envoie les credentials au serveur RADIUS (DC01 port 1812)
    ↓
NPS vérifie dans Active Directory
    ↓
NPS retourne : Access-Accept ou Access-Reject
    ↓
Le switch autorise ou refuse la connexion
```

### Network Policies dans le lab

Les **Network Policies NPS** définissent les conditions d'accès :
- Membres du groupe `Domain Computers` → autorisation
- Authentification NTLMv2 requise
- Logs d'accounting activés (port 1813)

---

## 14. Azure Arc

### Qu'est-ce qu'Azure Arc ?

**Azure Arc** est un service Microsoft qui permet de **gérer des serveurs on-premises** (hors cloud) depuis le portail Azure. Un serveur physique ou VM peut être inscrit dans Azure Arc et bénéficier de :
- Azure Monitor (métriques, alertes)
- Azure Policy (conformité)
- Azure Automation
- Defender for Cloud

### Agent en charge

L'agent **Azure Connected Machine Agent** (`azcmagent`) s'installe sur le serveur et maintient la connexion vers Azure. Il est géré via une **Service Principal** (identité applicative Azure AD).

### État dans le lab

Azure Arc était prévu pour DC01 mais n'a pas pu être finalisé : la **subscription Azure était inactive** au moment de l'exécution. Les scripts sont présents dans `azure-arc/` pour être rejoués.

---

## 15. Comment tout s'articule

Voici le flux complet depuis le démarrage d'un PC jusqu'à l'accès à un fichier partagé :

```
1. PC01 démarre
        ↓
2. DHCP Failover (DC01 ou DC02) attribue une IP via le scope LAN-Satom
        ↓
3. PC01 résout DC01.satom.local via DNS → 192.168.122.10
        ↓
4. PC01 contacte DC01 (port LDAP 389 ou LDAPS 636)
        ↓
5. Kerberos : PC01 obtient un TGT auprès du KDC (DC01)
        ↓
6. GPO téléchargées depuis SYSVOL sur DC01 (\\satom.local\SYSVOL)
   → GPO-LAPS applique la politique mot de passe local
   → GPO-Security-Hardening applique WDigest=0, SMB Signing...
   → GPO-FileServer-DriveMaps connecte H: et S:
        ↓
7. L'utilisateur ouvre une session, obtient son TGS pour \\DC01\Partages
        ↓
8. Accès SMB (chiffré, signé) → DFS redirige vers le bon serveur
        ↓
9. FSRM vérifie le quota et le type de fichier avant écriture
        ↓
10. PKI : si LDAPS requis, le certificat de DC01 est validé
           (émis par satom-DC01-CA, distribué par auto-enrôlement)
```

---

## 16. Glossaire

| Terme | Définition |
|-------|-----------|
| **ACL** | Access Control List — liste des permissions sur un objet |
| **AD CS** | Active Directory Certificate Services — PKI Microsoft |
| **AD DS** | Active Directory Domain Services — service d'annuaire |
| **ADML** | Administrative Template Language — fichiers de langue pour ADMX |
| **ADMX** | Administrative Template XML — modèles de GPO |
| **CA** | Certificate Authority — Autorité de Certification |
| **DC** | Domain Controller — contrôleur de domaine |
| **DHCP** | Dynamic Host Configuration Protocol — attribution IP automatique |
| **DFS** | Distributed File System — espace de noms fichier unifié |
| **DNS** | Domain Name System — résolution nom → IP |
| **FSMO** | Flexible Single Master Operations — rôles AD uniques par DC |
| **FSRM** | File Server Resource Manager — gestion quotas et filtrage fichiers |
| **GPO** | Group Policy Object — objet de stratégie de groupe |
| **GPMC** | Group Policy Management Console — console de gestion des GPO |
| **KCC** | Knowledge Consistency Checker — calcule la topologie de réplication |
| **KDC** | Key Distribution Center — service Kerberos sur le DC |
| **KVM** | Kernel-based Virtual Machine — hyperviseur Linux |
| **LAPS** | Local Administrator Password Solution — gestion MDP admin local |
| **LDAP** | Lightweight Directory Access Protocol — protocole d'interrogation AD |
| **LDAPS** | LDAP over TLS — LDAP chiffré port 636 |
| **LM** | LAN Manager — ancien protocole d'auth, désactivé |
| **MTU** | Maximum Transmission Unit — taille max d'un paquet réseau |
| **NTDS.dit** | Fichier base de données AD (sur chaque DC) |
| **NTLM** | NT LAN Manager — protocole d'auth Windows |
| **NPS** | Network Policy Server — serveur RADIUS Microsoft |
| **OU** | Organizational Unit — unité d'organisation dans AD |
| **PDC** | Primary Domain Controller — DC portant le rôle PDC Emulator |
| **PKI** | Public Key Infrastructure — infrastructure de gestion des certificats |
| **PSO** | Password Settings Object — politique MDP granulaire |
| **RADIUS** | Remote Authentication Dial-In User Service — auth centralisée réseau |
| **RID** | Relative Identifier — partie variable du SID |
| **SID** | Security Identifier — identifiant unique de chaque objet AD |
| **SMB** | Server Message Block — protocole de partage fichiers Windows |
| **SRV** | Service Record DNS — localise les services sur le réseau |
| **SYSVOL** | Dossier partagé sur tous les DCs — contient GPO et scripts |
| **TGS** | Ticket Granting Service — ticket Kerberos pour un service précis |
| **TGT** | Ticket Granting Ticket — ticket Kerberos maître (session) |
| **TLS** | Transport Layer Security — chiffrement des communications |
| **UPN** | User Principal Name — format `user@domaine.local` |
| **WDigest** | Ancien protocole stockant les MDP en clair — désactivé dans le lab |
| **X.509** | Format standard des certificats numériques |

---

*Document généré le 26 mars 2026 — Infrastructure satom.local, Windows Server 2025*
