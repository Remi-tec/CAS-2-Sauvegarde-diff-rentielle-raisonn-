import os
import random
import string
from datetime import datetime, timedelta

# Configuration
WORK_DIR = "/work/"
FILE_EXTENSIONS = [".txt", ".pdf", ".docx", ".xlsx", ".tmp", ".log", ".cache", ".jpg", ".png"]
NUM_FILES = 20  # Nombre total de fichiers à générer
NUM_DIRS = 3    # Nombre de sous-dossiers à créer

def generate_random_string(length=10):
    """Génère une chaîne aléatoire pour le contenu des fichiers."""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def generate_file(path, extension):
    """Génère un fichier avec un contenu aléatoire."""
    content = generate_random_string(100)  # Contenu aléatoire de 100 caractères
    with open(path + extension, "w") as f:
        f.write(content)

def generate_work_content():
    """Génère des fichiers et des sous-dossiers dans /work/."""
    if not os.path.exists(WORK_DIR):
        os.makedirs(WORK_DIR)
        print(f"Répertoire {WORK_DIR} créé.")

    # Générer des fichiers dans le répertoire racine
    for i in range(NUM_FILES):
        file_name = f"file_{i}"
        extension = random.choice(FILE_EXTENSIONS)
        generate_file(os.path.join(WORK_DIR, file_name), extension)

    # Générer des sous-dossiers et des fichiers
    for i in range(NUM_DIRS):
        dir_name = f"subdir_{i}"
        dir_path = os.path.join(WORK_DIR, dir_name)
        os.makedirs(dir_path, exist_ok=True)

        for j in range(NUM_FILES // NUM_DIRS):
            file_name = f"subfile_{i}_{j}"
            extension = random.choice(FILE_EXTENSIONS)
            generate_file(os.path.join(dir_path, file_name), extension)

    print(f"Contenu généré dans {WORK_DIR} avec succès.")

if __name__ == "__main__":
    generate_work_content()
