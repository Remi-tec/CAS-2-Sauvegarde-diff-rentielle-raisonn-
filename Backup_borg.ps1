# --- 1. VARIABLES DE CONFIGURATION ---
$BASE_PROJECT     = "D:\SupDeVinci\Cours\2025-2026\Scripting\Zone_de_test"
$WORK_DIR         = "$BASE_PROJECT\work"
$BACKUP_DIR       = "$BASE_PROJECT\backup"
$LOG_DIR          = "$BASE_PROJECT\log"
$LOG_FILE         = "$LOG_DIR\borg_backup.log"
$MAX_BACKUPS      = 5
$EXCLUDE_PATTERNS = "*.tmp", "*.log", "*.cache"
$TASK_NAME        = "BorgBackupTask"
$SCRIPT_PATH      = $PSCommandPath
 
# --- 2. FONCTION DE LOG ---
function Write-Log($Message){
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LOG_FILE -Value $LogEntry -Encoding UTF8
}
 
# --- 3. CRÉATION DES RÉPERTOIRES ---
foreach ($Dir in ($BACKUP_DIR, $LOG_DIR)) {
    if (-not (Test-Path $Dir)) {
        New-Item -Path $Dir -ItemType Directory -Force | Out-Null
        Write-Host "Répertoire créé : $Dir" -ForegroundColor Cyan
    }
}
 
# Traduction des chemins pour WSL
$WslWorkPath   = "/mnt/d/" + $WORK_DIR.Replace("D:\", "").Replace("\", "/")
$WslBackupPath = "/mnt/d/" + $BACKUP_DIR.Replace("D:\", "").Replace("\", "/")
 
# --- 4. INITIALISATION DE BORG ---
if (-not (Test-Path "$BACKUP_DIR\config")) {
    Write-Host "Initialisation du dépôt Borg..." -ForegroundColor Yellow
    wsl borg init --encryption=none $WslBackupPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Échec de l'initialisation. Vérifiez WSL."
        return # On arrête le script si l'init échoue
    }
}
 
# --- 5. CONFIGURATION DU PLANIFICATEUR ---
$ExistingTask = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($null -ne $ExistingTask) {
    Write-Host "La tâche '$TASK_NAME' existe déjà." -ForegroundColor Yellow
}
else {
    try {
        $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SCRIPT_PATH`""
        $Trigger = New-ScheduledTaskTrigger -Daily -At 6am
        Register-ScheduledTask -TaskName $TASK_NAME -Action $Action -Trigger $Trigger -User "SYSTEM" -RunLevel Highest | Out-Null
        Write-Host "Planificateur configuré : Exécution quotidienne à 06:00." -ForegroundColor Green
    }
    catch {
        Write-Error "Erreur lors de la création de la tâche : $($_.Exception.Message)"
    }
}
 
# --- 6. EXÉCUTION DE LA SAUVEGARDE ---
Write-Log "--- Démarrage de la sauvegarde Borg ---"
$ExcludeArgs = ""
foreach ($Pattern in $EXCLUDE_PATTERNS) { $ExcludeArgs += "--exclude '$Pattern' " }
$SauvegardeName = "sauvegarde-" + (Get-Date -Format "yyyy-MM-dd_HH:mm")
Write-Log "Création de la sauvegarde : $SauvegardeName"
$BorgCommand = "borg create $WslBackupPath::$SauvegardeName $WslWorkPath $ExcludeArgs --stats"
wsl bash -c "$BorgCommand" 2>&1 | ForEach-Object {
    Write-Log $_
}
# --- 7. VÉRIFICATION ET STATISTIQUES ---
if ($LASTEXITCODE -eq 0) {
    Write-Log "SUCCÈS : Sauvegarde terminée correctement."
    # On capture tout ce que Borg raconte
    $Stats = wsl borg info "$WslBackupPath::$SauvegardeName" 2>&1
    # On cherche la ligne qui contient "Number of files" et on nettoie tout sauf les chiffres
    $StatLine = $Stats | Where-Object { $_ -like "*Number of files*" }
    if ($StatLine) {
        # On ne garde que les chiffres de la ligne
        $NbFichiers = $StatLine -replace "[^0-9]", ""
        Write-Log "Statistiques : $NbFichiers fichiers sauvegardés."
        Write-Host "Nombre de fichiers traités : $NbFichiers" -ForegroundColor Green
    } else {
        Write-Log "Statistiques : Information non trouvée dans le résumé Borg."
    }
    # --- 8. ROTATION (Seulement si succès) ---
    Write-Log "Rotation : Conservation des $MAX_BACKUPS dernières sauvegardes."
    $PruneResult = wsl bash -c "borg prune --keep-last $MAX_BACKUPS --list $WslBackupPath"
    if ($PruneResult) { Write-Log "Sauvegardes supprimées : $PruneResult" }
 
} else {
    Write-Log "ERREUR : La sauvegarde a échoué (Code: $LASTEXITCODE). Nettoyage de l'archive..."
    wsl borg delete "$WslBackupPath::$SauvegardeName"
}
 
Write-Log "--- Fin de la sauvegarde Borg ---`n"
 