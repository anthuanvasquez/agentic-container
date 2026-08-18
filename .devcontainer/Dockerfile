FROM node:22.22.2

ARG TZ=America/Santo_Domingo
ENV TZ="$TZ"

ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=1000

# Install base tools, compilers, and GitHub CLI
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    ca-certificates \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    git \
    git-lfs \
    sudo \
    less \
    jq \
    yq \
    fzf \
    ripgrep \
    fd-find \
    tree \
    htop \
    procps \
    unzip \
    zip \
    nano \
    vim \
    dnsutils \
    net-tools \
    iputils-ping \
    netcat-openbsd \
    iptables \
    ipset \
    iproute2 \
    aggregate \
    locales \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Ensure node user exists with expected UID/GID
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || true \
    && id -u $USERNAME >/dev/null 2>&1 || useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && usermod -aG sudo $USERNAME

# Config directories and npm global path
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:$PATH
ENV COPILOT_CONFIG_DIR=/home/node/.copilot
ENV PNPM_HOME=/home/node/.local/share/pnpm
ENV PATH=$PNPM_HOME:$PATH

RUN mkdir -p /home/node/.copilot /home/node/.npm-global/lib /home/node/.config/gh /home/node/.local/bin /home/node/.local/share/pnpm /commandhistory \
    && chown -R node:node /home/node \
    && chown node:node /commandhistory

# Copy bootstrap scripts (must be available before switching to node)
COPY --chown=node:node scripts/health-check.sh /usr/local/bin/health-check.sh
COPY --chown=node:node scripts/setup-git-hook.sh /usr/local/bin/setup-git-hook.sh
COPY --chown=node:node scripts/setup-firewall.sh /usr/local/bin/setup-firewall.sh
COPY --chown=node:node scripts/configure-npm-security.sh /usr/local/bin/configure-npm-security.sh
RUN chmod +x /usr/local/bin/health-check.sh /usr/local/bin/setup-git-hook.sh /usr/local/bin/setup-firewall.sh /usr/local/bin/configure-npm-security.sh

# Switch to node user before installing global packages and configuring security
USER node

# Harden npm/pnpm defaults
RUN bash /usr/local/bin/configure-npm-security.sh

# Install pnpm directly to avoid corepack runtime version resolution
ARG PNPM_VERSION=10.6.3
RUN npm install -g pnpm${PNPM_VERSION:+@$PNPM_VERSION}

# Install GitHub Copilot CLI
ARG COPILOT_CLI_VERSION=1.0.80
RUN npm install -g @github/copilot${COPILOT_CLI_VERSION:+@$COPILOT_CLI_VERSION} \
    && npm cache clean --force

# Switch back to root for final system setup
USER root

# Allow node user to configure the firewall without a password and preserve env vars
RUN printf 'Defaults env_keep += "FIREWALL_ENABLED"\nnode ALL=(root) NOPASSWD:SETENV: /usr/local/bin/setup-firewall.sh\n' > /etc/sudoers.d/node-firewall \
    && chmod 0440 /etc/sudoers.d/node-firewall

# Shell configuration
RUN echo 'export PATH=/home/node/.npm-global/bin:/home/node/.local/share/pnpm:/home/node/.local/bin:$PATH' >> /home/node/.bashrc \
    && echo 'export PATH=/home/node/.npm-global/bin:/home/node/.local/share/pnpm:/home/node/.local/bin:$PATH' >> /home/node/.zshrc \
    && echo 'export PROMPT_COMMAND="history -a"' >> /home/node/.bashrc \
    && echo 'export HISTFILE=/commandhistory/.bash_history' >> /home/node/.bashrc \
    && echo 'export HISTFILE=/commandhistory/.zsh_history' >> /home/node/.zshrc \
    && git config --global core.excludesfile /home/node/.gitignore_global \
    && echo ".copilot/settings.json" >> /home/node/.gitignore_global \
    && chown node:node /home/node/.gitignore_global

ENV DEVCONTAINER=true
ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano
# Make pnpm available to all shells
ENV PNPM_HOME=/home/node/.local/share/pnpm
ENV PATH=/home/node/.npm-global/bin:/home/node/.local/share/pnpm:/home/node/.local/bin:$PATH

USER node
WORKDIR /workspaces

CMD ["/bin/bash"]
