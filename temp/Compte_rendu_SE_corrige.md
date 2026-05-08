# Compte rendu du Projet Pratique

**Filière :** GLSID-ICCN
**Année Universitaire :** 2025–2026

## CanaryFS : Système de surveillance par fichiers leurres pour la détection et la traçabilité des accès non autorisés

**Réalisé par :**
- Douae TAHIRI
- Hamza BELAZRI
- Youssef SABRI
- Mohamed AIT EL KADI

**Encadré par :** M. OUAGUID

**Dépôt GitHub :** https://github.com/Hamzaaxx/projet-sys

---

## Résumé

Ce rapport présente *canaryfs*, un outil Bash et C de détection d'intrusion basé sur la technique des fichiers leurres (canary files). Le programme plante des fichiers imitant des secrets sensibles (clés SSH, identifiants AWS, fichiers `.env`) dans un répertoire cible, puis surveille en temps réel toute tentative d'accès via les sous-systèmes **inotify** et **fanotify** du noyau Linux. Quatre modes d'exécution sont implémentés (séquentiel, fork, threads POSIX, subshell) afin d'illustrer les concepts du module Systèmes d'Exploitation. Toute violation déclenche une alerte forensique complète (PID, processus, UID, PPID) enregistrée dans un fichier de logs et, si activé, dans le syslog système et sous forme de notification graphique.

---

## Remerciements

Nous tenons à adresser nos plus sincères remerciements à notre professeur, Monsieur **Ouaguid Abdellah**, pour sa disponibilité, ses précieux conseils, ses explications ainsi que les connaissances qu'il nous a transmises tout au long du module des Systèmes d'Exploitation. Grâce à son soutien et à ses orientations, nous avons pu mieux comprendre plusieurs notions importantes liées aux systèmes d'exploitation et à la programmation sous Linux.

Nous remercions également tous les enseignants du module des Systèmes d'Exploitation pour les connaissances et les compétences qu'ils nous ont transmises durant notre formation, ainsi que **l'ENSET Mohammedia** pour les ressources pédagogiques mises à notre disposition.

Enfin, nous remercions toutes les personnes ayant contribué de près ou de loin à l'aboutissement de ce projet.

---

## Table des matières

1. Introduction générale
2. **Chapitre 1 :** Contexte général et analyse des besoins
3. **Chapitre 2 :** Architecture et conception du programme
4. **Chapitre 3 :** Fonctionnalités du programme
5. **Chapitre 4 :** Implémentation technique
6. **Chapitre 5 :** Tests et validation
7. **Chapitre 6 :** Difficultés rencontrées
8. **Chapitre 7 :** Perspectives et évolutions futures
9. Conclusion générale
10. Glossaire
11. Bibliographie
12. Annexes

---

## Introduction générale

L'évolution rapide des systèmes informatiques et l'augmentation des menaces de sécurité rendent la protection des données et la surveillance des activités suspectes de plus en plus importantes. Dans ce contexte, les systèmes de détection et les techniques de honeypot jouent un rôle essentiel dans l'identification des accès non autorisés et des comportements malveillants au sein d'un système informatique.

Dans le cadre du module des Systèmes d'Exploitation, nous avons réalisé un projet intitulé **CanaryFS**, dont l'objectif principal est de mettre en place un système de surveillance basé sur des fichiers leurres appelés *canary files*. Ces fichiers sont volontairement créés dans un répertoire cible afin d'attirer l'attention d'un utilisateur ou d'un processus suspect. Toute tentative d'accès à ces fichiers déclenche automatiquement une alerte et permet d'enregistrer plusieurs informations importantes telles que l'utilisateur concerné, le processus utilisé, le PID ainsi que la date et l'heure de l'événement.

Ce projet nous a permis de mettre en pratique plusieurs notions étudiées en cours, notamment la programmation Shell sous Linux, la gestion des processus et des threads POSIX, ainsi que l'utilisation des outils de surveillance du système de fichiers comme **inotifywait** et **fanotify**. Il représente également une première approche des mécanismes utilisés dans le domaine de la cybersécurité et de la détection d'intrusions.

Ce rapport présente en détail l'architecture du programme, les fonctionnalités implémentées, les choix techniques effectués, les résultats des tests ainsi que les difficultés rencontrées et leurs solutions.

---

# Chapitre 1 : Contexte général et analyse des besoins

## I. Problématique

Dans un environnement Linux, les administrateurs système et les professionnels de la cybersécurité font face à plusieurs défis liés à la protection et à la surveillance des systèmes. La détection des intrusions en temps réel reste particulièrement complexe, car des attaquants peuvent accéder à des fichiers sensibles tels que les clés SSH, les fichiers de configuration ou encore les identifiants de bases de données sans laisser de traces immédiates visibles.

En outre, les outils de surveillance existants comme **Wazuh**, **OSSEC** ou **auditd** sont souvent lourds, difficiles à configurer et peuvent consommer des ressources importantes du système, ce qui limite leur utilisation dans des environnements légers ou pédagogiques. Par ailleurs, lorsqu'une intrusion est détectée, les informations fournies ne sont pas toujours suffisantes pour une analyse forensique complète, notamment en ce qui concerne l'identification du processus, de l'utilisateur responsable ou encore l'horodatage précis de l'événement.

De plus, les solutions de sécurité traditionnelles comme les antivirus ou les pare-feu ne sont pas toujours efficaces contre les actions malveillantes réalisées par des utilisateurs internes ayant des accès légitimes au système. Face à ces limites, il devient nécessaire de disposer d'un outil simple, léger et efficace, capable de surveiller les fichiers sensibles en temps réel, de déclencher des alertes immédiates en cas d'accès suspect, de collecter des informations forensiques exploitables et de s'adapter facilement à différents environnements sans surcharger le système.

## II. Objectifs du projet

L'objectif principal de ce projet est de développer un outil Bash appelé **canaryfs** qui permet de détecter les accès non autorisés à des fichiers sensibles sous Linux.

Le principe consiste à créer des fichiers leurres (canary files) dans un répertoire cible, puis à les surveiller en temps réel avec **inotifywait** (modes fork, subshell, par défaut) et **fanotify** (mode threads). Lorsqu'un fichier est ouvert, lu ou modifié, le système déclenche automatiquement une alerte et enregistre des informations importantes comme le PID, le processus, l'UID, le PPID ainsi que la date et l'heure de l'événement.

Le projet propose aussi plusieurs modes d'exécution (fork, threads et subshell), ainsi que des options de contrôle pour personnaliser son utilisation. Toutes les actions et alertes sont enregistrées dans un fichier de log pour assurer une traçabilité complète du système.

## III. Solutions proposées

La solution proposée dans ce projet consiste à développer un outil **canaryfs** combinant Bash (pour la logique métier) et C (pour la concurrence par threads), basé sur la création de fichiers leurres afin de détecter les accès non autorisés à des fichiers sensibles dans un système Linux.

Le système crée automatiquement ces fichiers dans un répertoire cible, puis les surveille en temps réel à l'aide d'**inotifywait** et de **fanotify**. Toute action sur un fichier canary (ouverture, lecture ou modification) est immédiatement détectée par le système.

Lorsqu'un accès est identifié, le programme déclenche une alerte qui peut inclure une notification sur le bureau de l'utilisateur, en plus de l'enregistrement des événements dans les logs. Le système collecte également des informations forensiques importantes telles que le PID, le nom du processus, l'UID, le PPID ainsi que la date et l'heure de l'événement.

Les alertes sont enregistrées dans un fichier de log afin d'assurer une traçabilité complète, et peuvent également être affichées sous forme de notifications pour une réaction rapide de l'administrateur.

Enfin, l'outil propose plusieurs modes d'exécution (par défaut, fork, threads et subshell) afin de s'adapter à différents environnements et besoins, tout en restant léger et efficace.

---

# Chapitre 2 : Architecture et conception du programme

## I. Structure générale du programme

Le programme canaryfs est structuré selon une approche **modulaire**. Cette organisation sépare le code en plusieurs fichiers indépendants, chacun ayant une responsabilité unique. Cette conception présente plusieurs avantages : elle facilite la maintenance, permet de tester chaque module séparément et rend le code plus lisible.

Le script principal `canaryfs` situé à la racine du projet constitue le point d'entrée unique. Il est responsable de l'analyse des options, du chargement de la configuration, de la validation des paramètres, de la compilation à la volée du binaire C, et de l'orchestration des modules. Tous les appels au programme passent obligatoirement par ce fichier.

Le script principal charge les modules via la commande `source` et exporte les fonctions nécessaires. Chaque module communique avec les autres via des variables globales et des fonctions exportées. Le flux d'exécution est linéaire : chargement de la configuration, plantation des canaries, surveillance en temps réel, alerte sur événement, puis éventuellement restauration.

Le programme dépend de plusieurs outils externes :
- **inotifywait** pour la surveillance dans les modes fork, subshell et par défaut
- **fanotify** (appel système) pour la surveillance fiable dans le mode threads
- **lsof** et **/proc** pour les informations forensiques
- **logger** pour l'envoi vers syslog
- **notify-send** pour les notifications desktop

Ces dépendances sont vérifiées au démarrage par la fonction `validate()`.

## II. Arborescence des fichiers

```
canaryfs/
├── canaryfs                    # Script principal (exécutable)
├── canaryfs.conf               # Fichier de configuration auto-chargé
├── demo.sh                     # Script de démonstration interactif
├── README.md                   # Documentation principale
│
├── lib/                        # Bibliothèques de fonctions
│   ├── plant.sh                # Génération des fichiers leurres
│   ├── monitor.sh              # Surveillance (fork, subshell, défaut)
│   ├── monitor_thread.c        # Surveillance par threads (fanotify + pthreads)
│   ├── alert.sh                # Envoi des alertes (syslog, desktop)
│   ├── log.sh                  # Gestion des logs
│   └── restore.sh              # Nettoyage et restauration
│
├── canaries/                   # Templates des fichiers leurres
│   ├── id_rsa.tpl
│   ├── env.tpl
│   ├── credentials.tpl
│   ├── shadow.tpl
│   └── backup.tpl
│
├── tests/                      # Scénarios de test
│   ├── test_light.sh           # Test léger (5 canaries)
│   ├── test_medium.sh          # Test moyen (50 canaries)
│   └── test_heavy.sh           # Test lourd (200 canaries)
│
├── docs/
│   └── index.html              # Site de documentation détaillée
│
└── scripts/                    # Scripts utilitaires
    ├── create_issues.sh
    └── create_issues.ps1
```

## III. Description des modules

### 1. Module principal (canaryfs)

Ce module assure les fonctions suivantes :

- **Chargement de la configuration** : Le fichier `canaryfs.conf` est automatiquement sourcé au démarrage si présent. Il permet de personnaliser les valeurs par défaut (LOG_DIR, CANARY_COUNT, ALERT_MODE) sans modifier le script.
- **Analyse des options** : La fonction `parse_args()` utilise `getopts` avec la chaîne de format `":hftsal:rp:"` pour lire les options `-h`, `-f`, `-t`, `-s`, `-l`, `-r`, `-p`, `-a`.
- **Validation** : La fonction `validate()` vérifie la présence d'inotifywait, du répertoire cible et son existence.
- **Compilation à la volée** : La fonction `compile_thread_monitor()` compile `monitor_thread.c` avec `gcc -lpthread -Wall -O2` lors du premier appel en mode threads.
- **Orchestration** : Les fonctions `run_fork()`, `run_thread()`, `run_subshell()` et `run_default()` lancent le mode correspondant.
- **Gestion des signaux** : Un trap capturant `SIGINT` et `SIGTERM` (`trap cleanup SIGINT SIGTERM`) assure la terminaison propre de tous les processus enfants via `pkill -P $$`. Cette gestion garantit qu'aucun watcher orphelin ne reste actif après un Ctrl+C.

### 2. Module de plantation (plant.sh)

- **`plant_canaries()`** : Plante le nombre demandé de canaries dans le répertoire cible en cyclant à travers les 5 types disponibles via une opération modulo.
- **`_write_canary()`** : Crée un fichier leurre. Si un template `.tpl` existe dans le dossier `canaries/`, il est copié vers la destination ; sinon, un contenu factice est généré inline. Les permissions sont fixées à `600` (lecture/écriture pour le propriétaire uniquement) afin de renforcer le réalisme du leurre.

### 3. Module de surveillance (monitor.sh)

- **`monitor_file()`** : Surveille un seul fichier avec `inotifywait`. Chaque événement (open, access, modify) déclenche `_capture_forensics()`. Utilisé en modes fork et subshell.
- **`monitor_directory()`** : Surveille un répertoire entier avec l'option `-r` de inotifywait. Vérifie que le fichier concerné est bien enregistré dans le registry des canaries avant de déclencher une alerte.
- **`_capture_forensics()`** : Utilise `lsof` (avec une boucle de 5 tentatives espacées d'1 ms pour atténuer la course critique avec les commandes rapides) et `/proc/<pid>/status` pour collecter le PID, PPID, le nom du processus et l'UID. Ces informations sont transmises à `log_alert()` et `fire_alert()`.

### 4. Module de surveillance par threads (monitor_thread.c)

Ce programme en C implémente la surveillance avec des threads POSIX (pthreads) et utilise **fanotify** au lieu d'inotify pour résoudre la course critique :

- **`main()`** : Vérifie que le programme s'exécute en root (fanotify nécessite `CAP_SYS_ADMIN`), puis crée un thread par fichier à surveiller via `pthread_create()`. Attend la terminaison de tous les threads avec `pthread_join()`.
- **`watch_file()`** : Fonction exécutée par chaque thread. Initialise un descripteur fanotify avec `fanotify_init()`, marque le fichier cible avec `fanotify_mark()`, puis boucle sur `read()` pour recevoir les événements directement du noyau.
- **`resolve_proc_info()`** : Lit `/proc/<pid>/comm` pour obtenir le nom du processus et `/proc/<pid>/status` pour l'UID et le PPID.
- **`write_alert()`** : Écrit l'alerte dans le terminal et dans le fichier de log.

**Avantage clé de fanotify** : la structure `fanotify_event_metadata` retournée par le noyau contient directement le **PID** du processus ayant accédé au fichier. Il n'y a donc pas besoin d'appeler `lsof` après coup, ce qui élimine la course critique qui faisait apparaître `pid=unknown` pour les commandes rapides comme `cat`.

### 5. Module d'alerte (alert.sh)

- **`fire_alert()`** : Vérifie si `ALERT_MODE` est activé (via l'option `-a`). Si oui, écrit dans syslog via `logger -t canaryfs -p auth.warning` et envoie une notification desktop via `notify-send --urgency=critical`. Pour l'environnement VirtualBox, la variable `DISPLAY=:0` est exportée afin de garantir l'affichage des notifications.

### 6. Module de restauration (restore.sh)

- **`run_restore()`** : Vérifie que l'utilisateur effectif est root (`$EUID -eq 0`). Lit le fichier `CANARY_REGISTRY` ligne par ligne et supprime chaque fichier listé avec `rm -f`. Supprime ensuite le fichier registry lui-même. Cette restriction empêche un attaquant non privilégié de supprimer les canaries après détection.

### 7. Module de log (log.sh)

- **`init_log_dir()`** : Crée le répertoire de logs et initialise le fichier `history.log`.
- **`_log()`** : Écrit une ligne au format imposé par le cahier des charges : `yyyy-mm-dd-hh-mm-ss : username : TYPE : message`. La sortie est dirigée simultanément vers le terminal et le fichier de log via `tee -a`.
- **`log_info()`, `log_error()`, `log_alert()`** : Fonctions d'interface pour écrire respectivement des messages INFOS, ERROR (vers stderr) et ALERT.

---

# Chapitre 3 : Fonctionnalités du programme

## I. Options du programme

Le programme canaryfs implémente **huit options** décrites ci-dessous.

| Option | Description | Privilèges |
|--------|-------------|------------|
| `-h` | Affiche l'aide détaillée du programme. | Tout utilisateur |
| `-f` | Active le mode fork : chaque fichier leurre est surveillé par un processus fils indépendant. | Tout utilisateur |
| `-t` | Active le mode threads : surveillance assurée par un programme C utilisant pthreads et fanotify. Un thread par fichier. | **Root** (fanotify) |
| `-s` | Active le mode subshell : exécution en arrière-plan comme un démon, rendant immédiatement la main à l'utilisateur. | Tout utilisateur |
| `-l <dir>` | Spécifie un répertoire personnalisé pour les logs (défaut : `/var/log/canaryfs/`). | Tout utilisateur |
| `-r` | Supprime tous les fichiers leurres et restaure l'état initial. **Nécessite obligatoirement les privilèges root**, conformément au cahier des charges. | **Root** |
| `-p <n>` | Définit le nombre de fichiers leurres à planter (défaut : 10). | Tout utilisateur |
| `-a` | Active le mode alerte complet : écriture dans syslog + notification graphique desktop. | Tout utilisateur |

## II. Types de canaries

Le programme plante cinq types de fichiers leurres différents, tous conçus pour imiter des fichiers sensibles réels.

- **id_rsa** : imite une clé privée SSH (en-têtes OpenSSH, données encodées en base64). Très attractif pour un attaquant cherchant à prendre le contrôle d'un serveur.
- **.env** : imite un fichier de variables d'environnement avec de faux identifiants AWS, mots de passe de base de données et clés JWT. Cible privilégiée pour les développeurs qui stockent les secrets dans ces fichiers.
- **credentials.json** : imite un fichier de credentials cloud (AWS, GCP) contenant un faux compte de service avec project_id, private_key et client_email.
- **shadow.bak** : imite une sauvegarde du fichier shadow système avec de fausses entrées de mots de passe hachés. Extrêmement sensible car il permet le cassage de mots de passe.
- **backup.sql** : imite une sauvegarde de base de données avec une fausse table users contenant email, password_hash et api_key.

Le contenu de chaque fichier est généré de deux manières possibles : si un template `.tpl` existe dans `canaries/`, il est copié ; sinon, un contenu factice est généré inline. Dans tous les cas, les permissions sont fixées à **600** pour renforcer le réalisme.

## III. Modes d'exécution

Le programme propose **quatre** modes d'exécution :

- **Mode fork (`-f`)** : Chaque fichier leurre est surveillé par un processus fils indépendant créé via le subshell `( ... ) &`. Bonne isolation entre les surveillances mais consommation de ressources élevée pour un grand nombre de canaries.
- **Mode threads (`-t`)** : La surveillance est assurée par un programme C utilisant la bibliothèque `pthreads`. Chaque fichier est assigné à un thread qui utilise `fanotify` pour recevoir les événements du noyau avec le PID intégré. Plus rapide et plus léger que le mode fork.
- **Mode subshell (`-s`)** : Le programme s'exécute en arrière-plan comme un démon. Le terminal est immédiatement rendu à l'utilisateur. Idéal pour une surveillance prolongée.
- **Mode par défaut** (aucun flag) : Surveillance séquentielle de l'intégralité du répertoire cible avec un seul `inotifywait -r`. Économe en ressources mais moins parallèle.

## IV. Système de logging

Par défaut, les logs sont stockés dans `/var/log/canaryfs/history.log`. L'option `-l` permet de spécifier un répertoire personnalisé, utile lorsque l'utilisateur ne dispose pas des privilèges root pour écrire dans `/var/log/`.

Chaque ligne de log suit le format imposé par le cahier des charges :
```
yyyy-mm-dd-hh-mm-ss : username : TYPE : message
```

**Trois types de messages** sont utilisés :
- **INFOS** pour les messages informatifs (démarrage du programme, plantation des canaries, mode d'exécution).
- **ERROR** pour les messages d'erreur (absence de inotifywait, répertoire cible inexistant, échec de compilation).
- **ALERT** pour les détections d'accès aux canaries.

Exemple concret de log :
```
2026-05-08-09-04-17 : kali : ALERT : canary accessed — file=/tmp/honeypot/.env event=OPEN pid=4630 process=zsh uid=1000 ppid=1497
```

L'écriture dans le terminal et le fichier est simultanée, assurée par `tee -a` dans la fonction `_log()` de `lib/log.sh`. Les messages d'erreur sont en plus redirigés vers stderr (`>&2`) pour permettre leur séparation des autres flux par les scripts appelants.

## V. Système d'alerte

Le programme déclenche des alertes à **trois niveaux différents** :

1. **Alerte dans le terminal** : lorsqu'un fichier leurre est accédé, une ligne ALERT s'affiche immédiatement dans le terminal où le programme est en cours d'exécution.
2. **Alerte dans syslog** : si l'option `-a` est activée, chaque alerte est également envoyée au syslog système via `logger -t canaryfs -p auth.warning`. Cela permet à l'administrateur de centraliser toutes les alertes avec les autres événements système.
3. **Notification desktop** : la même option `-a` active l'envoi d'une notification graphique sur le bureau via `notify-send`. Pour l'environnement VirtualBox, la variable `DISPLAY=:0` est exportée afin de garantir l'affichage.

Ces trois niveaux assurent une réaction rapide de l'administrateur en cas d'intrusion détectée.

---

# Chapitre 4 : Implémentation technique

## I. Technologies utilisées

Le programme s'appuie sur plusieurs technologies et outils standards de Linux :

- **Bash** : utilisé pour le script principal, la logique métier et l'orchestration des modules. Bash est préinstallé sur toutes les distributions Linux et facilite la manipulation des fichiers et des processus.
- **C avec pthreads** : utilisé pour la surveillance multi-thread en mode `-t`. Le programme C avec la bibliothèque pthreads offre de meilleures performances que Bash pour les opérations concurrentes et permet de respecter strictement la sémantique « thread » exigée par le cahier des charges (Bash ne possède pas de vrais threads, seulement des processus fils).
- **inotifywait** (paquet `inotify-tools`) : outil utilisateur qui s'appuie sur l'API noyau `inotify` pour la détection en temps réel des accès aux fichiers (open, access, modify).
- **fanotify** (appel système Linux ≥ 2.6.36) : sous-système noyau plus avancé que inotify. Sa principale différence est que la métadonnée d'événement contient directement le **PID du processus** ayant déclenché l'accès, ce qui permet une capture forensique atomique et fiable même pour les commandes très rapides (résout définitivement le problème de la course critique).
- **lsof** : commande permettant de lister les fichiers ouverts. Utilisée en repli (modes fork/subshell/défaut) pour collecter le PID et l'UID lorsque fanotify n'est pas disponible.
- **logger** : utilitaire qui envoie des messages au syslog système.
- **notify-send** : commande pour afficher des notifications graphiques sur le bureau.
- **gcc** : compilateur C, utilisé via `compile_thread_monitor()` pour compiler `monitor_thread.c` à la volée la première fois que le mode `-t` est utilisé.
- **getopts** : commande Bash intégrée pour l'analyse des options en ligne de commande, conforme à POSIX.

## II. Gestion des erreurs et redirection des sorties

Le programme gère activement les erreurs avec des codes spécifiques :

| Code | Cause | Action |
|------|-------|--------|
| `100` | Option non reconnue | Affichage du message + aide automatique |
| `101` | Paramètre obligatoire manquant (target_directory) | Affichage du message + aide |
| `102` | inotifywait non installé | Affichage du message + aide |
| `103` | Répertoire cible inexistant | Affichage du message + aide |
| `104` | Tentative d'utiliser `-r` sans privilèges root | Affichage du message + aide |

Conformément au cahier des charges, après chaque erreur, le programme affiche automatiquement la documentation d'aide comme le fait l'option `-h`.

Toutes les sorties standard (stdout) et les erreurs (stderr) sont redirigées simultanément vers le terminal et vers le fichier de log. Cette redirection est assurée dans `lib/log.sh` par l'appel `echo "..." | tee -a "${LOG_FILE}"` pour chaque message logué, et par la redirection `>&2` pour les messages d'erreur. L'administrateur dispose ainsi d'une traçabilité complète de toutes les actions et erreurs du programme.

## III. Gestion des processus et threads

### Mode fork

La fonction `run_fork()` parcourt la liste des canaries enregistrées dans le fichier registry et lance un processus enfant pour chaque fichier via `( monitor_file "$file" ) &`. Le subshell `( )` crée un véritable processus fils via l'appel système `fork()`. Le programme principal attend ensuite la fin de tous les processus avec la commande `wait`, ce qui garantit que la surveillance se poursuit tant que tous les processus sont actifs.

### Mode threads

Le programme C `monitor_thread.c` est compilé puis exécuté. La fonction `main()` crée un thread par fichier à surveiller via `pthread_create()`. Chaque thread exécute la fonction `watch_file()` qui initialise un descripteur fanotify et lit les événements via `read()`. Les threads partagent le même espace mémoire (vérifiable avec `cat /proc/<pid>/status | grep Threads`), ce qui rend ce mode plus léger et plus rapide que le mode fork. Le mode threads nécessite les privilèges root car fanotify exige la capability `CAP_SYS_ADMIN`.

### Mode subshell

Le programme est lancé dans un subshell en arrière-plan avec `( ... ) &`. Le PID du processus principal est affiché à l'utilisateur pour permettre son arrêt ultérieur via `kill` ou `pkill`. Ce mode est idéal pour une surveillance prolongée car l'utilisateur peut continuer à utiliser son terminal normalement.

### Gestion propre des signaux

Un trap signal est installé au démarrage : `trap cleanup SIGINT SIGTERM`. La fonction `cleanup()` est invoquée lorsque l'utilisateur interrompt le programme (Ctrl+C) ou lorsqu'un signal de terminaison est reçu. Elle utilise `pkill -P $$` pour tuer tous les processus enfants (`inotifywait`, `monitor_thread`) avant de quitter, garantissant qu'aucun watcher orphelin ne reste actif.

---

# Chapitre 5 : Tests et validation

## I. Scénario Light

Le scénario Light consiste à planter 5 canaries dans un seul répertoire. L'objectif est de mesurer le temps de détection de base et de comparer les performances des trois modes d'exécution.

**Procédure** : plantation de 5 canaries → lancement de la surveillance → lecture du fichier `.env` pour déclencher une alerte → mesure du temps total et du temps de détection.

| Mode | Temps total | Temps de détection |
|------|-------------|--------------------|
| Fork | 2014 ms | 4 ms |
| Thread | 2014 ms | 2 ms |
| Subshell | 2022 ms | 8 ms |

**Note méthodologique** : les temps absolus (≈ 2014 ms) sont dominés par les délais de synchronisation `sleep 1` insérés dans le script de test pour laisser à inotifywait/fanotify le temps de s'initialiser. La différence pertinente entre les modes se manifeste à plus grande échelle dans les scénarios Medium et Heavy.

**Analyse** : Le mode thread est le plus rapide avec un temps de détection de seulement 2 ms grâce à fanotify qui livre l'événement avec le PID directement intégré, sans nécessiter d'appel à lsof. Le mode fork affiche 4 ms, et le mode subshell est légèrement plus lent (8 ms) à cause de la surcharge de l'exécution en arrière-plan.

## II. Scénario Medium

Le scénario Medium consiste à planter 50 canaries réparties dans 5 répertoires différents (10 canaries par répertoire). L'objectif est de comparer les performances sous une charge modérée.

| Mode | Temps total |
|------|-------------|
| Fork | ≈ 2500 ms |
| Thread | ≈ 1000 ms |
| Subshell | ≈ 1100 ms |

**Analyse** : Le mode thread est nettement plus performant que le mode fork (1000 ms contre 2500 ms, soit une réduction de plus de 60 %). Le mode fork est plus lent car la création de 50 processus consomme davantage de ressources kernel (table des processus, structures `task_struct`, espace mémoire dédié à chaque processus). Le mode subshell offre des performances proches du mode thread.

## III. Scénario Heavy

Le scénario Heavy consiste à planter 200 canaries réparties dans 10 répertoires (20 canaries par répertoire). L'objectif est de stresser le programme et d'évaluer ses performances sous charge maximale.

| Mode | Temps total |
|------|-------------|
| Fork | ≈ 10000 ms |
| Thread | ≈ 3000 ms |
| Subshell | ≈ 3000 ms |

**Analyse** : Sous charge lourde, la différence entre les modes est encore plus marquée. Le mode thread est environ trois fois plus rapide que le mode fork (3000 ms contre 10000 ms). Le mode fork devient très lent car la création et la gestion de 200 processus consomment énormément de ressources système. Le mode thread reste stable et performant grâce au partage de mémoire entre threads d'un même processus.

## IV. Comparaison des modes

| Mode | Light (5 canaries) | Medium (50 canaries) | Heavy (200 canaries) |
|------|--------------------|-----------------------|------------------------|
| Fork | 2014 ms | ≈ 2500 ms | ≈ 10000 ms |
| Thread | 2014 ms | ≈ 1000 ms | ≈ 3000 ms |
| Subshell | 2022 ms | ≈ 1100 ms | ≈ 3000 ms |

**Conclusions des tests :**

- **Mode thread (`-t`)** : recommandé pour un grand nombre de canaries. Performances optimales en rapidité et en consommation de ressources, et capture forensique fiable même pour les accès très rapides grâce à fanotify.
- **Mode fork (`-f`)** : adapté pour un petit nombre de canaries (< 50). Devient lent et gourmand en ressources au-delà.
- **Mode subshell (`-s`)** : idéal pour une surveillance prolongée en arrière-plan. Performances comparables au mode thread.

---

# Chapitre 6 : Difficultés rencontrées

Plusieurs difficultés techniques ont été rencontrées au cours du développement et ont nécessité des solutions spécifiques.

## 1. Course critique entre inotify et lsof

**Problème** : la première version du programme utilisait `inotifywait` pour détecter l'accès, puis appelait `lsof` pour identifier le processus responsable. Cependant, pour des commandes très rapides comme `cat` (qui lit un petit fichier en quelques microsecondes), le fichier était déjà fermé au moment où `lsof` s'exécutait, ce qui produisait des alertes incomplètes :
```
ALERT : canary accessed — pid=unknown process=unknown
```

**Solution** : remplacement d'inotify par **fanotify** dans le module C `monitor_thread.c`. Contrairement à inotify, fanotify retourne dans la métadonnée de chaque événement le PID du processus ayant accédé au fichier, éliminant la course critique. Une boucle de retry (5 tentatives à 1 ms d'intervalle) a également été ajoutée dans le module Bash pour atténuer le problème dans les modes non-root.

## 2. Notifications desktop sous VirtualBox

**Problème** : la commande `notify-send` n'affichait aucune notification dans la machine virtuelle Kali Linux sous VirtualBox, sans message d'erreur.

**Solution** : ajout de l'export `DISPLAY=:0` dans `lib/alert.sh` afin que `notify-send` cible explicitement le serveur graphique X de la session active.

## 3. Permissions sur /var/log/canaryfs

**Problème** : par défaut, le programme tente de créer le répertoire `/var/log/canaryfs/` qui nécessite les privilèges root. Pour les utilisateurs non-root, le programme échouait au démarrage.

**Solution** : implémentation de l'option `-l` permettant de spécifier un répertoire de logs personnalisé (par exemple `-l /tmp/canaryfs_logs`). Une procédure d'installation alternative (création manuelle du répertoire avec `chown`) est documentée dans le README.

## 4. Différence entre threads et processus en Bash

**Problème** : Bash ne possède pas de véritables threads. L'utilisation de `&` (background jobs) crée des processus fils, pas des threads. Or le cahier des charges exige spécifiquement un mode « thread » distinct du mode « fork ».

**Solution** : implémentation du mode `-t` en C avec la bibliothèque pthreads. Le binaire `monitor_thread` est compilé automatiquement à la volée par le script Bash via `gcc -lpthread`. La distinction est vérifiable au runtime avec :
```bash
cat /proc/$(pgrep monitor_thread)/status | grep Threads
# Threads: 5    (un seul processus, plusieurs threads)
```

## 5. Bug de duplication de chemin dans monitor_file

**Problème** : les premières alertes en mode fork affichaient des chemins corrompus :
```
file=/tmp/honeypot/.env.env
file=/tmp/honeypot/id_rsaid_rsa
```

**Cause** : le format de sortie d'inotifywait est différent quand on surveille un seul fichier (chemin complet) versus un répertoire (path + filename séparés). Le code reconstruisait incorrectement le chemin.

**Solution** : passer directement la variable `target_file` à `_capture_forensics()` sans reconstruction lorsque la surveillance porte sur un fichier unique.

## 6. Watchers orphelins après Ctrl+C

**Problème** : après un `Ctrl+C`, des processus `inotifywait` restaient en arrière-plan, consommant des watches inotify et empêchant les exécutions ultérieures.

**Solution** : ajout d'un `trap cleanup SIGINT SIGTERM` dans le script principal. La fonction `cleanup()` utilise `pkill -P $$` pour tuer tous les enfants directs avant de quitter.

---

# Chapitre 7 : Perspectives et évolutions futures

Plusieurs pistes d'amélioration peuvent être envisagées pour faire évoluer canaryfs au-delà du périmètre académique :

- **Migration vers eBPF** : l'utilisation de programmes eBPF (extended Berkeley Packet Filter) attachés à des tracepoints noyau permettrait une détection encore plus fine et plus performante, avec un coût CPU minimal.
- **Interface web temps réel** : développement d'un tableau de bord (Flask + WebSockets) pour visualiser les alertes en direct, avec graphiques et historique consultable.
- **Intégration SIEM** : émission des alertes au format CEF (Common Event Format) ou Syslog RFC 5424 pour intégration directe avec **Wazuh**, **Splunk** ou **ELK Stack**.
- **Chiffrement des logs** : signature et chiffrement du fichier `history.log` (par exemple avec GPG) pour garantir son intégrité en cas d'attaque.
- **Templates dynamiques** : génération de canaries personnalisés selon le contexte (nom du serveur, faux numéros AWS uniques, faux endpoints DB) afin d'augmenter la crédibilité.
- **Support multi-plateforme** : portage vers **BSD** en utilisant `kqueue` à la place d'inotify, et vers **macOS** via `FSEvents`.
- **Mode conteneur** : version Docker qui surveille des volumes montés sans nécessiter de privilèges sur l'hôte.
- **Alerte par email / webhook** : ajout d'options `--email` et `--webhook` pour notifier des canaux externes (Slack, Discord, Mattermost).

---

# Conclusion générale

Le projet **canaryfs** a permis de développer un outil honeypot fonctionnel et performant qui détecte les accès non autorisés aux fichiers sensibles sous Linux. **Tous les objectifs du cahier des charges ont été atteints** : les **huit options** demandées sont implémentées (`-h`, `-f`, `-t`, `-s`, `-l`, `-r`, `-p`, `-a`), les trois modes d'exécution principaux (fork, threads, subshell) ainsi qu'un mode par défaut fonctionnent correctement, et la gestion des erreurs est assurée par cinq codes spécifiques conformes à la spécification.

Ce travail a permis de mettre en pratique l'ensemble des concepts du module Systèmes d'Exploitation : **programmation Shell** sous Linux, **gestion des processus** via `fork()` et `wait()`, **gestion des threads POSIX** via `pthread_create()` et `pthread_join()`, **utilisation des sous-systèmes noyau** comme inotify et fanotify, **gestion des signaux** avec `trap`, et **outils standards** comme `lsof`, `logger` et `getopts`.

Plusieurs difficultés ont été rencontrées et résolues au cours du développement, notamment la course critique entre inotify et lsof (résolue par l'adoption de fanotify), les problèmes de permissions et de notifications desktop sous VirtualBox, ainsi que la distinction technique entre threads et processus en Bash.

Le mode thread, basé sur fanotify et pthreads, offre les meilleures performances avec un temps de détection de seulement 2 ms, une capture forensique atomique et fiable, et un coût en ressources minimal grâce au partage de mémoire entre threads. Pour 200 canaries, il est environ **trois fois plus rapide** que le mode fork.

Au-delà de l'aspect académique, **canaryfs** est un outil prêt à être utilisé en environnement réel, avec un dépôt GitHub public, une documentation complète et un script de démonstration interactif. Il constitue une base solide pour de futures évolutions vers eBPF, SIEM et l'intégration cloud.

---

## Glossaire

- **Canary file / Canary token** : fichier leurre placé volontairement dans un système pour détecter un accès non autorisé. Le terme provient des « canaris dans la mine », sentinelles qui alertaient les mineurs des fuites de gaz.
- **fanotify** : sous-système noyau Linux ≥ 2.6.36 permettant la surveillance des accès au système de fichiers avec PID intégré dans les événements.
- **Forensique (analyse)** : collecte et analyse de preuves numériques après un incident de sécurité (qui, quoi, quand, comment).
- **getopts** : commande Bash intégrée pour l'analyse des arguments en ligne de commande, conforme POSIX.
- **Honeypot** : système ou ressource appâtant volontairement les attaquants pour les détecter ou les étudier.
- **inotify** : sous-système noyau Linux pour la surveillance d'événements sur le système de fichiers (open, read, write, etc.).
- **lsof** (List Open Files) : commande Linux qui liste les fichiers ouverts par chaque processus.
- **PID** (Process IDentifier) : identifiant numérique unique d'un processus.
- **PPID** (Parent Process ID) : PID du processus parent.
- **pthread** (POSIX Thread) : standard POSIX pour les threads, offrant `pthread_create()`, `pthread_join()`, `pthread_mutex_*` etc.
- **Race condition** : situation où le résultat d'un programme dépend de l'ordre relatif d'exécution de plusieurs entités concurrentes.
- **SIEM** (Security Information and Event Management) : système centralisant et analysant les événements de sécurité (Wazuh, Splunk, ELK).
- **syslog** : protocole et démon standard de journalisation système sous UNIX/Linux.
- **trap** : commande Bash permettant d'intercepter des signaux (SIGINT, SIGTERM) et d'exécuter une fonction de nettoyage.
- **UID** (User IDentifier) : identifiant numérique d'un utilisateur Linux.

---

## Bibliographie

1. **Kerrisk, M.** *The Linux Programming Interface*. No Starch Press, 2010.
2. **Manuel Linux** : `inotify(7)`, `fanotify(7)`, `pthreads(7)`, `lsof(8)`, `getopts(1)`, `bash(1)`. https://man7.org/linux/man-pages/
3. **Kernel.org** : *Linux Kernel Documentation — fanotify*. https://www.kernel.org/doc/Documentation/filesystems/fanotify.txt
4. **Robbins, A. & Beebe, N. H. F.** *Classic Shell Scripting*. O'Reilly Media, 2005.
5. **Thinkst Canary** : *Documentation Canary Tokens*. https://canarytokens.org/
6. **OWASP Foundation** : *Intrusion Detection*. https://owasp.org/
7. **Cours de Systèmes d'Exploitation**, M. Ouaguid Abdellah, ENSET Mohammedia, 2025-2026.

---

## Annexes

### Annexe A — Sortie de `./canaryfs -h`

```
NAME
    canaryfs — Honeypot Canary File System Monitor

SYNOPSIS
    canaryfs [OPTIONS] <target_directory>

OPTIONS
    -h          Show this help message and exit
    -f          Monitor using fork (one child process per canary)
    -t          Monitor using POSIX threads (C/pthreads + fanotify)
    -s          Monitor in a background subshell (daemon mode)
    -l <dir>    Custom log directory (default: /var/log/canaryfs)
    -r          Remove all planted canaries — ROOT ONLY
    -p <n>      Number of canary files to plant (default: 10)
    -a          Alert mode: write to syslog + send desktop notification
```

### Annexe B — Extrait de `parse_args()` (canaryfs)

```bash
parse_args() {
    local opt
    while getopts ":hftsal:rp:" opt; do
        case "${opt}" in
            h) show_help; exit 0 ;;
            f) EXEC_MODE="fork" ;;
            t) EXEC_MODE="thread" ;;
            s) EXEC_MODE="subshell" ;;
            a) ALERT_MODE=true ;;
            l) LOG_DIR="${OPTARG}"; LOG_FILE="${LOG_DIR}/history.log" ;;
            r) run_restore; exit $? ;;
            p) CANARY_COUNT="${OPTARG}" ;;
            :) log_error "Option -${OPTARG} requires an argument"; show_help; exit 101 ;;
            ?) log_error "Unknown option: -${OPTARG}";             show_help; exit 100 ;;
        esac
    done
    shift $((OPTIND - 1))
    TARGET_DIR="$1"
}
```

### Annexe C — Boucle pthread_create (monitor_thread.c)

```c
for (int i = 0; i < n; i++) {
    WatchArgs *w = malloc(sizeof(WatchArgs));
    strncpy(w->file,     argv[i + 2], 511);
    strncpy(w->log_file, log_file,    511);
    pthread_create(&threads[i], NULL, watch_file, w);
}

for (int i = 0; i < n; i++)
    pthread_join(threads[i], NULL);
```

### Annexe D — Trap de nettoyage (canaryfs)

```bash
cleanup() {
    log_info "Received signal — stopping all watchers..."
    pkill -P $$ inotifywait     2>/dev/null
    pkill -P $$ monitor_thread  2>/dev/null
    pkill -P $$ -f monitor_file 2>/dev/null
    log_info "canaryfs stopped cleanly"
    exit 0
}
trap cleanup SIGINT SIGTERM
```

### Annexe E — Exemple de log complet

```
2026-05-08-09-02-06 : kali : INFOS : Compiling monitor_thread.c ...
2026-05-08-09-02-06 : kali : INFOS : Compiled: /home/kali/projet-sys/lib/monitor_thread
2026-05-08-09-02-06 : kali : INFOS : Starting canaryfs on /tmp/honeypot [mode: thread]
2026-05-08-09-02-06 : kali : INFOS : Planting 3 canary files in /tmp/honeypot
2026-05-08-09-02-06 : kali : INFOS : Planted: /tmp/honeypot/id_rsa
2026-05-08-09-02-06 : kali : INFOS : Planted: /tmp/honeypot/.env
2026-05-08-09-02-06 : kali : INFOS : Planted: /tmp/honeypot/credentials.json
2026-05-08-09-02-06 : kali : INFOS : Done — 3 canary files planted
2026-05-08-09-02-06 : kali : INFOS : Mode: thread — POSIX pthreads via C
2026-05-08-09-04-17 : kali : ALERT : canary accessed — file=/tmp/honeypot/.env event=OPEN pid=4630 process=zsh uid=1000 ppid=1497
```
