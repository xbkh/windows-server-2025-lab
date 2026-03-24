# 🧠 FORMATION WINDOWS SERVER 2025 – ADMINISTRATION SYSTÈME (VERSION PRO)
![image](https://hackmd.io/_uploads/HkUEXupcZg.png)

---
# 📘 Plan de Formation Complet : Windows Server 2025 & Active Directory

Ce plan est conçu pour être utilisé avec votre environnement de laboratoire (VM1: DC1, VM2: DC2, VM3: PC01). Chaque module alterne entre théorie, pratique de laboratoire et validation des connaissances.

---

# ✅ État actuel du dépôt et livrables du lab

Le dépôt contient désormais :

- les scripts de TP dans `lab/`
- les scripts de validation et correctifs dans `scripts/`
- les scripts Azure Arc dans `azure-arc/`
- la documentation dans `docs/`
- les captures finales dans `screenshots/`

## Validation finale du lab

La validation finale exécutée avec `check_all.ps1` confirme notamment :

- DHCP failover opérationnel en mode `LoadBalance`
- Active Directory, OUs, utilisateurs et GPOs présents
- LAPS fonctionnel sur `PC01`
- PKI/LDAPS opérationnels
- SMB durci (`SMBv1=False`, signature et chiffrement actifs)
- paramètres sécurité conformes (`LmCompatibilityLevel=5`, `WDigest=0`)
- PSO admins appliquée
- Hyper-V actif avec vSwitch internes et externes
- NPS/RADIUS fonctionnel

## Captures d'écran du rendu final

44 captures d'écran finales sont stockées dans `screenshots/`, de `01_AD-Domain-Controllers.png` à `44_Check-All-Script.png`.

Les captures couvrent notamment :

- AD DS, DNS, DHCP
- OUs, utilisateurs, groupes, GPO
- LAPS, PSO, PKI, LDAPS
- DFS, FSRM, partages SMB
- NPS / RADIUS
- validation finale du lab

# Module 00 : LAB - Environnement de laboratoire virtuel

# Module 01 : Introduction system d'exploitation et fonctionalitées

# Module 02 : Déploiement d'Active Directory Domain Services

# Module 03 : Infrastructure DNS et résolution de noms et DHCP

# Module 04 : Gestion des utilisateurs, groupes et Unités d'Organisation

# Module 05 : Stratégies de groupe (GPO) et gestion centralisée

# Module 06 : Sécurité de base et authentification

# Module 07 : Gestion des mots de passe et LAPS

# Module 08 : Haute disponibilité et sites Active Directory

# Module 09 : Stratégie de migration vers Windows Server 2025

# Module 10 : Windows Admin Center et gestion moderne

# Module 11 : Automatisation avec PowerShell et Winget

# Module 12 : Performances et optimisations matérielles

# Module 13 : Disponibilité et maintenance

# Module 14 : Sécurité avancée et durcissement

# Module 15 : Installation et configuration de l'infrastructure de virtualisation

# Module 16 : Cloud hybride avec Azure Arc et synthèse finale

---


# Module 00 : LAB - Environnement de laboratoire virtuel

![image](https://hackmd.io/_uploads/HJVLoc69Wx.png)




## 1. Objectifs du module
- Construire une infrastructure de laboratoire isolée pour Windows Server 2025.
- Maîtriser la configuration réseau (Host-Only/NAT) pour un domaine Active Directory.
- Préparer les machines virtuelles (DC, Clients) selon les bonnes pratiques Microsoft.

## 2. Architecture recommandée
Basé sur les guides de labo communautaires et Microsoft, voici l’architecture cible :

| Élément | Configuration | Notes |
| :--- | :--- | :--- |
| **Hyperviseur** | VMware Workstation Pro 17 / VirtualBox 7 | Support de la virtualisation imbriquée nécessaire  |
| **DC1 (Domain Controller)** | Windows Server 2025 Standard | 2 vCPU, 4 Go RAM, 40 Go HDD  |
| **VM2 (Client)** | Windows 11 Entreprise / 10 | 2 vCPU, 4 Go RAM, 64 Go HDD  |
| **Réseau Interne** | Host-Only (VMware) / Internal (VirtualBox) | Isolation totale du réseau physique. Adressage statique pour le DC  |
| **Réseau WAN** | NAT (via hyperviseur) | Optionnel. Permet aux VMs d'accéder à Internet (téléchargement, Azure)  |

## 3. Ressources nécessaires
- **Logiciels :**
    - Hyperviseur : [VMware Workstation Pro](https://satomitlearning.sharepoint.com/:u:/s/Formateurs-CHE2Cours/IQDCGOSdOGDWRb2_sqkjet90AXHPyBiYjN5fOPO_tnD687A?e=8ORw9Y) / [Oracle VirtualBox](https://www.virtualbox.org/wiki/Downloads).
    - [Windows Server 2025 Eval](https://www.microsoft.com/en-US/evalcenter/evaluate-windows-server-2025)
    - ISO :[ Windows Server 2025 (Evaluation Center)](https://www.microsoft.com/fr-fr/evalcenter/evaluate-windows-server-2025).
     - ISO :[ Windows 11](https://satomitlearning.sharepoint.com/:u:/s/Formateurs-CHE2Cours/IQBNpcXUofiPQ55rshdfMFMuAbTPMci9oUYf-xoRQXL6ejw?e=idQr9p).
    - ISO :[ Windows 10](https://satomitlearning.sharepoint.com/:u:/s/Formateurs-CHE2Cours/IQB52wg9_-Y3SpHm89nfStTJAYTxH--uIIo0mX4soiA6Xr8?e=aplbtX).
    - [Key Windows ](https://satomitlearning.sharepoint.com/:t:/s/Formateurs-CHE2Cours/IQDAvZFg5J8HSKLaRugkG7rzAahIadp7DeXsxJBJukGCmaE?e=KtbdgK)
- **Matériel (Host) :**
    - RAM : 16 Go (32 Go recommandé pour des performances optimales).
    - Stockage : 100 Go SSD (150 Go recommandé pour les snapshots) .

## 4. Procédure d'installation détaillée

### 4.1. Installation du premier contrôleur de domaine (DC1)
1.  **Création de la VM :**
    - Type : Microsoft Windows.
    - Version : [Windows Server 2025].
    - Stockage : 40 Go (éclater en plusieurs fichiers).
2.  **Configuration matérielle (avant installation) :**
    - Mémoire : 2048 Mo (minimum) à 4096 Mo (recommandé) .
    - Processeur : 2 cœurs.
    - Réseau : **Host-Only** (Isolation).
3.  **Installation OS :**
    - Monter l'ISO et démarrer.
    - Choisir "Windows Server 2025 Standard (Desktop Experience)" .
    - Installer sur l'espace non alloué.
4.  **Post-Installation :**
    - **IP Fixe** : 192.168.100.10/24 (DNS : 127.0.0.1) .
    - **Nom du serveur** : Renommer en `DC01` (ou `SRV-DC01`).

### 4.2. Installation du client (PC1 / Client)
1.  **Création :** Similaire au DC, mais avec Windows 11.
2.  **Réseau :** Même réseau Host-Only que le DC.
3.  **Post-Installation :**
    - IP automatique (DHCP) ou statique dans la même plage (ex: 192.168.100.50/24).
    - DNS pointer vers l'IP du DC (`192.168.100.10`).

## 5. Validation du Lab
| Test | Commande | Résultat attendu |
| :--- | :--- | :--- |
| Connectivité DC1 ↔ DC2 | `ping 192.168.10.10` depuis DC1 | Réponse |
| Connectivité DC1 ↔ PC1 | `ping 192.168.10.20` depuis DC1 | Réponse |
| Connectivité PC1 ↔ DC1 | `ping 192.168.10.30` depuis PC1 | Réponse |
| Résolution DNS temporaire | `nslookup dc01 192.168.10.10` depuis PC1 | Réponse du serveur DNS |



---



# Module 01 : Introduction système d'exploitation et fonctionnalités

# Introduction à Windows Server 2025

Ce module d'introduction a pour objectif de présenter ce qu'est Windows Server, ainsi que d'évoquer les nouveautés de cette version, les différentes éditions ou encore les modèles de licence.

Le premier chapitre sera consacré à la notion de serveur informatique, à l'intérêt de Windows Server et à son historique. Il sera suivi par un second chapitre consacré à la présentation des nombreuses nouveautés introduites par Microsoft dans Windows Server 2025. Quant au troisième chapitre, il abordera les fonctionnalités supprimées et dépréciées dans cette nouvelle version.

Nous aborderons ensuite les différentes éditions de Windows Server, leurs différences, ainsi que les modèles de licence proposés par Microsoft. Il y a d'ailleurs un nouveau modèle de licence introduit par Microsoft.

Nous finirons par évoquer le support de Windows Server, pour les différentes versions, et les principaux rôles qu'un administrateur peut installer et configurer sur ce système d'exploitation. Cette introduction purement théorique servira de base pour aborder les prochains modules de ce cours.


## Qu’est-ce que Windows Server ?

![image](https://hackmd.io/_uploads/ry4QhF6q-x.png)

### Qu'est-ce qu'un serveur informatique ?

Un serveur informatique est une machine conçue pour fournir des services à d'autres appareils (ordinateurs, smartphones, tablettes, serveurs, etc.) que l'on appelle « clients », via un réseau. En règle générale, un serveur est plus puissant qu'un ordinateur personnel, car il doit gérer de nombreuses connexions et exécuter des tâches complexes. Autrement dit, il doit répondre aux sollicitations des clients.

En termes simples, imaginons que c'est comme un grand bureau d'information dans une gare. Les voyageurs (les clients) demandent des informations ou des services (comme accéder à un site web, télécharger un fichier ou utiliser une application), et le bureau (le serveur) leur fournit ce qu'ils demandent de façon rapide et efficace.

Un serveur peut assurer différentes fonctions selon les besoins de l'entreprise utilisatrice. Nous pouvons citer, à titre d'exemple : stocker et partager des données, gérer des e-mails, héberger des sites web, distribuer une configuration réseau aux ordinateurs, etc.

Nous pouvons considérer qu'un serveur informatique a pour vocation de mettre à disposition un service auprès de plusieurs utilisateurs.

### Qu'est-ce que Windows Server ?

Windows Server est un système d'exploitation créé par Microsoft spécialement pour les serveurs. À l'inverse, Windows est destiné aux postes de travail et représente donc le client. Ceci représente deux grandes familles de systèmes d'exploitation Microsoft.

Windows Server à des points communs avec Windows, notamment d'un point de vue du noyau du système d'exploitation. Il y a aussi une interface graphique et une expérience d'utilisation équivalente, même si l'installation d'un environnement de bureau est facultative avec Windows Server.

Ce système d'exploitation pour les serveurs est conçu pour gérer et supporter de multiples connexions et des charges de travail beaucoup plus importantes que son homologue pour les postes de travail.

Windows Server est un système d'exploitation livré avec de nombreux rôles et fonctionnalités développés par Microsoft. Chaque administrateur est libre d'installer un ou plusieurs rôles sur son serveur, selon les besoins de son entreprise, les ressources matérielles de la machine et les recommandations liées aux bonnes pratiques.

### L'historique de Windows Server

La première version de Windows a été lancée en 1985. Mais, c'est bien dans les années 90 que Microsoft a commencé à travailler sur une première version estampillée « Server ».

La première édition de Windows à intégrer cette appellation, c'est « Windows NT 3.5 ». En effet, Microsoft l'a proposée en plusieurs éditions, dont l'une pour les postes de travail, et l'une pour les serveurs nommée « Windows NT 3.5 Advanced Server ».

Cela s'est poursuivi avec « Windows NT 4.0 Server », lancé à l'été 1996, et « Windows 2000 Server » au début de l'année 2000. D'ailleurs, c'est au sein de « Windows 2000 Server » que Microsoft a introduit la première version de l'Active Directory, un service clé et encore très utilisé aujourd'hui. Nous aurons l'occasion de l'étudier par la suite.

La première version nommée « Windows Server » est bien « Windows Server 2003 », et vous êtes susceptible de la rencontrer encore aujourd'hui dans certaines entreprises. Même s'il faut avouer que c'est de plus en plus rare, et c'est tant mieux.

Au cours des 20 dernières années, Microsoft a sorti plusieurs versions de Windows Server, avec une version majeure environ tous les 3 ans.

Voici un récapitulatif des versions avec les dates de sortie correspondantes :

- Windows Server 2008 : 4 février 2008
- Windows Server 2008 R2 : 22 octobre 2009
- Windows Server 2012 : 4 septembre 2012
- Windows Server 2012 R2 : 18 octobre 2013
- Windows Server 2016 : 12 octobre 2016
- Windows Server 2022 : 18 août 2021
- Windows Server 2025 : 1er novembre 2024

![image](https://hackmd.io/_uploads/SkgZ3cacWx.png)


Windows Server a évolué au fil des années, afin d'être plus stable, plus performant et plus sécurisé. Même s'il ne plaît pas à tout le monde, le système de Microsoft se veut en adéquation avec les besoins des organisations et les tendances du marché.

En effet, aujourd'hui, c'est un pilier de l'informatique d'entreprise, évoluant constamment pour s'adapter aux nouveaux défis technologiques, comme le développement du Cloud computing avec Azure, tout en restant une solution adaptée pour les serveurs physiques traditionnels.


![image](https://hackmd.io/_uploads/r1krhY65bl.png)


---
`
# [Les nouveautés de Windows Server 2025](https://learn.microsoft.com/fr-fr/windows-server/get-started/whats-new-windows-server-2025)

La sortie d'une nouvelle version majeure de Windows Server est synonyme de nouvelles fonctionnalités. Au sein de Windows Server 2025, Microsoft a introduit un bel ensemble de nouveautés et d'amélioration à son système d'exploitation.

Nous allons passer en revue les principales nouveautés. En fonction de votre niveau de connaissance actuel de Windows Server et des rôles associés, certaines nouveautés ne vous évoqueront peut-être pas grande chose. En parcourant IT-Connect, vous pourrez découvrir plus en détail les rôles évoqués dans ce chapitre.

### [Les nouveautés pour l'Active Directory](https://learn.microsoft.com/fr-fr/previous-versions/windows/it-pro/windows-server-2003/cc756101(v=ws.10))

### [Les nouveautés pour Hyper-V](https://learn.microsoft.com/fr-fr/windows-server/get-started/whats-new-windows-server-2025#hyper-v-ai-and-performance)

### [Le protocole SMB](https://learn.microsoft.com/fr-fr/azure/storage/files/storage-how-to-use-files-windows)

### [Les mises à chaud ou « Hotpatching »](https://learn.microsoft.com/fr-fr/windows-server/get-started/hotpatch)

### [Les mises à niveau simplifiées et plus flexibles](https://learn.microsoft.com/fr-fr/windows-server/get-started/upgrade-overview)

### [Le serveur OpenSSH](https://learn.microsoft.com/fr-fr/windows-server/administration/openssh/openssh_keymanagement)

### [Le gestionnaire de paquets WinGet](https://learn.microsoft.com/fr-fr/windows/package-manager/)

### [Intégration de Windows LAPS et nouveaux paramètres](https://learn.microsoft.com/fr-fr/windows-server/identity/laps/laps-scenarios-windows-server-active-directory)

### [La fonction Credential Guard](https://learn.microsoft.com/fr-fr/windows/security/identity-protection/credential-guard/)

### [L'application Windows Terminal](https://learn.microsoft.com/fr-fr/windows/terminal/)

### [Les comptes de messagerie](https://learn.microsoft.com/fr-fr/azure/service-bus-messaging/service-bus-messaging-overview)

### [La compression des fichiers](https://learn.microsoft.com/fr-fr/windows/wsl/filesystems)

### [La gestion de la sécurité avec OSConfig](https://learn.microsoft.com/fr-fr/windows-server/security/osconfig/osconfig-how-to-configure-security-baselines)

---

##  Les nouveautés pour l'Active Directory

Windows Server 2019 et Windows Server 2022 n'avaient pas apporté d'amélioration à l'Active Directory, mais avec Windows Server 2025, la situation évolue. En effet, Microsoft a introduit des nouveautés pour améliorer les performances, rendre l'Active Directory plus « scalable », et pour améliorer la sécurité.

Ci-dessous, la liste des nombreuses améliorations.

- **Prise en charge du matériel NUMA** pour les infrastructures importantes et gourmandes en ressources. Microsoft précise : "AD DS tire désormais parti du matériel NUMA en utilisant les CPU de tous les groupes de processeurs. Auparavant, AD n'utilisait que les CPU du groupe 0. Active Directory peut s'étendre à plus de 64 cœurs." - Microsoft indique que cette nouveauté est aussi accessible via Windows Server 2022 (avec une mise à jour cumulative à installer).

- **Une base de données avec un page size qui passe de 8K à 32K**, ce qui va permettre de stocker des objets avec plus de données et des attributs multi-valeurs qui pourront avoir jusqu'à 3200 valeurs. Cette limite de 8K était présente depuis Windows Server 2000. Les nouveaux DC peuvent être installés avec une base de données de 32 000 pages qui utilise des Long Value ID (LID) de 64 bits et fonctionne en « mode de compatibilité 8 000 pages » pour assurer la compatibilité avec les versions précédentes de Windows Server. Un DC mis à niveau vers cette nouvelle version continue d'utiliser son format de base de données actuel et ses 8 000 pages. Le passage à une base de données de 32 000 pages se fait à l'échelle de la forêt.

- **Amélioration de l'algorithme DC-Locator** pour qu'il soit plus efficace, notamment pour le mapping entre les noms NetBIOS et les noms DNS.

- **Réparation des objets Active Directory** pour les objets dont les attributs indispensables « SamAccountType » et « ObjectCategory » sont manquants.

- **Audit amélioré pour le LDAP Channel Binding** grâce à l'ajout de deux nouveaux événements, associés aux ID « 3074 » et « 3075 ». Si vous durcissez la configuration, cela vous permettra d'identifier les appareils qui ne prennent pas en charge le Channel Binding. Vous pouvez aussi bénéficier de cette nouveauté sur Windows Server 2022 grâce à l'installation de la mise à jour KB4520412.

- **Amélioration des algorithmes de résolution des noms et des SID** : les recherches de noms et d'identifiants de sécurité (SID) par l'Autorité de sécurité locale (LSA) entre les comptes machine n'utilisent plus le canal sécurisé Netlogon « Legacy ». Désormais, l'authentification Kerberos et l'algorithme de « DC Locator » sont utilisés. Pour assurer la compatibilité avec les précédentes versions, l'ancienne méthode reste toujours disponible en solution de repli (fallback).

- **Protection des attributs de l'annuaire** : les contrôleurs de domaine et les instances AD LDS autorisent les opérations d'ajout, de recherche et de modification LDAP impliquant des attributs confidentiels que lorsque la connexion est chiffrée.

- **Renforcement de la sécurité pour les mots de passe par défaut des comptes machine** : Active Directory utilise par défaut des mots de passe générés aléatoirement pour les comptes d'ordinateur. Les contrôleurs de domaine sous Windows Server 2025 empêchent l'utilisation d'un mot de passe correspondant au nom du compte ordinateur.

- **Support de l'agilité cryptographique pour Kerberos PKINIT** : la mise en œuvre du protocole Kerberos PKINIT (Public Key Cryptography for Initial Authentication in Kerberos) a été mise à jour pour permettre une meilleure agilité cryptographique. Cela se traduit par la prise en charge de davantage d'algorithmes et la suppression des algorithmes codés en dur, offrant une meilleure adaptabilité aux évolutions des standards de sécurité.

- **Le protocole Kerberos prend en charge l'AES SHA-256 et SHA-384** (RFC 8009).

- **Suppression du paramètre « Sécurité réseau : ne pas stocker de valeurs de hachage de niveau LAN Manager sur la prochaine modification de mot de passe »** pour les stratégies de groupe.

- **Le protocole LDAP va prendre en charge la dernière implémentation SCHANNEL ainsi que TLS 1.3** pour les connexions « LDAP over TLS ». En complément, toutes les communications avec un client LDAP après une authentification SASL (Simple Authentication and Security Layer) utilisent le « LDAP sealing » par défaut. La signature LDAP est aussi activée par défaut. Ces mesures améliorent la sécurité des échanges effectués via LDAP.

- **Comportement lors du changement de mot de passe SAM via RPC** : les protocoles sécurisés, tels que Kerberos, sont privilégiés pour changer les mots de passe des utilisateurs de domaine. Sur les contrôleurs de domaine, la méthode de changement de mot de passe SAM RPC la plus récente, à savoir « SamrUnicodeChangePasswordUser4 », utilisant l'algorithme AES, est acceptée par défaut lorsqu'elle est appelée à distance. A l'inverse, les méthodes « SAM RPC Legacy » listées ci-dessous sont bloquées par défaut, lorsqu'elles sont appelées à distance :
  - SamrChangePasswordUser
  - SamrOemChangePasswordUser2
  - SamrUnicodeChangePasswordUser2

  Pour les comptes utilisateurs membres du groupe de sécurité « Protected Users » et pour les comptes locaux sur les machines intégrées au domaine, tous les changements de mot de passe à distance via l'interface « SAM RPC Legacy » sont bloqués par défaut, y compris via la méthode « SamrUnicodeChangePasswordUser4 ».

- **Gestion de la priorité pour la réplication** : les administrateurs peuvent désormais augmenter la priorité de réplication calculée par le système avec un partenaire de réplication spécifique, pour un contexte de nommage particulier. Cette fonctionnalité offre plus de flexibilité pour configurer l'ordre de réplication Active Directory, et ainsi répondre à des scénarios spécifiques.

- **Ajout de nouveaux compteurs de performance** pour la surveillance et le diagnostic :
  - DC Locator : compteurs spécifiques pour les clients et les contrôleurs de domaine.
  - Recherches LSA : compteurs pour les recherches de noms et de SID via les API LsaLookupNames, LsaLookupSids, etc… disponibles sur les clients et serveurs.
  - Client LDAP : disponible dans Windows Server 2022 avec la mise à jour KB 5029250.

- **Ajout de trois nouveaux fichiers LDF** (Log Database Files) pour le Schéma Active Directory afin de supporter les évolutions : sch89.ldf, sch90.ldf, et sch91.ldf.

- **Prise en charge d'un nouveau type de compte de service nommé « Delegate Managed Service Accounts » (dMSA)** . Il s'agit d'une alternative plus sécurisée aux MSA et gMSA grâce à la gestion automatique du mot de passe et à la récupération des clés exclusivement via Kerberos. Le serveur sur lequel le dMSA est utilisé ne stocke jamais en local le mot de passe : seul le contrôleur de domaine dispose de cette information. Il est important de noter que les clés sont liées à l'identité de la machine (compte ordinateur) et sécurisées grâce à Credential Guard.

Ces nouveautés sont à l'origine de la création d'un nouveau niveau fonctionnel de domaine et de forêt (niveau 10). Il ajoute la prise en charge de ces nouvelles fonctionnalités. Il se nomme tout simplement « Windows Server 2025 » et il est disponible pour ADDS et ADLDS. Ce niveau fonctionnel vient s'ajouter à la liste existante et prend la suite du niveau actuel le plus récent, à savoir « Windows Server 2016 ».

---

##  Les nouveautés pour Hyper-V

Windows Server 2025 introduit plusieurs nouveautés pour Hyper-V, dont la prise en charge du partitionnement GPU (GPU-P) pour assigner des GPU directement à des VM.

Microsoft a aussi fait évoluer son hyperviseur afin de prendre en charge les clusters Hyper-V en groupe de travail, c'est-à-dire sans Active Directory. Jusqu'ici, l'intégration des hyperviseurs à un domaine Active Directory était un prérequis pour faciliter la mise en œuvre du cluster. Désormais, ces clusters d'un nouveau type peuvent se passer de l'Active Directory sans négliger la sécurité, car il s'agit d'une nouvelle solution basée sur des certificats.

Par ailleurs, lors de la création d'une VM, la génération 2 est l'option par défaut, à la place de la génération 1, bien que l'utilisateur ait toujours le choix. Ceci est une décision cohérente puisque la génération 2 de VM a été introduite avec Windows Server 2012 R2. La génération 1 sera disponible, mais les systèmes d'exploitation Windows qui la requièrent ne sont pas plus pris en charge par Microsoft (Windows 7, Windows Server 2008).

Hyper-V sur Windows Server 2025 supporte jusqu'à 240 To de RAM par machine virtuelle (soit x10 vis-à-vis de la version précédente) et 2048 processeurs virtuels par VM (soit environ x8.5 vis-à-vis de la version précédente). Il s'agit d'améliorations héritées du Cloud Azure.

Enfin, Microsoft a introduit la compatibilité dynamique des processeurs, ce qui va faciliter les opérations de « Live Migration » d'une VM entre plusieurs Hyper-V qui n'ont pas les mêmes CPUs. La fonction de « Live Migration » permet de basculer une VM d'un hyperviseur Hyper-V à un autre, sans interruption, c'est-à-dire « à chaud ». Grâce à cette nouveauté, Hyper-V comparera les processeurs entre les hôtes et utilisera les fonctionnalités processeur prises en charge par les deux processeurs, y compris s'il s'agit de modèles différents.

---

## Le protocole SMB

Le protocole SMB, très utilisé en environnement Windows, notamment pour les accès à des partages de fichiers, bénéficie d'améliorations au sein de Windows Server 2025. Les modifications évoquées ci-dessous montrent que Microsoft veut améliorer la sécurité SMB.

Les nouveaux paramètres permettent d'utiliser un port alternatif pour le SMB, d'utiliser SMB over QUIC (jusqu'ici réservé à « Azure Edition ») et de désactiver le protocole d'authentification NTLM pour les connexions SMB sortantes.

De plus, la signature SMB est activée par défaut, et l'utilisation du chiffrement SMB peut être forcée. « À partir de la version 25931, la signature SMB est désormais requise par défaut pour toutes les connexions SMB sortantes, alors qu'auparavant elle n'était requise que pour les connexions aux partages nommés SYSVOL et NETLOGON sur les contrôleurs de domaine AD. », précise la documentation officielle.

Microsoft a également introduit la génération de nouveaux événements pour auditer les connexions SMB et déterminer les clients qui ne supportent pas la signature SMB et/ou le chiffrement SMB. Ces informations sont stockées dans les journaux « Audit » sous « SMBClient » et « SMBServer ».

- Côté client SMB, cela correspond aux événements avec les ID 31998 et 31999
- Côté serveur SMB, cela correspond aux événements avec les ID 3021 et 3022

Dans le même esprit, vous pouvez auditer les connexions effectuées en « SMB over QUIC » grâce à ces événements :

- Côté client SMB, cela correspond aux événements avec l'ID 30832
- Côté serveur SMB, cela correspond aux événements avec l'ID 1913

Enfin, Microsoft a ajouté la prise en charge de l'algorithme de compression LZ4 pour la compression SMB.

---

## Les mises à chaud ou « Hotpatching »
![image](https://hackmd.io/_uploads/Hy0lTqpqbg.png)

Sur Windows Server, l'installation d'une mise à jour implique le redémarrage du système afin de finaliser l'installation. Ceci s'avère contraignant pour les environnements de production, car ce redémarrage peut être synonyme d'interruption de service.

Windows Server 2025 intègre une nouvelle fonctionnalité jusqu'ici réservée aux instances Windows Server exécutées dans le Cloud Azure : le hotpatching. Cette nouveauté permet l'installation des mises à jour à chaud sur Windows Server, c'est-à-dire sans redémarrage.

Grâce au Hotpatch, il est possible de réduire considérablement le nombre de redémarrages d'une machine. Au lieu des 12 redémarrages annuels habituellement requis si l'on installe toutes les machines à jour, soit une par mois, publiée à l'occasion du « Patch Tuesday », le Hotpatching permet de limiter ces redémarrages à 4 par an, soit un reboot par trimestre.

Le point négatif associé à cette nouveauté pourtant très intéressante sur le papier, c'est l'obligation d'inscrire le serveur auprès du service Azure Arc. Cela permet de faire remonter le serveur local, installé sur votre infrastructure on-premise, dans Azure, et ainsi activer la fonction de Hotpatch.

---

## Les mises à niveau simplifiées et plus flexibles

Le processus de mise à niveau de Windows Server est simplifié puisqu'il est envisageable de mettre à niveau un serveur de Windows Server 2019 ou Windows Server 2022 vers Windows Server 2025 à partir de Windows Update.

Autrement dit, en théorie, migrer de Windows Server 2022 à Windows Server 2025 doit être aussi simple que de passer de Windows 10 à Windows 11. Bien entendu, vous devez tenir compte des rôles, des services et des applications installés sur le serveur avant d'engager une telle opération… La mise à niveau est proposée sous la forme d'une mise à jour optionnelle accessible via Windows Update.

Microsoft a également apporté une seconde modification importante pour les mises à jour « sur place », qui consiste à passer d'une version de Windows Server à une autre, sans faire de réinstallation.

Jusqu'ici, avec Windows Server 2022 et les versions antérieures, il était possible d'effectuer une mise à niveau jusqu'à deux versions supérieures. Par exemple, si vous utilisez Windows Server 2012 R2 vous pouviez passer sur Windows Server 2019, mais pas sur Windows Server 2022.

Avec la nouvelle version, Microsoft offre la possibilité de passer sur Windows Server 2025 à partir de n'importe quelle version, à condition d'être sur Windows Server 2012 R2 ou une version supérieure. Cela signifie que vous pouvez mettre à jour un serveur sous Windows Server 2012 R2 vers Windows Server 2025 en une seule étape ! Avant, il aurait été nécessaire de s'y prendre en deux fois.

Voici la matrice de Microsoft :

[Matrice des mises à niveau]

---

## Le serveur OpenSSH

Depuis plusieurs années, Microsoft prend en charge le protocole SSH pour l'accès à distance, par l'intermédiaire de l'implémentation d'OpenSSH. Ainsi, Windows et Windows Server bénéficient d'un client SSH et d'un serveur SSH.

Dans Windows Server 2025, le serveur OpenSSH est préinstallé par défaut, mais il n'est pas activé. Après l'avoir activé à partir du « Gestionnaire de serveur », il est possible de se connecter au serveur à distance, en ligne de commande, via le protocole SSH. De plus, un nouveau groupe de sécurité local nommé « Utilisateurs OpenSSH » a été ajouté.

---

## Le gestionnaire de paquets WinGet

Désormais intégré par défaut au système, l'utilitaire WinGet, disponible en ligne de commande, permet d'installer des applications et d'autres packages. Il suffit d'utiliser le mot clé « WinGet » avec les bonnes options pour installer des applications à partir de la console. Pour information, WinGet est capable de récupérer les paquets d'applications à partir du Microsoft Store et aussi disponible sur Windows 11.

---

## Intégration de Windows LAPS et nouveaux paramètres

Au même titre que Windows 11, le nouveau Windows Server intègre la fonction de sécurité « Windows LAPS ». Elle a pour objectif de protéger le compte Administrateur local du système d'exploitation grâce à la création d'un mot de passe robuste. Ce mot de passe est renouvelé de façon automatique par Windows LAPS. Il peut être stocké dans l'Active Directory ou dans Microsoft Entra ID, en fonction de la configuration.

Microsoft a aussi introduit la prise en charge de nouveaux paramètres :

- **Créer un nouveau compte administrateur personnalisé** : il est possible de créer facilement un compte local géré avec Windows LAPS. Cette nouveauté permet de personnaliser le nom du compte administrateur, d'activer ou de désactiver le compte et même de rendre aléatoire le nom du compte (un nom unique sur chaque machine).

- **Restauration d'une image système** : Windows LAPS peut détecter quand un appareil a été restauré à partir d'une image système précédente. En temps normal, cette opération peut être problématique, car le mot de passe de l'image restaurée peut ne pas correspondre au mot de passe stocké dans l'Active Directory (ou Entra ID). Un nouvel attribué nommé « msLAPS-CurrentPasswordVersion » va stocker un GUID pour apporter une réponse à cette problématique. Pour bénéficier de cette nouveauté, le schéma Active Directory doit être mis à jour via la commande PowerShell « Update-LapsADSchema ».

- **Générateur de passphrases** : Windows LAPS offre plus de flexibilité pour personnaliser la génération du mot de passe, notamment avec la possibilité de générer des passphrases (suite de plusieurs mots). L'administrateur peut déterminer la complexité et le nombre de mots à utiliser.

- **Amélioration de la lisibilité des mots de passe** : un nouveau paramètre dit de « lisibilité » permet d'éviter l'utilisation de caractères similaires, tels que la lettre « o » et le chiffre « 0 », par exemple, afin d'éviter les confusions. Cela implique de choisir le niveau 5 pour la complexité.

- **Action de post-connexion à un compte Administrateur** : une nouvelle option permet d'ordonner le changement du mot de passe et la déconnexion de la session correspondante au compte managé par Windows LAPS (y compris les processus associés).

---

## La fonction Credential Guard

À partir de Windows Server 2025, la fonctionnalité « Credential Guard » est activée par défaut sur les machines qui respectent les prérequis.

Credential Guard est une fonction de sécurité dont l'objectif est de lutter contre le vol d'identifiants à partir du processus « lsass.exe » du système.

---

## L'application Windows Terminal

L'application « Windows Terminal », disponible par défaut sur Windows 11, est aussi intégrée par défaut à Windows Server 2025. Cette application permet d'ouvrir plusieurs consoles (Invite de commandes, PowerShell, Azure Cloud Shell, etc…) dans une même interface.

Vous pouvez personnaliser l'interface de l'application et créer des sessions personnalisées, grâce à la configuration de l'outil.

---

## Les comptes de messagerie

Bien que cela puisse surprendre, Windows Server 2025 prend en charge la configuration de comptes e-mails, sur le même principe que Windows 11.

Les types de comptes suivants sont pris en charge :

- Compte Microsoft Entra ID
- Compte Microsoft personnel
- Compte Microsoft professionnel ou scolaire

---

## La prise en charge du Wi-Fi

Bien qu'il soit plutôt rare de recourir à l'utilisation d'une connexion sans-fil Wi-Fi sur Windows Server, Microsoft a pris la décision d'installer par défaut le service de LAN sans-fil. Jusqu'ici, il était nécessaire de l'installer manuellement.

Il est installé, mais pas activé par défaut, car à l'administrateur d'activer le démarrage du service s'il en a l'utilité.

---

## Meilleure prise en charge des disques NVMe

Les disques SSD NVMe sont très performants et Microsoft a optimisé Windows Server 2025 de façon à améliorer les performances lorsque le serveur utilise ce type de disque. Cela se traduit par une augmentation des IOPS et une diminution de l'utilisation du processeur.

---

## La gestion du réseau avec « Network ATC »

La fonctionnalité « Network ATC » a été ajoutée à Windows Server 2025, alors que jusqu'ici, elle était réservée à Azure Local (nouveau nom d'Azure Stack HCI) depuis la version 21H2. Elle facilite la mise en réseau des machines intégrées dans un cluster, en automatisant la configuration.

En appliquant des configurations standardisées à travers tous les nœuds d'un cluster, Network ATC assure une cohérence qui minimise les risques d'erreurs et de dérives de configuration. Cette fonctionnalité doit être configurée à l'aide de PowerShell ou de Windows Admin Center. Elle n'est pas intégrée aux autres outils de gestion de Windows Server.

---

##  La compression des fichiers

Un nouvel assistant pour compresser les fichiers dans des archives a été introduit, au même titre que dans Windows 11 24H2. Il permet de créer des archives dans plusieurs formats sans utiliser un logiciel tiers : ZIP, 7z et TAR.

---

## La gestion de la sécurité avec OSConfig

OSConfig, introduit avec Windows Server 2025, simplifie la configuration des paramètres de sécurité recommandés par Microsoft. Il facilite le déploiement de politiques de sécurité basées sur les Security Baselines de Microsoft, garantissant une approche standardisée et robuste pour protéger vos systèmes.

Grâce à OSConfig, les administrateurs peuvent gérer ces configurations via des outils familiers tels que PowerShell, Windows Admin Center ou encore Azure Policy. Il intègre également un mécanisme de détection et de correction automatique des dérives de configuration. En cas de non-conformité détectée, OSConfig peut appliquer automatiquement les paramètres requis, assurant ainsi une conformité continue avec les recommandations de sécurité.

Découvrez notre tutoriel sur l'utilisation d'OSConfig :

Renforcez la sécurité de Windows Server 2025 avec OSConfig


---

## 🔍 Explication détaillée des rôles clés

---

### 🧠 AD DS (Active Directory Domain Services)

**Définition technique :**
Active Directory est un annuaire hiérarchique distribué basé sur LDAP (Lightweight Directory Access Protocol) et Kerberos pour l'authentification. Il stocke les objets (utilisateurs, groupes, ordinateurs, imprimantes) dans une base de données ESE (Extensible Storage Engine) qui utilise désormais des pages de 32 Ko sous Windows Server 2025.

**Fonctionnement concret :**

| Composant | Rôle | Détail technique |
| :--- | :--- | :--- |
| **Domaine** | Périmètre administratif et de sécurité | Groupe logique d'objets partageant une base de données AD commune. Exemple : `contoso.com` |
| **Contrôleur de domaine (DC)** | Serveur hébergeant AD DS | Stocke une copie de la base AD, gère l'authentification (Kerberos KDC), exécute le service NetLogon |
| **Forest** | Conteneur racine | Ensemble de domaines partageant un schéma commun et des relations de confiance automatiques |
| **OU (Unité d'Organisation)** | Conteneur administratif | Permet la délégation et l'application de GPO sans créer de nouveau domaine |

**Scénario concret :**
Société "Satom IT & Learning Solutions" avec 500 employés :
- Création du domaine `satom.local`
- DC principal : `DC01.satom.local` (192.168.10.10)
- DC secondaire : `DC02.satom.local` (192.168.10.20)
- OU "Paris" pour les 200 collaborateurs du siège
- OU "Bordeaux" pour les 150 collaborateurs de l'agence
- Groupe "Administrateurs_IT" avec droits délégués sur les OUs
- Chaque employé s'authentifie une fois au démarrage (SSO) et accède à tous les ressources sans ressaisie du mot de passe

**Mécanisme d'authentification :**
1. L'utilisateur saisit ses identifiants sur PC01
2. PC01 contacte le DC le plus proche (détection via DNS SRV record `_ldap._tcp.dc._msdcs.satom.local`)
3. Le DC émet un Ticket Granting Ticket (TGT) valide 10h par défaut
4. Pour chaque ressource, le client présente le TGT pour obtenir un ticket de service
5. Kerberos version 5 assure l'authentification mutuelle (client + serveur s'authentifient réciproquement)

**Nouveautés Windows Server 2025 :**
- Base de données AD avec pages de 32 Ko (contre 8 Ko précédemment)
- Support des attributs multi-valeurs jusqu'à 15 000 valeurs
- Augmentation du nombre d'objets par domaine : jusqu'à 3 milliards
- Amélioration de la réplication : compression delta plus efficace

---

### 🌐 DNS (Domain Name System)

**Définition technique :**
DNS est un service de résolution de noms hiérarchique et distribué qui fonctionne sur le port 53 (UDP/TCP). Sous Windows Server, le rôle DNS est intégré à AD DS pour assurer la localisation des services critiques via les enregistrements SRV.

**Types d'enregistrements essentiels :**

| Enregistrement | Fonction | Exemple |
| :--- | :--- | :--- |
| **A (Host)** | Résolution nom → IPv4 | `dc01.satom.local → 192.168.10.10` |
| **AAAA** | Résolution nom → IPv6 | `dc01.satom.local → fe80::1` |
| **CNAME (Alias)** | Alias d'un autre nom | `files.satom.local → fs01.satom.local` |
| **MX (Mail)** | Serveur de messagerie | `mail.satom.local priorité 10` |
| **SRV (Service)** | Localisation des services AD | `_ldap._tcp.dc._msdcs.satom.local → dc01.satom.local:389` |
| **PTR (Pointer)** | Résolution IP → nom (reverse lookup) | `10.10.10.10 → dc01.satom.local` |
| **NS (Name Server)** | Serveur de noms autoritaire | `satom.local → dns1.satom.local` |

**Scénario concret :**
L'utilisateur souhaite accéder au partage de fichiers `\\dfs.satom.local\partages` :

1. Le client envoie une requête DNS au serveur configuré (DC01, port 53)
2. Le serveur DNS vérifie sa zone `satom.local` (stockée dans AD)
3. Il retourne l'enregistrement A correspondant à `dfs.satom.local` → `192.168.10.20`
4. Le client établit une connexion SMB vers `192.168.10.20`

**Intégration AD DS :**
- Zones DNS intégrées à AD (stockées dans l'annuaire)
- Sécurité via Secure Dynamic Update (seuls les clients authentifiés peuvent mettre à jour leur enregistrement)
- Réplication DNS intégrée au cycle de réplication AD (plus rapide que les transferts de zone traditionnels)

**Nouveautés Windows Server 2025 :**
- Support de DNSSEC (DNS Security Extensions) renforcé pour validation cryptographique des réponses
- DNS Policy pour la gestion du trafic géo-localisé
- Cache DNS optimisé pour charges élevées (jusqu'à 50 000 requêtes/seconde)

---

### ⚡ DHCP (Dynamic Host Configuration Protocol)

**Définition technique :**
DHCP est un protocole client/serveur fonctionnant sur le port 67 (serveur) et 68 (client) qui automatise l'attribution des paramètres réseau. Le serveur DHCP maintient une base de données de baux (leases) avec durée de validité.

**Étapes du processus DORA :**

| Étape | Type | Direction | Contenu |
| :--- | :--- | :--- | :--- |
| **D**iscover | Broadcast | Client → Serveur | "Je cherche un serveur DHCP" (255.255.255.255:67) |
| **O**ffer | Broadcast/Unicast | Serveur → Client | "Je t'offre l'IP 192.168.10.50 pour 8 jours" |
| **R**equest | Broadcast | Client → Serveur | "J'accepte l'IP 192.168.10.50" |
| **A**cknowledge | Broadcast/Unicast | Serveur → Client | "Validation du bail, voici les paramètres" |

**Paramètres distribués typiques :**

| Option DHCP | Code | Valeur typique |
| :--- | :--- | :--- |
| Subnet Mask | 1 | 255.255.255.0 |
| Router (Passerelle) | 3 | 192.168.10.254 |
| DNS Servers | 6 | 192.168.10.10, 192.168.10.11 |
| Domain Name | 15 | satom.local |
| NTP Servers | 42 | 192.168.10.10 |
| WINS Servers | 44 | 192.168.10.10 (optionnel) |

**Scénario concret :**
Déploiement de 250 postes clients dans l'agence de Bordeaux :

- Le serveur DHCP installé sur `DC01.satom.local`
- Plage d'adresses : `192.168.10.50 - 192.168.10.250`
- Bail standard : 8 jours (machines fixes), 4 heures (zone Wi-Fi invités)
- Exclusions : `192.168.10.1 - 192.168.10.49` (réservé aux serveurs)
- Réservations statiques pour imprimantes réseau (MAC → IP fixe)
- Superscope pour gérer plusieurs sous-réseaux (agences multiples)

**Nouveautés Windows Server 2025 :**
- DHCP Failover amélioré avec mode Load Balance (50/50 par défaut)
- Télémétrie intégrée via Windows Admin Center
- Support IPv6 complet avec attribution automatique via DHCPv6

---

### 📂 File Server (Serveur de fichiers)

**Définition technique :**
Le service de fichiers repose sur le protocole SMB (Server Message Block) version 3.1.1 sous Windows Server 2025. Il permet le partage sécurisé de données avec authentification intégrée à AD DS.

**Protocoles supportés :**

| Protocole | Port | Sécurité | Usage |
| :--- | :--- | :--- | :--- |
| **SMB 3.1.1** | 445 | AES-256, pre-authentification | Standard on-premises |
| **SMB over QUIC** | 443 (UDP) | TLS 1.3, chiffrement | Accès distant sans VPN |
| **NFS** | 2049 | Kerberos | Interopérabilité Linux/Unix |

**Fonctionnalités avancées :**

| Fonctionnalité | Description | Avantage |
| :--- | :--- | :--- |
| **DFS Namespaces (DFS-N)** | Espace de noms unifié masquant l'emplacement physique | `\\satom.local\partages` reste constant même si le serveur change |
| **DFS Replication (DFS-R)** | Réplication asynchrone entre serveurs | Haute disponibilité et répartition de charge |
| **Deduplication des données** | Dédoublonnage post-process | Jusqu'à 80% d'économie de stockage |
| **Work Folders** | Synchronisation type "Dropbox" | Accès mobile aux données personnelles |
| **FSRM (File Server Resource Manager)** | Quotas et filtrage de fichiers | Blocage des exécutables (.exe) et contrôle de l'espace |

**Scénario concret :**
Département financier de 15 personnes :

- Partage `\\fs01.satom.local\finance`
- NTFS permissions : Finance_Team (Modify), Dirigeants (Read)
- Share permissions : Everyone (Full Control) - délégation NTFS uniquement
- Deduplication activée : 750 Go de données compressés à 280 Go
- Quota de 50 Go par utilisateur dans les dossiers personnels
- DFS Namespace : `\\satom.local\donnees\finance`
- Réplication DFS vers `fs02.satom.local` pour continuité

**Nouveautés Windows Server 2025 :**
- SMB over QUIC intégré sans configuration complexe
- Compression SMB activée par défaut pour les transferts sur WAN
- Amélioration des performances NVMe : +70% en IOPS
- Accès direct aux données via Azure File Sync pour le cloud hybride

---

### 🔐 GPO (Group Policy Objects)

**Définition technique :**
Les GPO sont des collections de paramètres administrateur appliqués aux utilisateurs et ordinateurs via AD DS. Elles sont stockées dans SYSVOL (répliqué entre DC) et traitées par le client GPO (service de l'ordinateur) au démarrage et périodiquement.

**Structure d'une GPO :**

| Nœud | Cible | Exemples de paramètres |
| :--- | :--- | :--- |
| **Computer Configuration** | Ordinateur (démarrage) | Paramètres de sécurité, scripts de démarrage, paramètres réseau |
| **User Configuration** | Utilisateur (ouverture session) | Paramètres bureau, scripts de connexion, paramètres Internet Explorer/Edge |

**Hiérarchie d'application :**

```
Local Policy (ordinateur)
    ↓
Site (le plus haut niveau, rarement utilisé)
    ↓
Domain (appliqué à tout le domaine)
    ↓
OU (appliqué à l'OU parent puis enfant)
    ↓
Héritage : La dernière GPO appliquée a priorité
```

**Paramètres GPO critiques en entreprise :**

| Catégorie | Paramètre | Emplacement GPO | Impact |
| :--- | :--- | :--- | :--- |
| **Sécurité** | Longueur minimale mot de passe : 12 caractères | Computer Config > Windows Settings > Security Settings > Account Policies > Password Policy | Réduction des risques brute force |
| **Sécurité** | Verrouillage compte : 5 échecs → 30 min | Account Lockout Policy | Blocage des attaques par dictionnaire |
| **Sécurité** | UAC : Ne pas demander les tâches administratives | Computer Config > Policies > Windows Settings > Security Settings > Local Policies > Security Options | Réduction des élévations intempestives |
| **Restriction** | Désactiver Panneau de configuration | User Config > Policies > Administrative Templates > Control Panel | Standardisation des postes |
| **Restriction** | Interdire lecteurs USB | Computer Config > Policies > Administrative Templates > System > Removable Storage Access | Sécurité des données |
| **Déploiement** | Script de connexion mappage lecteurs | User Config > Windows Settings > Scripts (Logon/Logoff) | Uniformisation des accès |
| **Sécurité** | Pare-feu Windows activé | Computer Config > Policies > Administrative Templates > Network > Network Connections > Windows Firewall | Protection périmètre |
| **Navigation** | Site d'accueil Edge obligatoire | User Config > Policies > Administrative Templates > Microsoft Edge | Charte d'utilisation |

**Scénario concret :**
Création d'une GPO "Sécurité_Strict" liée à l'OU "Postes_Finance" :

1. **Paramètres de mot de passe** : 12 caractères, complexité (majuscule, minuscule, chiffre, symbole)
2. **Verrouillage** : 3 tentatives, déverrouillage après 30 minutes
3. **Restrictions** : Interdiction USB, installation logiciels bloquée
4. **Sécurité réseau** : Pare-feu activé, RDP autorisé uniquement depuis sous-réseau IT
5. **Paramètres utilisateur** : Session verrouillée après 10 minutes d'inactivité

**Nouveautés Windows Server 2025 :**
- GPO Analytics : analyse des conflits et impact avant application
- Intégration avec Microsoft Intune pour co-management (Cloud Policy)
- Paramètres ADMX mis à jour pour Windows 11 24H2

---

### 💻 Hyper-V

**Définition technique :**
Hyper-V est un hyperviseur de type 1 (bare-metal) intégré à Windows Server. Il s'exécute directement sur le matériel et partitionne les ressources physiques en machines virtuelles (VM) isolées. Le composant Hyper-V Hypervisor (hôte) consomme moins de 5% des ressources physiques.

**Architecture Hyper-V :**

| Composant | Rôle | Détail |
| :--- | :--- | :--- |
| **Hyper-V Hypervisor** | Couche de virtualisation | S'exécute sous Windows Server, partitionne le matériel |
| **Parent Partition (Host)** | Partition de gestion | Exécute Windows Server, gère les VM via WMI/PowerShell |
| **Child Partition (VM)** | Machines virtuelles | Chaque VM est une partition isolée avec son propre OS invité |
| **VMBus** | Bus de communication | Canal haute vitesse pour les services (stockage, réseau) entre VM et host |

**Types de virtualisation supportés :**

| Type | Performance | Cas d'usage |
| :--- | :--- | :--- |
| **VM standard** | Native (via VMBus) | Serveurs de production, applications métier |
| **Nested Virtualization** | Réduite de 10-15% | Labo, développement, formation |
| **Virtualization-Based Security (VBS)** | Réduction 5-10% | Isolation des identifiants (Credential Guard) |

**Fonctionnalités clés :**

| Fonctionnalité | Description | Avantage |
| :--- | :--- | :--- |
| **Live Migration** | Déplacement VM sans interruption | Maintenance sans temps d'arrêt |
| **Replica Hyper-V** | Réplication asynchrone vers site secondaire | RPO 5-15 minutes, RTO immédiat |
| **Shielded VMs** | VM chiffrées (BitLocker) | Protection contre accès administrateur host |
| **Disque différencié** | Disques parents/enfants | Économie d'espace pour labos et VDI |
| **SR-IOV (Single Root I/O Virtualization)** | Accès direct au matériel réseau | Performance réseau proche du bare-metal |

**Scénario concret :**
Infrastructure de 5 serveurs physiques virtualisée :

| Hôte physique | Spécifications | VMs hébergées |
| :--- | :--- | :--- |
| HV01 | 64 Go RAM, 2x 10 cœurs | DC01, FS01, IIS01 |
| HV02 | 64 Go RAM, 2x 10 cœurs | DC02, FS02, SQL01 |
| HV03 | 128 Go RAM, 2x 16 cœurs | SQL02, APP01, APP02, RDS01 |
| HV04 (replica) | 64 Go RAM | Réplication HV01 |
| HV05 (replica) | 64 Go RAM | Réplication HV02 |

**Configuration :**
- Cluster Hyper-V (HV01, HV02, HV03) avec Shared Storage (S2D)
- Live Migration réseau dédié (10 GbE)
- Réplication toutes les 10 minutes vers HV04/HV05 (site DR)
- VHDX avec taille dynamique (économise 30% d'espace)
- Points de contrôle (snapshots) quotidiens pour les VMs critiques

**Nouveautés Windows Server 2025 :**
- Virtualization-Based Security (VBS) activée par défaut sur les VMs
- Amélioration des performances : +70% sur charges NVMe
- Hotpatching des VMs (via Azure Arc) sans redémarrage
- Support des tailles de mémoire énormes : jusqu'à 24 To RAM par VM
- Virtual Switch amélioré avec latence réduite de 40%

---

## 📊 Synthèse comparative des rôles

| Rôle | Objectif principal | Dépendance AD | Impact si indisponible | Nouveauté WS2025 |
| :--- | :--- | :--- | :--- | :--- |
| **AD DS** | Authentification centralisée | — | Aucune connexion possible, blocage total | Base 32 Ko, objets jusqu'à 3 milliards |
| **DNS** | Résolution de noms | Optionnelle (intégré AD) | Localisation des services impossible | DNSSEC renforcé, 50k req/sec |
| **DHCP** | Attribution IP automatique | Optionnelle (autorisation) | Configuration manuelle requise | Failover Load Balance 50/50 |
| **File Server** | Stockage centralisé | Oui (permissions) | Accès fichiers impossible | SMB over QUIC natif |
| **GPO** | Configuration centralisée | Oui (stockage SYSVOL) | Perte des paramètres standardisés | GPO Analytics, Intune intégration |
| **Hyper-V** | Virtualisation | Optionnelle | Panne des machines virtuelles | VBS par défaut, Hotpatching |

---

# Module 02 : Installation Windows Server 2025 & Infrastructure DNS et résolution de noms et DHCP

## [Conditions préalables](https://learn.microsoft.com/fr-fr/windows-server/get-started/hardware-requirements?tabs=storage&pivots=windows-server-2025)

![image](https://hackmd.io/_uploads/rJw21jTcZx.png)
![image](https://hackmd.io/_uploads/Bk_ako69-x.png)
![image](https://hackmd.io/_uploads/H1bgeoT9-l.png)
![image](https://hackmd.io/_uploads/SJqgls6c-l.png)
![image](https://hackmd.io/_uploads/SJkBgop5Zl.png)

### Windows server 2025 : installation pas-à-pas
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=50c18f44-cf4a-4070-96bb-f3344eb10385&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="Installation_Windows_Server_2025.webm"></iframe>


<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=8c5acc3b-c871-4b12-b933-6ba9f48cd0e8&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="Cloner(Sysprep)_Windows_Server_2025.webm"></iframe>
![image](https://hackmd.io/_uploads/BkGX-o69be.png)
![image](https://hackmd.io/_uploads/Hkvm-jp5bx.png)
![image](https://hackmd.io/_uploads/H1jQZiT5-l.png)
![image](https://hackmd.io/_uploads/BJWE-ja5be.png)
![image](https://hackmd.io/_uploads/BJr4bjaqWx.png)
![image](https://hackmd.io/_uploads/HJF4bi65-l.png)
![image](https://hackmd.io/_uploads/HyxSZjTqZe.png)
![image](https://hackmd.io/_uploads/rkrSWj65Zl.png)
![image](https://hackmd.io/_uploads/H1FH-iaq-g.png)
![image](https://hackmd.io/_uploads/BkpBZsa9bg.png)
![image](https://hackmd.io/_uploads/HJzIWiT5-g.png)
![image](https://hackmd.io/_uploads/ByLLbjpq-x.png)
![image](https://hackmd.io/_uploads/rkxwWi69We.png)
![image](https://hackmd.io/_uploads/HyVv-jTcZe.png)
![image](https://hackmd.io/_uploads/SyDwWip5Wl.png)

### Confguration Post-Installation
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=9f627b27-53dd-4466-984b-4857d94c1e17&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="IPv4_statique_et_autorisation_icmp(ping)_Windows_Server_2025.webm"></iframe>

<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=84ad429d-5712-4a88-aef1-558f26601d1a&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="10.Renommer_Windows_Server_2025.webm"></iframe>
* L'adressage IP Fixe
* La complexité du password
* Désactiver le ping sur la parefeu
* Activer le services RDP
* Update Windows
* Modifier le password administrateur
* Désactiver l'IE renforcé

### [Configuration Active Directory Server 2025](https://www.numelion.com/installer-active-directory.html)
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=fc5d7001-63ba-4177-b66c-65152267b099&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="12.Installation_du_controleur_de_domaines.webm"></iframe>

<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=9703f948-dc79-44ed-8140-b88acf37e871&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="13.Configuration_administrateur_entreprise.webm"></iframe>

<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=fc398a02-57cb-40ca-b799-82fd2ed3eead&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="14.Test_authentification_administrateur_du_domaine.webm"></iframe>
![image](https://hackmd.io/_uploads/rJa_zj65-e.png)
![image](https://hackmd.io/_uploads/S1Rv7s69-l.png)
![image](https://hackmd.io/_uploads/Sy6pXspqZl.png)
![image](https://hackmd.io/_uploads/SywbEsaqWe.png)
![image](https://hackmd.io/_uploads/H1sQ4s6qbg.png)
![image](https://hackmd.io/_uploads/Hk8HEoa5bl.png)
![image](https://hackmd.io/_uploads/BkKPNsT9bx.png)
![image](https://hackmd.io/_uploads/Hy_dNjp9Wl.png)
![image](https://hackmd.io/_uploads/BkIFViTcbe.png)
![image](https://hackmd.io/_uploads/Bkw5Voa9Wx.png)
![image](https://hackmd.io/_uploads/SJ164sTqbg.png)



### [Configuration du  DHCP (Dynamic Host Configuration Protocol)  Server 2025](https://www.numelion.com/installer-serveur-dhcp-windows-server.html)
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=fc398a02-57cb-40ca-b799-82fd2ed3eead&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="14.Test_authentification_administrateur_du_domaine.webm"></iframe>
![image](https://hackmd.io/_uploads/HkcHUj6cbe.png)
![image](https://hackmd.io/_uploads/B1hLUo6qZl.png)
![image](https://hackmd.io/_uploads/r1Ov8sT5bl.png)
![image](https://hackmd.io/_uploads/BJPFLo6cWx.png)
![image](https://hackmd.io/_uploads/HkrjIia9Zg.png)
![image](https://hackmd.io/_uploads/BkTyDjaqWl.png)
![image](https://hackmd.io/_uploads/Sy1ZvspcWl.png)
![image](https://hackmd.io/_uploads/B1bMDj6qWe.png)
![image](https://hackmd.io/_uploads/BJw4wjTq-e.png)
![image](https://hackmd.io/_uploads/S1YIws65Ze.png)
![image](https://hackmd.io/_uploads/r1xoDDs65bg.png)
![image](https://hackmd.io/_uploads/rkJKPipcWg.png)
![image](https://hackmd.io/_uploads/HJ3YDjTqZe.png)
![image](https://hackmd.io/_uploads/B1QjPs6cWg.png)
![image](https://hackmd.io/_uploads/rkW3wip5-l.png)
![image](https://hackmd.io/_uploads/ryS6vs6cbl.png)
![image](https://hackmd.io/_uploads/rkbxds69Zg.png)
![image](https://hackmd.io/_uploads/HJUWOjT9bx.png)

### Configuration du DNS (Domain Name System)  Server 2025
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=fc398a02-57cb-40ca-b799-82fd2ed3eead&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="14.Test_authentification_administrateur_du_domaine.webm"></iframe>
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=556084fb-6914-4050-bbaa-a19240ec7e51&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="17.Ajouter_Résolution_DNS_inversée_(PTR).webm"></iframe>
![image](https://hackmd.io/_uploads/rJUXroT5bl.png)
![image](https://hackmd.io/_uploads/HkzUBoT9bg.png)
![image](https://hackmd.io/_uploads/S1pwSjp5bg.png)
![image](https://hackmd.io/_uploads/ry-pBoaqWe.png)

### Ajouter un poste client au domaine Active Directory
<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=9e354563-d4f7-4403-9c93-68d4855dee44&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="16.Ajouter_un_poste_client_dans_le_domaine.webm"></iframe>

# Module 04 : Gestion des utilisateurs, groupes et Unités d'Organisation

<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=963fdae3-174d-4a05-b5bc-450c1982d987&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="19.Création_utilisateur_du_domaine.webm"></iframe>

### Créer une Unité d’Organisation dans le domaine
Maintenant que nous savons à quoi va nous servir notre Unité d’Organisation dans Active Directory, voyons comment en créer une. 

Pour cela, on va imaginer que nous avons une entreprise avec plusieurs sites. Un à Nantes, l’autres à Paris, un à Marseille…

Avant de créer une OU, il est important de planifier sa structure en fonction de vos besoins de gestion et de sécurité. C’est pour cela que l’on peut imaginer plusieurs sites dans notre cas.

Nous allons créer une Unité d’Organisation. Commençons par faire un clic droit sur le domaine ou une Unité d’Organisation déjà existante, puis nous allons choisir « Nouveau » et enfin « Unité d’organisation ».

### Organiser et hiérarchiser sa forêt Active Directory

Maintenant, dans notre Unité d’Organisation, nous pouvons en créer des nouvelles pour hiérarchiser et organiser nos éléments dans notre annuaire Active Directory. 
Dans l’exemple ci-dessous, il me suffit d’ajouter des services sous la forme de UO pour le site de Nantes. 
On pourrait simuler des services IR, RH et Direction qui contiendront par exemple des utilisateurs.
![image](https://hackmd.io/_uploads/SyeG6s69We.png)

![image](https://hackmd.io/_uploads/S188ns65-e.png)
![image](https://hackmd.io/_uploads/B1BVnoTcbl.png)
![image](https://hackmd.io/_uploads/B13r6jpqZx.png)

![image](https://hackmd.io/_uploads/HyWvnjT9Wg.png)
![image](https://hackmd.io/_uploads/B1Uk6sT9bg.png)
![image](https://hackmd.io/_uploads/HkuDhsp5-e.png)

<iframe src="https://satomitlearning.sharepoint.com/sites/Formateurs-CHE2Cours/_layouts/15/embed.aspx?UniqueId=6610048c-14e8-40c0-b00a-8130820e93d2&embed=%7B%22ust%22%3Afalse%2C%22hv%22%3A%22CopyEmbedCode%22%7D&referrer=StreamWebApp&referrerScenario=EmbedDialog.Create" width="1280" height="720" frameborder="0" scrolling="no" allowfullscreen title="18.Supprimer_une_UO_protégée.webm"></iframe>