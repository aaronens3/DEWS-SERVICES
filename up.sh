#!/bin/bash
# Comprueba si existe el fichero .env
test ! -f ./.env && { echo -e "\033[0;31m[ERROR]\033[0m No existe el fichero .env. Saliendo.." ; exit; }
# Carga las variables de entorno del fichero .env
set -o allexport && source ./.env && set +o allexport
# Muestra un mensaje de pull
echo "Git Pull realizado." 
# Ejecuta el pull rebase para actualizar el repositorio
git pull --rebase 
# Ejecuta el stash pop y drop para actualizar y eliminar los cambios locales
git stash pop
git stash drop
# Ejecuta el docker compose
exec docker compose up -d