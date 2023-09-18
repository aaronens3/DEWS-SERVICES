#!/bin/bash
# Comprueba si existe el fichero .env
test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }
# Carga las variables de entorno del fichero .env
set -o allexport && source ./.env && set +o allexport
# Comprueba si hay cambios en el repositorio
if [[ `git status --porcelain` ]]; 
then
  # Ejecuta el stash push para guardar los cambios
  echo "Git stash realizado." 
  git stash push -u
fi
# Ejecuta el docker compose down para parar y borrar los contenedores
exec docker compose down