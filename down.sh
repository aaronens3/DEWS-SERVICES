#!/bin/bash
# Comprueba si existe el fichero .env
test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }
# Carga las variables de entorno del fichero .env
set -o allexport && source ./.env && set +o allexport
# Comprueba si hay cambios en el repositorio
if [[ `git status --porcelain` ]]; 
then
  docker-compose exec -T "${ME_CONFIG_MONGODB_SERVER}" mongodump --out ./docker-entrypoint-initdb.d/db-dump -u ${MONGO_INITDB_ROOT_USERNAME} -p ${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin
  docker-compose exec mariadb mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > ./mariadb/db-dump/mariadb-dump.sql
  # Ejecuta el stash push para guardar los cambios
  echo "Git stash realizado." 
  git stash push -u
fi
# Ejecuta el docker compose down para parar y borrar los contenedores
exec docker compose down -v