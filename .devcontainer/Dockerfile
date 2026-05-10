FROM node:22.22.2

ARG TZ
ENV TZ="$TZ"

# Install development tools, compilers, and utilities
# Groups: Core utils, Network tools, Build tools, Editors, CLI deps, Security
# BuildKit cache mounts for faster rebuilds (5-10x speedup)

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    curl \
    wget \
    less \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    gnupg2 \
    # System tools
    procps \
    htop \
    tree \
    sudo \
    # Git and related tools
    git \
    git-lfs \
    gh \
    # Shell and terminal tools
    zsh \
    fzf \
    ripgrep \
    fd-find \
    tmux \
    jq \
    yq \
    sed \
    gawk \
    unzip \
    zip \
    bzip2 \
    xz-utils \
    nano \
    vim \
    # Network tools
    dnsutils \
    net-tools \
    iputils-ping \
    telnet \
    netcat-openbsd \
    iptables \
    ipset \
    iproute2 \
    aggregate \
    # Python and related tools
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Build tools
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    # Locales
    locales \
    # OpenSSL and crypto
    openssl \
    libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python symlink for convenience
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Set up locale for UTF-8 support
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Ensure default node user has access to /usr/local/share
RUN chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history and configure PATH for npm global packages
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo 'export PATH=$PATH:/home/node/.npm-global/bin:/home/node/.local/bin' >> /home/node/.bashrc \
    && chown node:node /home/node/.bashrc

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create config directories and set permissions
# Note: Workspace directory is created and mounted by VS Code automatically
RUN mkdir -p /home/node/.config/gh /home/node/.copilot /home/node/.pi /home/node/.gemini /home/node/.npm-global/lib /home/node/.local/bin && \
    chown -R node:node /home/node/.config /home/node/.copilot /home/node/.pi /home/node/.gemini /home/node/.npm-global /home/node/.local

# Default working directory (VS Code will override this with actual workspace mount)
WORKDIR /workspaces

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
    -a "source /usr/share/doc/fzf/examples/completion.zsh" \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -a "export PATH=\$PATH:/home/node/.npm-global/bin:/home/node/.local/bin" \
    -a "alias fd=fdfind" \
    -a "alias rg='rg --smart-case'" \
    -x

# Install uv (fast Python package manager)
# uv installer places binary at /home/node/.local/bin/uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/node/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/node/.zshrc

# Add .local/bin to PATH
ENV PATH="/home/node/.local/bin:$PATH"

# Install bun
RUN curl -fsSL https://bun.sh/install | bash && \
    echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/node/.bashrc && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/node/.bashrc && \
    echo 'export BUN_INSTALL="$HOME/.bun"' >> /home/node/.zshrc && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /home/node/.zshrc

ENV BUN_INSTALL="/home/node/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Configure git to global ignore
# This prevents accidentally committing sensitive configuration like API keys
RUN git config --global core.excludesfile ~/.gitignore_global && \
    echo ".pi/settings.json" >> /home/node/.gitignore_global && \
    echo ".gemini/settings.json" >> /home/node/.gitignore_global && \
    chown node:node /home/node/.gitignore_global

# Switch to root for final setup (scripts, sudoers, templates)
USER root

# Create directory for Claude Code and Codex defaults
RUN mkdir -p /usr/local/share/copilot-defaults /usr/local/share/pi-defaults /usr/local/share/gemini-defaults


# Copy all scripts and templates in one layer (changes most frequently)
COPY scripts/setup-firewall.sh /usr/local/bin/
COPY scripts/setup-pi-config.sh /usr/local/bin/
COPY scripts/setup-copilot-config.sh /usr/local/bin/
COPY scripts/setup-gemini-config.sh /usr/local/bin/
COPY scripts/setup-python.sh /usr/local/bin/

COPY --chown=node:node templates/pi-settings.template.json /usr/local/share/pi-defaults/settings.json
COPY --chown=node:node templates/copilot-settings.template.json /usr/local/share/copilot-defaults/settings.json
COPY --chown=node:node templates/gemini-settings.template.json /usr/local/share/gemini-defaults/settings.json

# Set permissions and configure sudoers for all init scripts
RUN chmod +x /usr/local/bin/setup-firewall.sh && \
    chmod +x /usr/local/bin/setup-pi-config.sh && \
    chmod +x /usr/local/bin/setup-copilot-config.sh && \
    chmod +x /usr/local/bin/setup-gemini-config.sh && \
    chmod +x /usr/local/bin/setup-python.sh && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-firewall.sh" > /etc/sudoers.d/node-firewall && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-pi-config.sh" > /etc/sudoers.d/node-pi-config && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-copilot-config.sh" > /etc/sudoers.d/node-copilot-config && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-gemini-config.sh" > /etc/sudoers.d/node-gemini-config && \
    echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-python.sh" > /etc/sudoers.d/node-python && \
    chmod 0440 /etc/sudoers.d/node-firewall && \
    chmod 0440 /etc/sudoers.d/node-pi-config && \
    chmod 0440 /etc/sudoers.d/node-copilot-config && \
    chmod 0440 /etc/sudoers.d/node-gemini-config && \
    chmod 0440 /etc/sudoers.d/node-python

# Switch back to node user for runtime
USER node
