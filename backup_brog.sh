#!/bin/bash

# Configuration
WORK_DIR="/work/"
BACKUP_DIR="/backup/"
MAX_BACKUPS=5  # Remplace N par la valeur souhaitée
LOG_FILE="/var/log/backup_borg.log"
EXCLUDE_PATTERNS=("*.tmp" "*.log" "*.cache")
CRON_JOB="0 6 * * * /home/backup_borg.sh"



# Fonction pour logger les messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier et configurer cron si nécessaire
setup_cron() {
        # Vérifier si la tâche cron existe déjà
        if ! crontab -l 2>/dev/null | grep -qF "$CRON_JOB"; then
            log "Configuration de la tâche cron pour les sauvegardes automatiques à 6h..."
            (crontab -l 2>/dev/null; echo "$CRON_JOB") 
            log "Tâche cron ajoutée : $CRON_JOB"
        else
            log "La tâche cron est déjà configurée pour s'exécuter à 6h."
        fi
}

# Exécuter la configuration cron
setup_cron

# Créer le répertoire de sauvegarde avec le format YYYY-MM-DD_HHMM
CURRENT_BACKUP_NAME=$(date '+%Y-%m-%d_%H%M')
CURRENT_BACKUP_DIR="$BACKUP_DIR/$CURRENT_BACKUP_NAME"
mkdir -p "$CURRENT_BACKUP_DIR"

# Initialiser le dépôt Borg dans le dossier de sauvegarde actuel
BORG_REPO="$CURRENT_BACKUP_DIR/borg_repo"
log "Initialisation du dépôt Borg dans $BORG_REPO..."
borg init --encryption=none "$BORG_REPO"
if [ $? -ne 0 ]; then
    log "Erreur : Impossible d'initialiser le dépôt Borg."
    exit 1
fi

# Créer une sauvegarde incrémentielle avec Borg
log "Début de la sauvegarde Borg pour $WORK_DIR..."
borg create "$BORG_REPO::sauvegarde" "$WORK_DIR" \
    --exclude-from <(printf "%s\n" "${EXCLUDE_PATTERNS[@]}") \
    --stats --progress > "$CURRENT_BACKUP_DIR/borg_log.txt" 2>&1

if [ $? -ne 0 ]; then
    log "Erreur : La sauvegarde Borg a échoué. Voir $CURRENT_BACKUP_DIR/borg_log.txt pour plus de détails."
    rm -rf "$CURRENT_BACKUP_DIR"  # Supprimer la sauvegarde incomplète
    exit 1
fi

# Compter le nombre de fichiers sauvegardés
NUM_FILES=$(borg list "$BORG_REPO::sauvegarde" | wc -l)
log "Nombre de fichiers sauvegardés : $NUM_FILES"

# Gérer la rotation des sauvegardes (supprimer les plus anciennes si > MAX_BACKUPS)
BACKUP_COUNT=$(ls -d "$BACKUP_DIR"/2[0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]_[0-2][0-9][0-5][0-9] 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    NUM_TO_DELETE=$((BACKUP_COUNT - MAX_BACKUPS))
    log "Suppression des $NUM_TO_DELETE sauvegardes les plus anciennes..."
    ls -t "$BACKUP_DIR" | grep -E '2[0-9]{3}-[01][0-9]-[0-3][0-9]_[0-2][0-9]{3}' | tail -n "$NUM_TO_DELETE" | while read -r old_backup; do
        rm -rf "$BACKUP_DIR/$old_backup"
        log "Suppression de la sauvegarde : $old_backup"
    done
fi

log "Sauvegarde terminée avec succès dans $CURRENT_BACKUP_DIR."
