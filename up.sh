#!/bin/bash

# Función para mostrar mensajes de error y salir
error_exit() {
  echo -e "\033[0;31m[ERROR]\033[0m $1. Saliendo.."
  exit 1
}

# Función para obtener las variables de un repositorio
get_repo_vars() {
  local repo_url="$1"
  local repo_name=$(basename "$repo_url" .git)
  local repo_path="$SERVER_PATH/www/$repo_name"
  local repo_vars=("$repo_name" "$repo_url" "$repo_path")
  echo "${repo_vars[@]}"
}

# Función para clonar o actualizar un repositorio
clone_or_update_repository() {
  local repo_name="${repo_info[0]}"
  local repo_url="${repo_info[1]}"
  local repo_path="${repo_info[2]}"

  if [ -d "$repo_path" ]; then
    echo "Actualizando el repositorio $repo_name desde $repo_url."
    # Ejecuta el pull rebase para actualizar el repositorio
    (cd "$repo_path" && git pull --rebase && git stash pop && git stash drop)
  else
    # Si no existe, clona el repositorio con nombre de usuario y contraseña
    local repo_url_with_auth="https://${GITHUB_TOKEN}@${repo_url#https://}"
    echo "Clonando el repositorio $repo_name desde $repo_url."
    git clone "$repo_url_with_auth" "$repo_path"
  fi
}

# Función para buscar archivos docker-compose.yml en los directorios y ejecutar docker-compose up si se encuentra
find_and_up_docker_compose() {
  local repo_path="${repo_info[2]}"
  local docker_compose_file="$repo_path/docker-compose.yml"
  
  if [ -f "$docker_compose_file" ]; then
    if [ -z "$APP_PORT" ]; then
      error_exit "La variable APP_PORT no está definida en .env"
    fi
    # Incrementar el puerto en el archivo .env principal
    (($APP_PORT++))
    sed -i "s/APP_PORT=.*/APP_PORT=$APP_PORT/" $repo_path/.env

    echo "Ejecutando docker-compose up en $docker_compose_file."
    (cd "$repo_path" && docker-compose up -d)
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
repo_info=()
# Loop para recorrer los repositorios
for repo_url in "${REPOSITORIES[@]}"; do
  repo_info=($(get_repo_vars "$repo_url"))
  clone_or_update_repository
  find_and_up_docker_compose
done

# Ejecuta el docker compose
echo -e "\033[0;32m[INFO]\033[0m Arrancando los servicios: ${SERVICES[@]}"
exec docker compose up -d "$@" "${SERVICES[@]}"