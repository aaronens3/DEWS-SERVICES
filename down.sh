#!/bin/bash

# Función para mostrar un mensaje de error y salir
function mostrar_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1. Saliendo.."
  exit 1
}

# Función para comprobar la existencia de un archivo
function comprobar_archivo() {
  if [ ! -f "$1" ]; then
    mostrar_error "No existe el archivo $1"
  fi
}

# Función para ejecutar stash y push en una carpeta
function ejecutar_stash_push() {
  local carpeta="$1"
  if [ -d "$carpeta/.git" ]; then
    echo "Git stash realizado en $carpeta." 
    git -C "$carpeta" stash push -u
  fi
}

# Cargar variables de entorno desde el archivo .env
comprobar_archivo .env
set -o allexport && source .env && set +o allexport

# Comprobar si hay cambios en el repositorio principal
if git status --porcelain | grep -q .; then
  docker-compose exec -T "$MONGO_SERVER" mongodump --out ./docker-entrypoint-initdb.d/db-dump -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin
  docker-compose exec mariadb mysqldump -u root -p"$MARIADB_ROOT_PASS" --all-databases > ./mariadb/db-dump/mariadb-dump.sql
  # Ejecuta el stash push para guardar los cambios
  echo "Git stash realizado en el repositorio principal." 
  git stash push -u
  for carpeta in "${SERVER_PATH}/www/"*; do
    ejecutar_stash_push "$carpeta"
  done
fi
# Ejecuta el docker compose down para parar y borrar los contenedores
exec docker compose down -v