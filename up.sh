#!/bin/bash
# Comprueba si existe el fichero .env y .services
test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }
test ! -f ./.services && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .services. Saliendo.." ; exit; }
# Carga las variables de entorno del fichero .env
set -o allexport && source ./.env && source ./.services && set +o allexport

# Función para leer las URL de los repositorios desde .repositories
read_repositories() {
  if [ -f ./.repositories ]; then
    mapfile -t REPO_URLS < ./.repositories
  else
    echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .repositories. Saliendo.."
    exit 1
  fi
}

# Función para verificar si un repositorio existe y realizar un git pull o git clone
update_repository() {
  local repo_url="$1"
  local repo_name="${repo_url##*/}"  # Obtiene la última parte de la URL como nombre del repositorio
  local repo_name="${repo_name%.git}" # Elimina ".git" de la última parte

  local repo_path="${SERVER_PATH}/www/${repo_name}"

  if [ -d "$repo_path/.git" ]; then
    # Muestra un mensaje de pull
    echo "Git Pull realizado en $repo_name." 
    # Ejecuta el pull rebase para actualizar el repositorio
    cd "$repo_path" || return
    git pull --rebase
    git stash pop
    git stash drop
    cd - || return
  else
    # Si no existe, clona el repositorio con nombre de usuario y contraseña
    local encoded_username="$(printf %s "$GITHUB_USER" | sed 's/[@.]/%2/g')"
    local encoded_password="$(printf %s "$GITHUB_PASSWORD" | sed 's/[@.]/%2/g')"
    local repo_url_with_auth="https://${encoded_username}:${encoded_password}@${repo_url}"
    echo "Clonando el repositorio $repo_name desde $repo_url."
    git clone "$repo_url_with_auth" "$repo_path"
  fi
}

# Muestra un mensaje de pull
echo "Git Pull realizado." 
# Ejecuta el pull rebase para actualizar el repositorio
git pull --rebase 
# Ejecuta el stash pop y drop para actualizar y eliminar los cambios locales
git stash pop
git stash drop

# Lee las URLs de los repositorios desde .repositories
read_repositories

# Itera sobre las URLs de los repositorios y actualiza cada uno
for repo_url in "${REPO_URLS[@]}"; do
  update_repository "$repo_url"
done

# Ejecuta el docker compose
echo -e "\033[0;32m[INFO]\033[0m Arrancando los servicios: ${SERVICES[@]}"
exec docker compose up -d "$@" "${SERVICES[@]}"