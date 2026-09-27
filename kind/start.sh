#!/bin/bash
CLUSTERNAME=k8s-1.37

mkdir -p ~/.kube
mkdir -p ../checkpoints/

# Create the network if it doesn't exist
if ! sudo docker network ls --format '{{.Name}}' | grep -q 'kind'; then
  sudo docker network create kind
fi 

# Start the cache if not already running, useful to re-create the cluster without hitting rate limits
if ! sudo docker ps --format '{{.Names}}' | grep -q 'proxy-docker-hub'; then
  sudo docker run -d --name proxy-docker-hub --restart=always \
    --net=kind \
    -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
    registry:2
fi
if ! sudo docker ps --format '{{.Names}}' | grep -q 'proxy-quay-io'; then
  sudo docker run -d --name proxy-quay-io --restart=always \
    --net=kind \
    -e REGISTRY_PROXY_REMOTEURL=https://quay.io \
    registry:2
fi

cd $(dirname $(realpath $0))

# Start Kind cluster
sudo kind delete cluster --name $CLUSTERNAME || true

sudo kind create cluster --name $CLUSTERNAME --config ./config.yaml --wait 5m
sudo kind get kubeconfig --name $CLUSTERNAME | tee ~/.kube/config >/dev/null

rm -rf ../checkpoints/*
sudo docker exec -it k8s-1.37-worker bash -c "apt-get update && apt-get install -y criu buildah"

docker run -d -p 5001:5000 --name kind-registry registry:2
docker network connect kind kind-registry
