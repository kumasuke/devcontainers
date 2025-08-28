FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest
ARG BUN_VERSION=latest

# Install basic development tools and Squid proxy
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  squid \
  dnsutils \
  jq \
  nano \
  vim \
  curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Set locale to avoid warnings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR nano
ENV VISUAL nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install bun
RUN npm install -g bun@${BUN_VERSION}

# Copy and set up Squid proxy configuration
COPY squid-proxy-solution.conf /etc/squid/squid.conf
COPY setup-squid-proxy.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/setup-squid-proxy.sh && \
  mkdir -p /var/log/squid && \
  chown proxy:proxy /var/log/squid && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/setup-squid-proxy.sh" > /etc/sudoers.d/node-proxy && \
  echo "node ALL=(root) NOPASSWD: /usr/sbin/service squid *" >> /etc/sudoers.d/node-proxy && \
  chmod 0440 /etc/sudoers.d/node-proxy

# Set proxy environment variables for AWS SDK
ENV HTTP_PROXY=http://localhost:3128
ENV HTTPS_PROXY=http://localhost:3128
ENV http_proxy=http://localhost:3128
ENV https_proxy=http://localhost:3128
ENV NO_PROXY=localhost,127.0.0.1,::1
ENV no_proxy=localhost,127.0.0.1,::1

USER node
