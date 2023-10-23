#!/bin/bash

# Función para mostrar mensajes de error y salir
error_exit() {
  echo -e "\033[0;31m[ERROR]\033[0m $1. Saliendo.."
  exit 1
}

# Función para clonar o actualizar un repositorio
clone_or_update_repository() {
  local repo_url="$1"
  local repo_name=$(basename "$repo_url" .git)
  local repo_path="$SERVER_PATH/www/$repo_name"

  if [ -d "$repo_path" ]; then
    echo "Actualizando el repositorio $repo_name desde $repo_url."
    (cd "$repo_path" && git pull --rebase)
  else
    echo "Clonando el repositorio $repo_name desde $repo_url."
    git clone "$repo_url" "$repo_path"
  fi
}

# Verificar si existen .env, .services y .repositories
for file in .env .services .repositories; do
  [ -f "./$file" ] || error_exit "No existe el archivo $file"
done

# Cargar variables de entorno
set -o allexport
source ./.env
source ./.services
source ./.repositories
set +o allexport

# Loop para recorrer los repositorios
for repo_url in "${REPOSITORIES[@]}"; do
  clone_or_update_repository "$repo_url"
  repo_name=$(basename "$repo_url" .git)
  repo_path="$SERVER_PATH/www/$repo_name"
done

# Ejecuta el docker compose
echo -e "\033[0;32m[INFO]\033[0m Arrancando los servicios: ${SERVICES[@]}"
exec docker compose up -d "$@" "${SERVICES[@]}"