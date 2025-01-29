#!/bin/bash

set -u # to verify variables are defined
: $SDWNS

echo "1. Configuración inicial"
cd bin
chmod +x *
./prepare-k8slab
source ~/.bashrc
echo $SDWNS
echo "--- Compobamos que están creadas las correspondientes Network Attachment Definitions de Multus"
microk8s kubectl get -n $SDWNS network-attachment-definitions

echo "2. Creamos el servidor nginx y arrancamos el escenario"
cd ..
cd vnx
docker run --restart always --name helm-repo -p 8080:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx
sudo vnx -f sdedge_nfv.xml -t

echo "3. Creamos y arrancamos los contenedores para las KNFs"
cd ..
./sdedge1.sh
bin/sdw-knf-consoles open 1
./sdedge2.sh
bin/sdw-knf-consoles open 2

echo "4. Obtenemos los comandos para ejecutar el navegador Firefox con acceso al controlador SDN"
./sdwan1.sh
./sdwan2.sh
