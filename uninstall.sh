#!/bin/bash

set -u # to verify variables are defined
: $SDWNS

# HELM SECTION
echo "1. Desinstalando contenedores"
for NETNUM in {1..2}
do
  for VNF in access cpe wan ctrl
  do
    helm -n $SDWNS uninstall $VNF$NETNUM 
  done
done

microk8s kubectl delete deployments --all

# PARAR ESCENARIO
echo "2. Destruyendo escenario"
cd vnx
sudo vnx -f sdedge_nfv.xml --destroy
cd ..

# ELIMINAR SERVIDOR NGINX
echo "3. Eliminando servidor nginx"
docker stop helm-repo
docker rm helm-repo

# ELIMINAR NAMESPACE
echo "4. Eliminando namespace"
microk8s kubectl delete namespace $SDWNS
