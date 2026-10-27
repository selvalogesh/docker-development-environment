# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
# Space-separated list of Node versions for nvm; the first one becomes the default
ARG NODE_VERSIONS="lts/* 20"
ARG NVM_VERSION=v0.40.1
ARG INSTALL_PYTHON=true
ARG INSTALL_RUST=false
ARG INSTALL_GO=false
# "latest" or an exact version such as 1.23.2
ARG GO_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Base tooling
RUN apt-get update \
    && apt-get install -y -q --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        htop \
        jq \
        less \
        libssl-dev \
        nano \
        openssh-client \
        procps \
        sudo \
        tzdata \
        unzip \
        vim \
        wget \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
        apt-get update \
        && apt-get install -y -q --no-install-recommends python3 python3-pip python3-venv pipx \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$INSTALL_GO" = "true" ]; then \
        version="$GO_VERSION"; \
        [ "$version" = "latest" ] && version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1 | sed 's/^go//')"; \
        curl -fsSL "https://go.dev/dl/go${version}.linux-$(dpkg --print-architecture).tar.gz" | tar -C /usr/local -xz; \
    fi

# Non-root user with passwordless sudo. Ubuntu 24.04 ships an "ubuntu" user on UID 1000;
# remove it so ours can take that UID and bind-mounted files keep the host user's ownership.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME" \
    # Pre-create volume mount points so named volumes inherit the user's ownership
    && mkdir -p /workspaces "/home/$USERNAME/.vscode-server/extensions" /commandhistory \
    && chown -R "$USERNAME:$USERNAME" /workspaces "/home/$USERNAME/.vscode-server" /commandhistory

USER $USERNAME

# Node via nvm. NVM_SYMLINK_CURRENT keeps ~/.nvm/current pointing at the active version,
# so node is on PATH for non-interactive shells too (docker exec, tasks, debuggers).
ENV NVM_DIR=/home/$USERNAME/.nvm \
    NVM_SYMLINK_CURRENT=true \
    COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash \
    && . "$NVM_DIR/nvm.sh" \
    && for version in $NODE_VERSIONS; do nvm install "$version"; done \
    && nvm alias default "${NODE_VERSIONS%% *}" \
    && nvm use default \
    # pnpm and yarn through corepack (no longer bundled with newer Node releases)
    && (command -v corepack >/dev/null || npm install -g corepack) \
    && corepack enable \
    && nvm cache clear

RUN if [ "$INSTALL_RUST" = "true" ]; then \
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
            | sh -s -- -y --no-modify-path --profile minimal --component rustfmt,clippy; \
    fi

ENV PATH=/home/$USERNAME/.nvm/current/bin:/home/$USERNAME/.cargo/bin:/home/$USERNAME/go/bin:/usr/local/go/bin:$PATH

# Shell history survives container rebuilds (stored in the commandhistory volume)
RUN echo 'export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}" HISTFILE=/commandhistory/.bash_history' >> ~/.bashrc

WORKDIR /workspaces

# Keep the container running so VS Code (and docker exec) can attach at any time
CMD ["sleep", "infinity"]
