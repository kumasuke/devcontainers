# devcontainer
devcontainerを使用して、Claude Codeを実行できる環境

[Anthropic公式の.devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer) を元にして、一部以下の修正を加えています
- Amazon Bedrock APIで使用できるように、Squidプロキシによるドメインベースのアクセス制御を実装
- Claude Code v1.0.73のインストール
- Bunのインストール（v1.2.20）
- 実行マシンとのフォルダ、ファイルのマウント設定

## 実行マシンとのフォルダ、ファイルのマウント設定
```
# ローカルの .zshrc をマウント
"source=${localEnv:HOME}/.zshrc,target=/home/node/.zshrc,type=bind",

# ClaudeCode設定ファイル関連
"source=${localEnv:HOME}/.claude/CLAUDE.md,target=/home/node/.claude/CLAUDE.md,type=bind",
"source=${localEnv:HOME}/.claude/settings.json,target=/home/node/.claude/settings.json,type=bind",
```

### .zshrc
以下を含めておく
```bash
## use AmazonBedrock API on ClaudeCode
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_BEARER_TOKEN_BEDROCK="****"
export AWS_REGION="us-east-1"
```

#### tips
以下のエイリアスも設定しておくと便利
```bash
## ccusage
alias ccusage="bunx ccusage"

## AmazonBedrock API Model
alias claude-ops="claude \"/model arn:aws:bedrock:us-east-1:***:inference-profile/us.anthropic.claude-opus-4-1-20250805-v1:0\""
alias claude-sonnet="claude \"/model arn:aws:bedrock:us-east-1:***:inference-profile/us.anthropic.claude-sonnet-4-20250514-v1:0\""
```

### ~/.claude/CALUDE.md
```markdown
- 応答やレポートの書き出しは `日本語` で行うこと
- マークダウンファイルなどを作る時は、何も指示がなければ `[作業フォルダ]/.claude/docs` 以下に作成すること

## サブエージェント
- サブエージェントを作成、実行する時には、 `model: arn:aws:bedrock:us-east-1:***:inference-profile/us.anthropic.claude-sonnet-4-20250514-v1:0` を必ず指定するようにすること

```

### ~/.claude/settings.json
```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  },
  "model": "arn:aws:bedrock:us-east-1:***:inference-profile/us.anthropic.claude-sonnet-4-20250514-v1:0",
  "statusLine": {
    "type": "command",
    "command": "bun x ccusage statusline"
  },
  "permissions": {
    "allow": [
    ],
    "deny": [
      "Fetch(*)",
      "WebFetch(*)",
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf ~/*)",
      "Bash(rm -rf /*)",
      "Bash(git push origin:*)",
      "Bash(git push origin main:*)",
      "Bash(git push origin master:*)",
      "Bash(git push -f:*)",
      "Bash(git push --force:*)",
      "Bash(brew :*)"
    ]
  }
}
```


## 現在の実装内容（Dockerfile/devcontainer.json）

### 採用されているソリューション：Squid Proxy

現在のdevcontainer環境では、**Squid Proxyソリューション**が採用されています。これにより、Amazon Bedrock APIへのアクセスを動的IPアドレスの変更に影響されることなく安定して行えます。

#### 実装詳細

1. **Dockerfile での設定**
   - Squidプロキシのインストール
   - `squid-proxy-solution.conf` を `/etc/squid/squid.conf` にコピー
   - `setup-squid-proxy.sh` を `/usr/local/bin/` に配置
   - nodeユーザーにSquid管理権限を付与（sudoers設定）
   - プロキシ環境変数の設定（HTTP_PROXY, HTTPS_PROXY）

2. **devcontainer.json での設定**
   - `postStartCommand` で自動的にSquidプロキシを起動
   - プロキシ環境変数をコンテナ環境変数として設定
   - NO_PROXYでローカルホストを除外

3. **自動起動される処理**
   ```bash
   # コンテナ起動時に自動実行
   sudo /usr/local/bin/setup-squid-proxy.sh
   ```

### インストールされているツール

- **Claude Code**: v1.0.73
- **Bun**: v1.2.20
- **Git Delta**: v0.18.2
- **Zsh with PowerLevel10k**: v1.2.0
- **GitHub CLI (gh)**
- **その他開発ツール**: fzf, jq, vim, nano, curl, dnsutils

## 代替ソリューションについて

過去に検討・実装されたAmazon Bedrock APIタイムアウト問題の代替ソリューションについては、[alternative-solutions.md](./alternative-solutions.md)を参照してください。

含まれる内容：
- ファイアウォールベースのソリューション (init-firewall.sh, init-firewall-bedrock-bypass.sh, refresh-firewall.sh)
- Transparent Proxy Solution (transparent-proxy-solution.sh)

## Squid Proxy Solution (setup-squid-proxy.sh, squid-proxy-solution.conf)

動的IPアドレス問題に対するもう一つのアプローチとして、Squidプロキシを使用したドメインベースのフィルタリングソリューションを提供しています。

### 概要

Squidプロキシソリューションは、HTTPプロキシサーバーを使用して、許可されたドメインへのアクセスのみを許可します。IPアドレスではなくドメイン名でアクセス制御を行うため、動的IPの変更に影響されません。

### 構成ファイル

#### setup-squid-proxy.sh
Squidプロキシの起動と設定を行うスクリプトです：
- ログディレクトリの作成
- Squidサービスの起動/再起動
- 環境変数の設定方法の表示

#### squid-proxy-solution.conf
Squidの設定ファイルで、以下の機能を提供します：
- ポート3128でのプロキシサービス
- ドメインベースのアクセス制御
- キャッシュの無効化（常に最新のDNS解決を使用）
- 短いDNS TTL設定（動的IP変更への迅速な対応）

### 許可されているドメイン

1. **Amazon Bedrockエンドポイント**
   - `bedrock.us-east-1.amazonaws.com`
   - `bedrock-runtime.us-east-1.amazonaws.com`
   - `bedrock-fips.us-east-1.amazonaws.com`
   - `bedrock-agent.us-east-1.amazonaws.com`
   - `bedrock-agent-runtime.us-east-1.amazonaws.com`
   - `sts.us-east-1.amazonaws.com`

2. **開発ツール関連**
   - GitHub（`.github.com`, `.githubusercontent.com`）
   - NPM（`registry.npmjs.org`）
   - Anthropic API（`api.anthropic.com`など）

### 使用方法

#### 1. Squidプロキシの起動
```bash
# コンテナ内で実行
sudo /usr/local/bin/setup-squid-proxy.sh
```

#### 2. 環境変数の設定
```bash
# HTTPプロキシの設定
export HTTP_PROXY=http://localhost:3128
export HTTPS_PROXY=http://localhost:3128
export http_proxy=http://localhost:3128
export https_proxy=http://localhost:3128

# AWS SDKの証明書設定（必要に応じて）
export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```

### メリット

1. **完全なドメインベースの制御**
   - IPアドレスの変更に自動対応
   - DNS解決は常に最新の情報を使用

2. **詳細なアクセスログ**
   - `/var/log/squid/access.log`でアクセス履歴を確認可能
   - デバッグとトラブルシューティングが容易

3. **標準的なHTTPプロキシプロトコル**
   - ほとんどのツールやライブラリがサポート
   - 設定が簡単で互換性が高い

### トラブルシューティング

#### Squidの状態確認
```bash
# サービスの状態
service squid status

# アクセスログの確認
tail -f /var/log/squid/access.log

# エラーログの確認
tail -f /var/log/squid/cache.log
```

#### プロキシ経由の接続テスト
```bash
# プロキシを使用した接続テスト
curl -x http://localhost:3128 https://bedrock.us-east-1.amazonaws.com

# 環境変数が設定されている場合
curl https://bedrock.us-east-1.amazonaws.com
```

### 注意事項

- SSL/TLS接続はCONNECTメソッドでトンネリングされます
- キャッシュは無効化されているため、パフォーマンスよりも最新性を優先しています
- DNS TTLが短く設定されているため、DNSクエリが頻繁に発生します