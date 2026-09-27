# Checkpoint API + CRIU on Kind

This repository provides a small but practical lab for experimenting with container checkpointing in Kubernetes using Kind, CRI-O, and CRIU.

The goal is to create a local environment where a pod can be checkpointed through the kubelet checkpoint API, the resulting snapshot can be stored on a shared filesystem, and a custom image can be built from that checkpoint for further testing.

## What this setup includes

This project contains three main directories:

- `custom-image/`: builds a custom Kind node image that replaces containerd with CRI-O and enables CRIU support.
- `kind/`: creates the Kind cluster, installs the required runtime pieces, and starts a local registry for testing checkpointed images.
- `pod-snapshot/`: contains the demo pod used to validate the checkpoint flow.

## Why this is useful

This environment is ideal for learning and validating how Kubernetes checkpointing works in a local, reproducible setup. It is especially useful when exploring:

- CRI-O runtime behavior
- CRIU integration with OCI-compatible images
- Kubernetes node checkpoint APIs
- checkpoint image creation and local registry publishing

---

## Prerequisites

Before running this lab, make sure the following tools are installed on your machine:

- Docker
- Kind
- kubectl
- buildah
- sudo access for the node image and cluster bootstrap steps

You can verify the main tools with:

```bash
docker --version
kind --version
kubectl version --client
buildah --version
criu --version
```

---

## 1. Build the custom node image

From the repository root, run:

```bash
cd custom-image
./build.sh
```

This script:

- builds a Kind node image based on `kindest/node`
- swaps the default runtime from containerd to CRI-O
- migrates Kubernetes images from containerd to CRI-O
- prepares the node image with CRIU support enabled

The resulting image is then used by the cluster created in the next step.

---

## 2. Create the Kind cluster

Move into the cluster setup directory and start the lab:

```bash
cd kind
./start.sh
```

The script performs the following:

- creates the `kind` Docker network if it does not exist
- starts local registry proxies for Docker Hub and Quay.io
- deletes any previous cluster named `k8s-1.37`
- creates a fresh Kind cluster with the custom image
- writes kubeconfig to `~/.kube/config`
- creates the `../checkpoints/` directory
- installs `criu` and `buildah` inside the worker node
- starts a local registry on port `5001`

After cluster creation, validate that it is healthy:

```bash
kubectl get nodes
kubectl get pods -A
```

---

## 3. Deploy the demo pod

Apply the example workload:

```bash
kubectl apply -f pod-snapshot/pod.yaml
```

This manifest defines a pod named `pod-counter` and runs a simple `nginx` container with a loop that prints a counter. It is intentionally simple and useful for verifying that the application state is preserved during checkpointing.

Check that the pod is running:

```bash
kubectl get pods
kubectl logs -f pod-counter
```

You should see incrementing log lines such as:

```text
Running... 0
Running... 1
Running... 2
```

---

## 4. Create a checkpoint snapshot

The checkpoint operation is triggered through the kubelet checkpoint API exposed via the Kubernetes API proxy:

```bash
kubectl proxy --port=8001 &
kubectl get --raw /api/v1/nodes/k8s-1.37-worker/proxy/checkpoint/default/pod-counter/counter
```

This calls the node checkpoint endpoint for the `counter` container and writes the checkpoint artifacts into the shared `/checkpoints` filesystem on the node.

> Note: the exact node name and pod name may vary depending on your cluster state, but the expected pattern is the same as above.

---

## 5. Build a checkpoint image

Once the checkpoint is written to `/checkpoints`, you can package it into a special image that references the original application content:

```bash
newcontainer=$(buildah from scratch)
buildah add $newcontainer checkpoints/$(ls -1 checkpoints/) /
buildah config --annotation=io.kubernetes.cri-o.annotations.checkpoint.name=counter $newcontainer
buildah commit $newcontainer checkpoint-image:latest
buildah push --tls-verify=false localhost/checkpoint-image:latest localhost:5001/checkpoint-image:latest
```

This produces an OCI-style image that contains the checkpoint metadata and can be pushed to the local registry for later use in the cluster.

---

## 6. Reuse the checkpoint image in the cluster

After publishing the image to the local registry, you can consume it from Kubernetes or as a test image for additional experiments:

```bash
kubectl run demo --image=localhost:5001/checkpoint-image:latest --restart=Never
```

This is useful for testing restore flows or validating image reuse patterns after checkpoint creation.

---

## Useful notes

- This setup is designed for a local lab and experimental testing.
- Checkpointing behavior depends on the runtime, kernel features, and CRIU support available in the environment.
- The `checkpoints/` directory is cleared when the cluster is recreated, so preserve any important checkpoint artifacts before rerunning the setup.
- The local registry is useful for validating the entire lifecycle: create checkpoint, push image, pull image, and test restore behavior.

---

## Troubleshooting

If you run into issues, start with the basics:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl describe pod pod-counter
kubectl logs pod-counter
```

Also verify:

- Docker is running correctly
- `kind` and `kubectl` are installed and working
- the custom image build completed without errors
- CRI-O is active on the worker node
- the checkpoint endpoint is accessible and the node name is correct

---

## Conclusion

This project is a practical example of how to run Kubernetes container checkpointing in a local, reproducible Kind environment using CRI-O and CRIU.

It covers the full experimental loop: custom node image creation, cluster bootstrap, checkpoint generation, image packaging, and registry publication. It is a useful starting point for deeper investigation into restore workflows, runtime behavior, and checkpoint-based application recovery.

