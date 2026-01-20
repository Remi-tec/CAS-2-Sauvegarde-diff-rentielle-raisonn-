############################################
# CONFIGURATION GÉNÉRALE
############################################

$sourceDir     = "D:\SupDeVinci\Cours\2025-2026\Scripting\Zone_de_test\work"
$repoDir       = "C:\backup\repo"
$logDir        = "C:\logs"
$logFile       = "$logDir\backup_restic.log"
$resticLogFile = "$logDir\restic_log.txt"

$maxSnapshots  = 5
$resticPassword = "root"  # Mot de passe simple (Restic impose le chiffrement)

############################################
# CONFIGURATION DE LA TÂCHE PLANIFIÉE
############################################

$taskName   = "ResticBackupTask"
$scriptPath = "D:\SupDeVinci\Cours\2025-2026\Scripting\backup_restic.ps1"

$taskAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$taskTrigger = New-ScheduledTaskTrigger -Daily -At 6am

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($null -eq $existingTask) {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $taskAction `
        -Trigger $taskTrigger `
        -RunLevel Highest `
        -Force

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Tâche planifiée créée : $taskName (06:00)."
}

############################################
# CRÉATION DES DOSSIERS NÉCESSAIRES
############################################

foreach ($dir in @($logDir, $repoDir)) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

############################################
# FONCTION DE LOG
############################################

function Log {
    param ([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"

    $entry | Out-File -FilePath $logFile -Append
    Write-Output $entry
}

############################################
# GESTION DU MOT DE PASSE RESTIC
############################################

$passwordFile = "$env:TEMP\restic_password.txt"
Set-Content -Path $passwordFile -Value $resticPassword -NoNewline

############################################
# INITIALISATION DU DÉPÔT RESTIC (SI NÉCESSAIRE)
############################################

if (!(Test-Path "$repoDir\config")) {
    Log "Dépôt Restic non initialisé. Initialisation en cours..."
    & restic -r $repoDir --password-file $passwordFile init >> $resticLogFile 2>&1

    if ($LASTEXITCODE -ne 0) {
        Log "ERREUR : échec de l'initialisation du dépôt Restic."
        Remove-Item $passwordFile -Force
        exit 1
    }

    Log "Dépôt Restic initialisé avec succès."
} else {
    Log "Dépôt Restic déjà initialisé."
}

############################################
# SAUVEGARDE RESTIC
############################################

$backupTag = "backup_$(Get-Date -Format 'yyyy-MM-dd_HHmm')"
Log "Début de la sauvegarde de $sourceDir..."

& restic -r $repoDir `
    --password-file $passwordFile `
    backup "$sourceDir" `
    --tag $backupTag `
    --verbose >> $resticLogFile 2>&1

if ($LASTEXITCODE -ne 0) {
    Log "ERREUR : la sauvegarde Restic a échoué."
    Remove-Item $passwordFile -Force
    exit 1
}

############################################
# LISTE DES SNAPSHOTS
############################################

Log "Snapshots présents dans le dépôt :"
& restic -r $repoDir --password-file $passwordFile snapshots >> $resticLogFile 2>&1

############################################
# NETTOYAGE DES ANCIENS SNAPSHOTS
############################################

Log "Nettoyage : conservation des $maxSnapshots snapshots les plus récents."
& restic -r $repoDir `
    --password-file $passwordFile `
    forget --keep-last $maxSnapshots --prune >> $resticLogFile 2>&1

############################################
# NETTOYAGE FINAL
############################################

Remove-Item -Path $passwordFile -Force
Log "Sauvegarde Restic terminée avec succès."
