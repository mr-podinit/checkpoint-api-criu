#!/bin/bash

export DOCKER_BUILDKIT=1
TARGET="kindest/node:v1.37.0-crio"
INTERMEDIATE="${TARGET}-tmp"

docker rmi $TARGET $INTERMEDIATE || true
docker system prune --all --force || true

cd $(dirname $0)
sudo rm -rf /tmp/k8s-tar-extract-*
sudo kind build node-image --base-image docker.io/kindest/base:v20260820-69b56db7 v1.37.0 --image kindest/node:v1.37.0

sudo docker build --build-arg CRIO_VERSION=v1.36 -t $INTERMEDIATE --network=host  .
docker run --privileged --rm -d --name crio-builder --entrypoint sleep $INTERMEDIATE infinity

cleanup() {
  docker kill crio-builder
}
# Remove the crio-builder container on exit
trap cleanup EXIT

# Start crio & containerd daemons
docker exec -d crio-builder containerd
docker exec -d crio-builder crio
sleep 3
# Migrate the pinned kube-* images from containerd to cri-o
docker exec crio-builder bash -c 'for IMG in $(ctr -n k8s.io images list -q | grep "registry.k8s.io/kube-"); do echo "Migrating $IMG ..." && ctr -n k8s.io image export --platform "linux/amd64" - "$IMG" | podman load; done'

# Commit the final image, restoring the original entrypoint
docker commit --change 'ENTRYPOINT [ "/usr/local/bin/entrypoint", "/sbin/init" ]' crio-builder $TARGET
