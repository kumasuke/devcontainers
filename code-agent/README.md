# 開発コンテナ (.devcontainer) セットアップ概要

このリポジトリには、Ubuntu ベースの Dev Container 環境が用意されています。Homebrew、zsh、oh‑my‑zsh、powerlevel10k、direnv、Claude(CLI)、OpenAI Codex、Node.js(nvm)、npm グローバル、Bun、gemini-cli などをインストールし、日本(Asia/Tokyo)のタイムゾーンで動作します。

## 構成
- ベース: Ubuntu 22.04（`ARG VARIANT`）
- シェル: zsh（`/usr/bin/zsh`）
- Homebrew (Linuxbrew): 非対話インストール + PATH 設定
- oh‑my‑zsh + powerlevel10k: 非対話インストール（RUNZSH=no, CHSH=no, KEEP_ZSHRC=yes）、テーマ反映済み
- direnv: apt インストール + zsh フック設定済み（apt 優先）
- gh (GitHub CLI): 公式 APT リポジトリからインストール（apt 優先）
- gnupg: gh の APT リポジトリ鍵導入に必要（apt 導入済み）
- Codex: GitHub リリースからバイナリ取得（x86_64/arm64 自動判定、失敗時は brew、双方失敗でもビルド継続）
- Claude (Claude Code): ネイティブバイナリ（公式 install.sh）
- Node.js: nvm で 22.18.0 をインストールし default に設定。`PATH` に `~/.nvm/versions/node/v${NODE_VERSION}/bin` を追加し、zsh 起動時に `nvm use default` を実行するため、非ログイン/ログインの両方で `node`/`npm`/`npx` が利用可能です。
- npm グローバル: nvm 互換性のため `~/.npmrc` での `prefix` 設定は行わず、nvm が管理する Node ごとのグローバルパスを使用（`~/.nvm/versions/node/v22.18.0/bin` が PATH に含まれる）
- Bun: バージョン固定（bun-v1.2.21）
- gemini-cli: npm グローバルで v0.2.1 固定（変数管理: `GEMINI_CLI_VERSION`）
- タイムゾーン: Asia/Tokyo
- VS Code: 統合ターミナルを zsh 既定、フォントは MesloLGS NF を推奨
- ワークスペース: コンテナ内の `/workspace` を作業ディレクトリに設定（ローカルをバインドマウント）

## バージョン固定
- Claude (CLI): 1.0.94（`CLAUDE_VERSION`）
- Codex: 0.25.0（GitHub リリース rust-v0.25.0 から取得）
- Node.js: 22.18.0（nvm）
- Bun: bun-v1.2.21（インストーラにバージョン指定）
- gemini-cli: v0.2.1（npm グローバル）

## 主要ファイル
- `.devcontainer/Dockerfile`
  - すべてのインストールと環境設定（PATH, SHELL, TZ, npm prefix, nvm, bun など）
- `.devcontainer/devcontainer.json`
  - ビルド引数、リモートユーザー、環境変数（`TZ`）、VS Code 設定、起動後のバージョン表示

## 使い方
1. VS Code に Dev Containers 拡張をインストール
2. このリポジトリを開き、「Reopen in Container」を実行
3. 起動後、以下が自動で確認されます（`postCreateCommand`）:
   - `brew --version`
   - `gh --version`
   - `claude --version`
   - `codex --version`
   - `node -v`, `npm -v`
   - `bun --version`
   - `gemini --version`

### ローカル zsh 設定のマウント（エイリアス等）
- ローカルの `.devcontainer/.zshrc.local` は、コンテナ内の `/home/vscode/.zshrc.local` にバインドマウントされます。
- コンテナ側の `~/.zshrc` は `~/.zshrc.local` を自動で source するため、`.devcontainer/.zshrc.local` に alias や関数を記述すると zsh 起動時に反映されます。
- 例: `.devcontainer/.zshrc.local`
  ```sh
  alias ll='ls -alF'
  export EDITOR=vim
  ```

手動確認コマンドの例:
- `zsh --version`
- `direnv version`
- `echo $TZ` → `Asia/Tokyo`

## 認証/初期設定のヒント
- powerlevel10k の見た目改善にはローカル OS 側に Nerd Font のインストールが必要（推奨: MesloLGS NF）。
- direnv を使う場合はプロジェクト直下に `.envrc` を置き、`direnv allow` を実行。
  - 例: Claude/Gemini 用の API キーを設定
    ```sh
    # .envrc の例
    export GEMINI_API_KEY=your_api_key
    export ANTHROPIC_API_KEY=your_api_key
    ```
- gemini-cli 初回実行時に認証が必要な場合はドキュメントに従って設定してください。
- Claude CLI もログイン/キー設定が必要な場合があります。`claude --help` を参照してください。

## カスタマイズ（ビルド引数）
`devcontainer.json` の `build.args` から主要バージョン/設定を変更できます。
- `VARIANT`: Ubuntu のタグ（例: `22.04`）
- `TIMEZONE`: 例 `Asia/Tokyo`
- `CLAUDE_VERSION`: 例 `1.0.94`
- `CODEX_VERSION`: 例 `0.25.0`
- `NODE_VERSION`: 例 `22.18.0`
- `BUN_VERSION`: 例 `bun-v1.2.21`
- `GEMINI_CLI_VERSION`: 例 `v0.2.1`

変更後は Dev Container を Rebuild してください。

## 実装メモ（主な設定）
- パッケージ導入方針: インストール可能なものは apt を優先（例: direnv, gh）。それ以外は公式スクリプト/バイナリ、Homebrew を併用。
- PATH: `~/.local/bin`, `~/.npm-global/bin`, `~/.bun/bin`, Linuxbrew `bin` を追加
- npm グローバル: `~/.npmrc` の `prefix` 固定は廃止（nvm と非互換のため）。`npm -g` は有効な Node（nvm default）配下にインストールされ、当該 bin が PATH に入ります。
- nvm: `~/.nvm` に配置し、zsh 起動時に自動読み込み
- Codex: 
  - 取得 URL 例: `https://github.com/openai/codex/releases/download/rust-v0.25.0/codex-x86_64-unknown-linux-musl.tar.gz`
  - 展開後の実行ファイルを `~/.local/bin/codex` に配置
  - 失敗時は `brew install codex && brew pin codex` にフォールバック。両方失敗してもビルドは継続します（`codex` は任意）。
- Claude: `curl -fsSL https://claude.ai/install.sh | bash -s 1.0.94`
- gh: 公式 APT リポジトリを登録し `apt-get install gh`
- Bun: `curl -fsSL https://bun.com/install | bash -s "bun-v1.2.21"`
  
  補足: gh の APT リポジトリ鍵（`.gpg`）を `curl | gpg --dearmor` で登録するため、`gnupg` を apt で導入しています。

## トラブルシュート
- powerlevel10k のアイコンが崩れる: ローカル VS Code のフォントを Nerd Font（MesloLGS NF）へ切り替え。
- `codex` が見つからない: GitHub へのアクセスやアーキ判定を確認。失敗時は brew のフォールバックが働きます。
  - それでも取得できない場合はスキップされます（ビルドは成功）。必要になった時点で手動導入を検討してください。
- `gemini`/`claude` が認証エラー: 各 CLI のドキュメントに従い API キーやログインを設定。`.envrc` + direnv 管理が便利です。
- npm 権限/互換: `~/.npmrc` に `prefix` を書かない。`npm prefix -g` で現在のグローバル先を確認。`nvm use --delete-prefix` 警告が出る場合は `.npmrc` から `prefix` 行を削除。

---
不明点や追加したいツール/バージョンがあればお知らせください。必要に応じて `.devcontainer` を更新します。
