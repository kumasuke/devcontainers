# AGENTS.md

このリポジトリのエージェント開発運用ポリシーを記述します。

## ドキュメント同期ポリシー（必須）
- `.devcontainer` 配下の構成、バージョン、導入ツール、利用方法に変更を行う場合は、必ず `README.md` の該当箇所を同一コミット内で更新してください。
- 変更対象の例:
  - 追加/削除/更新したツール（Homebrew, zsh, oh‑my‑zsh, powerlevel10k, direnv, Claude, Codex, Node.js, Bun, gemini-cli など）
  - バージョン固定値（例: `CLAUDE_VERSION`, `CODEX_VERSION`, `NODE_VERSION`, `BUN_VERSION`）
  - インストール手順の変更（取得 URL、インストーラスクリプト、PATH 設定、npm グローバル設定など）
  - `devcontainer.json` の `postCreateCommand`、`build.args`、`remoteEnv` などの変更
  - タイムゾーンや既定シェルなどの基本設定変更
- README の更新が不要な場合（スペースやコメントのみの変更等）でも、影響の有無を確認し、影響がある場合は必ず反映します。

## プルリクエスト/コミット時のチェックリスト
- [ ] `.devcontainer/Dockerfile` と `README.md` の記載内容が一致している
- [ ] `.devcontainer/devcontainer.json` と `README.md` のオプション・引数・確認コマンドが一致している
- [ ] バージョン固定値の変更が `README.md` に反映されている
- [ ] 新規ツール導入や削除が `README.md` に追記/削除されている
- [ ] 動作確認コマンド（`postCreateCommand` 等）の出力例や想定が変わっていないか確認した

## 変更の意図の明文化
- バージョン固定や導入方法変更（例: brew → GitHub バイナリ）を行う際は、PR 説明で背景と理由を簡潔に記載してください。
- 影響範囲が大きい変更（デフォルトシェル、PATH、パッケージマネージャ切替など）は、README の「トラブルシュート」や「実装メモ」に補足を追加してください。

## 運用メモ
- README は利用者の一次情報源です。保守性を最優先し、手順の齟齬がない状態を維持します。
- 将来の更新で破壊的変更が発生する場合は、アップグレード手順を README に追記します。

## パッケージ導入ポリシー（apt 優先）
- 基本方針として、Ubuntu 環境では可能な限り `apt` でインストールする。
  - 例: `direnv`, `gh (GitHub CLI)` は apt を優先し、必要に応じて公式リポジトリを追加する。
- `apt` で入手不可のものは、公式のインストールスクリプト/ネイティブバイナリ/リリース資産を使用する。
  - 例: `Claude`（公式 install.sh）、`Codex`（GitHub リリースの musl バイナリ）、`Bun`（公式 install でバージョン指定）。
- `Homebrew (Linuxbrew)` は補助的に使用する。`apt`/公式配布がない場合のみ検討し、導入時は PATH と `brew pin` によりバージョン固定を行う。
- バージョン固定を徹底する。変更時は `devcontainer.json` の build args と `README.md` を同時に更新する。
  - 管理変数例: `CLAUDE_VERSION`, `CODEX_VERSION`, `NODE_VERSION`, `BUN_VERSION`, `GEMINI_CLI_VERSION`。
- セキュリティ配慮: `curl | bash` を行う場合は、出所の明確な公式 URL とタグ/バージョン固定を使用する。可能ならハッシュ検証を行う。
- PATH/ENV の統一: ユーザー配下のディレクトリを優先して PATH 追加し、グローバル権限問題を回避する。
  - 例: `~/.local/bin`, `~/.npm-global/bin`, `~/.bun/bin`。npm は `prefix=$HOME/.npm-global` を標準とする。
  - シェル初期化は `/etc/zsh/zshrc` とユーザー `~/.zshrc` の両方に反映する。
 - 導入方法の切り替え（brew → apt 等）を行った場合は、不要になった記述を README から削除し、`postCreateCommand` の確認コマンドを最新化する。
