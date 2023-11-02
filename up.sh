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

# Función para crear una red personalizada
create_custom_network() {
  local network_name="$1"
  if ! docker network inspect "$network_name" &> /dev/null; then
    echo "Creando la red personalizada $network_name."
    docker network create "$network_name"
  fi
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
    # Verificar si existe .env.example y copiarlo a .env
  fi
  if [ -f "$repo_path/.env.example" ] && [ ! -f "$repo_path/.env" ]; then
    echo "Copiando .env.example a .env en $repo_path."
    cp "$repo_path/.env.example" "$repo_path/.env"
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
    APP_PORT=$((APP_PORT + 1))
    VITE_PORT=$((VITE_PORT + 1))
    # Verificar si APP_PORT está definido en el archivo .env
    if grep -q "APP_PORT=" $repo_path/.env; then
      # APP_PORT existe, actualizar su valor
      sed -i "s/APP_PORT=.*/APP_PORT=$APP_PORT/" $repo_path/.env
      sed -i "s/VITE_PORT=.*/VITE_PORT=$VITE_PORT/" $repo_path/.env
    else
      # APP_PORT no existe, agregarlo con el valor predeterminado
      echo "APP_PORT=$APP_PORT" >> $repo_path/.env
      echo "VITE_PORT=$VITE_PORT" >> $repo_path/.env
    fi
    if grep -q "APP_NAME=" $repo_path/.env; then
      sed -i "s/APP_NAME=.*/APP_NAME=${repo_info[0]}/" $repo_path/.env
    else
      echo "APP_NAME=${repo_info[0]}" >> $repo_path/.env
    fi
    if grep -q "NETWORK=" $repo_path/.env; then
      sed -i "s/NETWORK=.*/NETWORK=$NETWORK/" $repo_path/.env
    else
      echo "NETWORK=$NETWORK" >> $repo_path/.env
    fi
    # Ejecutar docker-compose up
    echo "Ejecutando docker-compose up en $docker_compose_file."
    (cd "$repo_path" && docker-compose up composer && ./vendor/bin/sail up -d)
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

# Crear una red personalizada
create_custom_network "$NETWORK"

# Loop para recorrer los repositorios
for repo_url in "${REPOSITORIES[@]}"; do
  repo_info=($(get_repo_vars "$repo_url"))
  clone_or_update_repository  
  find_and_up_docker_compose
done

# Ejecuta el docker compose
echo -e "\033[0;32m[INFO]\033[0m Arrancando los servicios: ${SERVICES[@]}"
docker compose up -d "$@" "${SERVICES[@]}"
