FROM registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:a8870aa60b45495d298df5b65c69b3d7972608da4367bd6e69d6e392ac969dd4

COPY --chown=1001:0 . /home/eduk8s/
RUN mv /home/eduk8s/workshop /opt/workshop

# All the direct Downloads need to run as root as they are going to /usr/local/bin
USER root
# TBS
RUN curl -L -o /usr/local/bin/kp https://github.com/vmware-tanzu/kpack-cli/releases/download/v0.10.0/kp-linux-amd64-0.10.0 && \
  chmod 755 /usr/local/bin/kp
# Tanzu
COPY /plugins/cli/core/v0.28.1/tanzu-core-linux_amd64 /usr/local/bin/tanzu
RUN chmod 755 /usr/local/bin/tanzu
COPY /plugins/cli/discovery /tmp/discovery
COPY /plugins/cli/distribution /tmp/distribution
RUN tanzu plugin install --local /tmp all
RUN chmod -R 755 .config/tanzu
# Knative
RUN curl -L -o /usr/local/bin/kn https://github.com/knative/client/releases/download/knative-v1.9.2/kn-linux-amd64 && \
    chmod 755 /usr/local/bin/kn

# Utilities
RUN apt-get update && apt-get install -y unzip

# Requirements for Live Update
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version 4.11.0
RUN mv /usr/bin/code-server /opt/code-server/bin/code-server
COPY extensions/tanzu-vscode-extension-0.14.1.vsix /tmp
COPY extensions/tanzu-app-accelerator-0.1.6.vsix /tmp
RUN code-server --install-extension vscjava.vscode-java-pack && \
    code-server --install-extension /tmp/tanzu-vscode-extension-0.14.1.vsix && \
    code-server --install-extension /tmp/tanzu-app-accelerator-0.1.6.vsix
RUN echo -n 'export PATH=~/.local/bin:$PATH' >> /etc/profile
RUN chown -R eduk8s:users /home/eduk8s/.cache
RUN chown -R eduk8s:users /home/eduk8s/.local
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
RUN chown -R eduk8s:users /home/eduk8s/.tilt-dev

# Install Tilt for eduk8s user in local path under homedir
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | PATH=~/.local/bin:$PATH bash

# kubectl krew
RUN \
( \
  set -x; cd "$(mktemp -d)" && \
  OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
  KREW="krew-${OS}_${ARCH}" && \
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
  tar zxvf "${KREW}.tar.gz" && \
  ./"${KREW}" install krew \
)
RUN echo "export PATH=\"${KREW_ROOT:-$HOME/.krew}/bin:$PATH\"" >> ${HOME}/.bashrc
ENV PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
RUN kubectl krew install tree
RUN kubectl krew install view-secret
RUN kubectl krew install ctx
RUN kubectl krew install ns
RUN kubectl krew install eksporter
RUN kubectl krew install slice
RUN chmod 775 -R $HOME/.krew
RUN rm -rf /tmp/*

USER 1001
RUN fix-permissions /home/eduk8s
