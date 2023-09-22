#!/bin/bash
# Comprueba si existe el fichero .env
test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }
# Carga las variables de entorno del fichero .env
set -o allexport && source ./.env && set +o allexport

# Función para recorrer carpetas y ejecutar stash y push
function recorrer_y_stash_push() {
  for carpeta in "${SERVER_PATH}/www/*"; do
    if [ -d "$carpeta/.git" ]; then
      # Esta carpeta es un repositorio Git
      echo "Git stash realizado en $carpeta." 
      git stash push -u
    fi
  done
}


# Comprueba si hay cambios en el repositorio principal
if [[ `git status --porcelain` ]]; 
then
  docker-compose exec -T "${ME_CONFIG_MONGODB_SERVER}" mongodump --out ./docker-entrypoint-initdb.d/db-dump -u ${MONGO_INITDB_ROOT_USERNAME} -p ${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin
  docker-compose exec mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > ./mariadb/db-dump/mariadb-dump.sql
  # Ejecuta el stash push para guardar los cambios
  echo "Git stash realizado repositorio principal." 
  git stash push -u
  recorrer_y_stash_push
fi
# Ejecuta el docker compose down para parar y borrar los contenedores
exec docker compose down -v