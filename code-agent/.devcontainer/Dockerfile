ARG VARIANT="22.04"
FROM ubuntu:${VARIANT}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME="vscode"
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG TIMEZONE="Etc/UTC"
ARG CLAUDE_VERSION="1.0.94"
ARG CODEX_VERSION="0.25.0"
ARG NODE_VERSION="22.18.0"
ARG BUN_VERSION="bun-v1.2.21"
ARG GEMINI_CLI_VERSION="v0.2.1"
ARG UV_VERSION="0.8.14"
ARG SERENA_REPO="https://github.com/oraios/serena"
ARG SERENA_TAG="v0.1.4"

# 基本パッケージとユーザー作成
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        file \
        git \
        locales \
        tzdata \
        direnv \
        sudo \
        build-essential \
        procps \
        jq \
        fzf \
        vim \
        unzip \
        zsh \
    && rm -rf /var/lib/apt/lists/* \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo ${TIMEZONE} > /etc/timezone \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd -s /usr/bin/zsh --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
    && usermod -aG sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${USERNAME}

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/${USERNAME}/.claude /home/${USERNAME}/.codex /home/${USERNAME}/.gemini && \
  chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME}/.claude /home/${USERNAME}/.codex /home/${USERNAME}/.gemini

# GitHub CLI (gh) を APT リポジトリから導入（apt 優先方針）
RUN set -eux \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
         | gpg --dearmor \
         | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
         | tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Homebrew (Linuxbrew) をインストール
# 推奨ツール (build-essential, curl, file, git) は既に導入済み
RUN set -eux \
    && curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install_brew.sh \
    && chmod +x /tmp/install_brew.sh \
    && su - ${USERNAME} -c "NONINTERACTIVE=1 /bin/bash /tmp/install_brew.sh" \
    && rm -f /tmp/install_brew.sh

# Homebrew を全ユーザーで使えるよう PATH 等を設定
ENV HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar \
    HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
ENV PATH=/home/${USERNAME}/.nvm/versions/node/v${NODE_VERSION}/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.npm-global/bin:/home/${USERNAME}/.local/bin:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:${PATH} \
    MANPATH=${HOMEBREW_PREFIX}/share/man:${MANPATH} \
    INFOPATH=${HOMEBREW_PREFIX}/share/info:${INFOPATH}
ENV SHELL=/usr/bin/zsh
ENV NVM_DIR=/home/${USERNAME}/.nvm

# ログインシェルでも有効化
RUN echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' | tee /etc/profile.d/homebrew.sh >/dev/null \
    && chmod +x /etc/profile.d/homebrew.sh \
    && printf '%s\n' '# Ensure default nvm Node on PATH' 'export NVM_DIR="/home/'"${USERNAME}"'/.nvm"' 'if [ -s "$NVM_DIR/alias/default" ]; then export PATH="$NVM_DIR/versions/node/$(cat "$NVM_DIR/alias/default")/bin:$PATH"; fi' > /etc/profile.d/nvm-path.sh \
    && chmod +x /etc/profile.d/nvm-path.sh \
    && echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> /home/${USERNAME}/.bashrc \
    && echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> /home/${USERNAME}/.profile \
    && echo 'eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> /etc/zsh/zshrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/zsh/zshrc \
    && echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /etc/zsh/zshrc \
    && echo 'export PATH="$HOME/.bun/bin:$PATH"' >> /etc/zsh/zshrc \
    && echo 'export NVM_DIR="$HOME/.nvm"' >> /etc/zsh/zshrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/zsh/zshrc \
    && echo 'if [ -s "$NVM_DIR/alias/default" ]; then export PATH="$NVM_DIR/versions/node/$(cat "$NVM_DIR/alias/default")/bin:$PATH"; fi' >> /etc/zsh/zshrc \
    && echo 'nvm use default >/dev/null 2>&1 || true' >> /etc/zsh/zshrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> /etc/zsh/zshrc \
    && chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bashrc /home/${USERNAME}/.profile

# 動作確認（バージョン表示のみ、無ければビルド失敗）
RUN brew --version

# oh-my-zsh と powerlevel10k をインストール（ユーザー: ${USERNAME}）
RUN set -eux \
    && su - ${USERNAME} -c 'curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install-ohmyzsh.sh' \
    && su - ${USERNAME} -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh /tmp/install-ohmyzsh.sh' \
    && su - ${USERNAME} -c 'rm -f /tmp/install-ohmyzsh.sh' \
    && su - ${USERNAME} -c 'git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k' \
    && su - ${USERNAME} -c 'if [ -f "$HOME/.zshrc" ]; then sed -i "s#^ZSH_THEME=.*#ZSH_THEME=\"powerlevel10k/powerlevel10k\"#" "$HOME/.zshrc"; else echo "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" >> "$HOME/.zshrc"; fi'

# direnv フックを設定（パッケージは apt で導入済み）
RUN set -eux \
    && echo 'eval "$(direnv hook zsh)"' >> /etc/zsh/zshrc \
    && echo '[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"' >> /etc/zsh/zshrc \
    && if grep -q "^plugins=" /home/${USERNAME}/.zshrc; then sed -i 's/^plugins=.*/plugins=(git direnv)/' /home/${USERNAME}/.zshrc; else echo 'plugins=(git direnv)' >> /home/${USERNAME}/.zshrc; fi \
    && (grep -q 'direnv hook zsh' /home/${USERNAME}/.zshrc || echo 'eval "$(direnv hook zsh)"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q '.zshrc.local' /home/${USERNAME}/.zshrc || echo '[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'HOME/.local/bin' /home/${USERNAME}/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'HOME/.npm-global/bin' /home/${USERNAME}/.zshrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'HOME/.bun/bin' /home/${USERNAME}/.zshrc || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'export NVM_DIR=' /home/${USERNAME}/.zshrc || echo 'export NVM_DIR="$HOME/.nvm"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'nvm.sh' /home/${USERNAME}/.zshrc || echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /home/${USERNAME}/.zshrc) \
    && (grep -q 'bash_completion' /home/${USERNAME}/.zshrc || echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> /home/${USERNAME}/.zshrc) \
    && chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.zshrc

# nvm を導入し、Node.js をバージョン固定でインストールして既定化
RUN set -eux \
    && su - ${USERNAME} -c 'mkdir -p "$HOME/.nvm"' \
    && su - ${USERNAME} -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash' \
    && su - ${USERNAME} -c 'export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh" && nvm install '"${NODE_VERSION}"' && nvm alias default '"${NODE_VERSION}"' && nvm use default && corepack enable'

# bun をバージョン固定でインストール（ユーザー領域）
RUN set -eux \
    && su - ${USERNAME} -c 'curl -fsSL https://bun.com/install | bash -s '"${BUN_VERSION}"'' \
    && su - ${USERNAME} -c '$HOME/.bun/bin/bun --version || true'

# uv を公式インストールスクリプトでバージョン固定インストール（~/.local/bin）
RUN set -eux \
    && su - ${USERNAME} -c 'curl -LsSf https://astral.sh/uv/'"${UV_VERSION}"'/install.sh | sh' \
    && su - ${USERNAME} -c '$HOME/.local/bin/uv --version || true'

# Serena リポジトリを取得（タグ固定）し、起動用ラッパーを配置
RUN set -eux \
    && su - ${USERNAME} -c " \
      set -euo pipefail; \
      DEST=\"\$HOME/serena\"; \
      if [ ! -d \"\$DEST/.git\" ]; then \
        echo \"Cloning Serena (tag ${SERENA_TAG}) from ${SERENA_REPO}\"; \
        if git clone --depth 1 --branch \"${SERENA_TAG}\" \"${SERENA_REPO}\" \"\$DEST\" 2>/dev/null; then \
          :; \
        else \
          git clone \"${SERENA_REPO}\" \"\$DEST\"; \
          cd \"\$DEST\"; \
          git checkout \"${SERENA_TAG}\"; \
        fi; \
      fi; \
      mkdir -p \"\$HOME/.local/bin\"; \
      # mcp サーバ起動用ラッパー（printfで生成）
      printf '%s\\n' \
         '#!/usr/bin/env bash' \
         'set -euo pipefail' \
         'exec "\$HOME/.local/bin/uv" run --directory "\$HOME/serena" serena start-mcp-server "\$@"' \
         > \"\$HOME/.local/bin/serena-mcp-server\" \
      && chmod +x \"\$HOME/.local/bin/serena-mcp-server\" \
      # 設定編集用ラッパー
      && printf '%s\\n' \
         '#!/usr/bin/env bash' \
         'set -euo pipefail' \
         'exec "\$HOME/.local/bin/uv" run --directory "\$HOME/serena" serena config edit "\$@"' \
         > \"\$HOME/.local/bin/serena-config-edit\" \
      && chmod +x \"\$HOME/.local/bin/serena-config-edit\" \
      && true"

# npm のグローバル設定（nvm 互換のため ~/.npmrc の prefix を削除）
RUN set -eux \
    && su - ${USERNAME} -c 'if [ -f "$HOME/.npmrc" ]; then sed -i "/^prefix=/d" "$HOME/.npmrc"; fi'

# gemini-cli を指定バージョンでグローバルインストール（nvm 管理の Node 環境に導入）
RUN set -eux \
    && su - ${USERNAME} -c 'export NVM_DIR="$HOME/.nvm" && . "$NVM_DIR/nvm.sh" \
      && nvm use default \
      && NODE_BIN_DIR="$HOME/.nvm/versions/node/$(cat "$NVM_DIR/alias/default")/bin" \
      && export PATH="$NODE_BIN_DIR:$PATH" \
      && npm install -g @google/gemini-cli@'"${GEMINI_CLI_VERSION}"' \
      && GLOB_PREFIX="$(npm prefix -g)" \
      && if [ ! -x "$GLOB_PREFIX/bin/gemini" ] && [ -x "$GLOB_PREFIX/bin/gemini-cli" ]; then ln -sf "$GLOB_PREFIX/bin/gemini-cli" "$GLOB_PREFIX/bin/gemini"; fi \
      && command -v gemini >/dev/null 2>&1 && gemini --version || true'

# 任意の Homebrew パッケージをビルド時に追加インストール（存在しない場合は警告のみ）
ARG BREW_PACKAGES=""
RUN set -eux \
    && if [ -n "${BREW_PACKAGES}" ]; then \
         su - ${USERNAME} -c "/home/linuxbrew/.linuxbrew/bin/brew install ${BREW_PACKAGES}" \
         || (echo "[warn] Some brew packages failed to install: ${BREW_PACKAGES}" && true); \
         su - ${USERNAME} -c 'for pkg in '"${BREW_PACKAGES}"'; do /home/linuxbrew/.linuxbrew/bin/brew pin "$pkg" || true; done'; \
       fi

# codex: GitHub リリースのバイナリでバージョン固定（rust-v${CODEX_VERSION}）。失敗時は brew を試し、両方失敗してもビルド継続
RUN set -eux \
    && ( \
         su - ${USERNAME} -c 'set -euo pipefail; CODEX_VERSION='"${CODEX_VERSION}"'; \
           ARCH="$(uname -m)"; \
           case "$ARCH" in \
             x86_64) COD_ARCH="x86_64-unknown-linux-musl" ;; \
             aarch64|arm64) COD_ARCH="aarch64-unknown-linux-musl" ;; \
             *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
           esac; \
           URL="https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${COD_ARCH}.tar.gz"; \
           echo "Downloading: $URL"; \
           TMPDIR="$(mktemp -d)"; \
           EXTDIR="$TMPDIR/x"; \
           mkdir -p "$HOME/.local/bin" "$EXTDIR"; \
           if curl -fsSL "$URL" -o "$TMPDIR/codex.tgz"; then \
             tar -xzf "$TMPDIR/codex.tgz" -C "$EXTDIR" || true; \
             BIN="$(find "$EXTDIR" -maxdepth 1 -type f -name "codex*" ! -name "*.tgz" | head -n1)"; \
             if [ -n "$BIN" ]; then mv "$BIN" "$HOME/.local/bin/codex" && chmod +x "$HOME/.local/bin/codex"; else echo "[warn] codex binary not found after extract" >&2; exit 1; fi; \
             rm -rf "$TMPDIR"; \
             "$HOME/.local/bin/codex" --version || true; \
           else \
             echo "[warn] download failed: $URL" >&2; exit 1; \
           fi' \
       || ( \
           echo "[warn] Installing codex via brew (fallback)" >&2; \
           su - ${USERNAME} -c "/home/linuxbrew/.linuxbrew/bin/brew install codex" || true; \
           su - ${USERNAME} -c "/home/linuxbrew/.linuxbrew/bin/brew pin codex" || true; \
           true \
       ) \
       || echo "[warn] codex installation skipped (both methods failed). Continuing build." )

# Claude (ClaudeCode) Native binary をバージョン固定でインストール（~/.local/bin）
RUN set -eux \
    && su - ${USERNAME} -c "curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_VERSION}" \
    && su - ${USERNAME} -c '$HOME/.local/bin/claude --version || true'

USER ${USERNAME}
WORKDIR /workspace

# pnpm のグローバル設定
# 新規に公開されたバージョンのインストールを遅延
RUN pnpm config set --location=global minimumReleaseAge 1440 # 1 day

# Aikido Safe Chain のインストール
RUN npm install -g @aikidosec/safe-chain@latest && safe-chain setup
