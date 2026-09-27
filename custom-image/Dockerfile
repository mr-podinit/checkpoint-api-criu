FROM kindest/node:v1.37.0
ARG CRIO_VERSION
ARG PROJECT_PATH=prerelease:/$CRIO_VERSION

RUN echo "Installing CRI-O and related tools" \
    && apt update -y \
    && apt install -y --no-install-recommends vim curl gnupg \
    && curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/$PROJECT_PATH/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/$PROJECT_PATH/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list \
    && apt update \
    && apt install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends cri-o podman criu \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/containerd/crio/g' /etc/crictl.yaml \
    && ln -s /usr/libexec/podman/conmon /usr/local/bin/conmon \
    && systemctl disable containerd \
    && systemctl enable crio 

COPY crio.conf /etc/crio/crio.conf.d/10-crio.conf
COPY registries.yaml /etc/containers/registries.conf



