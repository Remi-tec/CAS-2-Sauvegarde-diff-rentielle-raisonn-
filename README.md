# CAS-2-Sauvegarde-diff-rentielle-raisonn- Par Kelvia et Remi
## 📌 Description
Ce projet automatise la sauvegarde du répertoire `/work/` vers `/backup/` en utilisant **BorgBackup** pour des sauvegardes **incrémentielles, compressées et sécurisées**. Il inclut également un script Python pour générer des fichiers de test dans `/work/`, afin de simuler un environnement de travail réaliste.

---

## 📋 Prérequis

### Système d'Exploitation
- **Linux** (testé sur Debian/Ubuntu, Fedora, etc.).

### Dépendances
- **Python 3** (pour générer le contenu de `/work/`).
- **BorgBackup** (pour les sauvegardes incrémentielles).
- **Cron** (pour planifier les sauvegardes automatiques).

#### Installation des Dépendances

**Sur Debian/Ubuntu :**
```bash
sudo apt-get update
sudo apt-get install -y python3 borgbackup

/
├── work/                  # Répertoire source à sauvegarder
│   ├── fichiers/          # Fichiers générés automatiquement
│   └── sous-dossiers/     # Sous-dossiers avec fichiers
│
├── backup/                # Répertoire de destination des sauvegardes
│   ├── YYYY-MM-DD_HHMM/   # Dossier de sauvegarde (ex: 2026-01-20_1430)
│   │   └── borg_repo/     # Dépôt Borg contenant les sauvegardes
│   └── ...
│
└── home/
    ├── backup_borg.sh     # Script de sauvegarde avec Borg
    └── generate_work_content.py  # Script Python pour générer des fichiers dans /work/
