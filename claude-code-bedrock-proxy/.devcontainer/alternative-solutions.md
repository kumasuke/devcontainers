# 代替ソリューション（現在未使用）

このドキュメントには、Amazon Bedrock APIのタイムアウト問題に対する代替ソリューションを記載しています。
現在は使用されていませんが、将来的な参考や別の環境での利用のために保存しています。

## init-firewall.sh の修正内容 (2025-08-17)

### 修正理由
devcontainer環境でAmazon Bedrock APIがタイムアウトする問題が発生していたため、ファイアウォール設定を改善しました。

### セキュリティを重視した修正内容

#### 1. **AWS IPレンジの広範な許可を削除**
- ❌ 削除: AWS IP範囲JSONからのCIDRブロック一括追加
- ✅ 採用: DNS解決による特定エンドポイントのみ許可
- **理由**: AWSの広範なIPレンジを許可すると、Bedrock以外のサービスや第三者のAWSホストサービスへのアクセスも許可してしまう

#### 2. **DNS解決の改善とセキュリティ強化**
```bash
# 重要なドメインの定義（解決失敗時はエラー終了）
CRITICAL_DOMAINS=(
    "bedrock-runtime.${BEDROCK_REGION}.amazonaws.com"
    "bedrock.${BEDROCK_REGION}.amazonaws.com"
)

# デフォルトリゾルバーを優先、必要時のみ公開DNSを使用
ips=$(dig +short A "$domain")  # デフォルトを最初に試行
if [ -z "$ips" ]; then
    ips=$(dig +short A "$domain" @8.8.8.8)  # フォールバック
fi
```

#### 3. **グローバルエンドポイントの削除**
- ❌ 削除: `sts.amazonaws.com`（グローバルエンドポイント）
- ✅ 維持: `sts.${BEDROCK_REGION}.amazonaws.com`（リージョン固有）
- **理由**: 最小権限の原則に従い、特定リージョンのみアクセス許可

#### 4. **ファイアウォールルールの最適化**
```bash
# ESTABLISHED,RELATED接続を最初に配置（パフォーマンス向上）
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### 動的IPアドレス問題への対応

#### refresh-firewall.sh スクリプト
動的IPアドレスの変更によるタイムアウト問題が発生した場合、以下のスクリプトを実行してDNS解決を更新できます：

```bash
# コンテナ内で実行
sudo /usr/local/bin/refresh-firewall.sh
```

このスクリプトは：
- Amazon BedrockのエンドポイントのDNSを再解決
- ipsetに新しいIPアドレスを追加
- 接続性をテスト

### トラブルシューティング

タイムアウトが継続する場合の対処法：

1. **DNS解決の確認**
```bash
dig bedrock-runtime.us-east-1.amazonaws.com
```

2. **ファイアウォールルールの確認**
```bash
sudo iptables -L -n -v
sudo ipset list allowed-domains
```

3. **一時的な回避策**（開発環境のみ）
```bash
# 警告: セキュリティリスクあり。本番環境では使用しないこと
sudo iptables -P OUTPUT ACCEPT  # 出力を一時的に許可
```

## Bedrock APIのファイアウォールバイパス設定

Amazon Bedrock APIのタイムアウト問題を根本的に解決するため、Bedrock APIの通信のみファイアウォールをバイパスする設定を用意しました。

### init-firewall-bedrock-bypass.sh

このスクリプトは、Bedrock APIへのHTTPS通信（ポート443）のみを許可し、その他の不要な通信はブロックします。

#### 実装されているバイパス方法

1. **Bedrock IPへのHTTPS通信を許可（デフォルト有効）**
```bash
# Bedrock IPアドレスへのHTTPS(443)通信のみ許可
iptables -A OUTPUT -p tcp --dport 443 -m set --match-set bedrock-ips dst -j ACCEPT
```

2. **特定グループでの実行（オプション）**
```bash
# aws-sdkグループを作成してプロセスを実行
groupadd -f aws-sdk
usermod -a -G aws-sdk node
iptables -A OUTPUT -m owner --gid-owner aws-sdk -j ACCEPT
```

3. **特定ユーザーの特定ポート（オプション）**
```bash
# nodeユーザーのBedrock IPへのHTTPS通信のみ許可
iptables -A OUTPUT -m owner --uid-owner node -p tcp --dport 443 \
    -m set --match-set bedrock-ips dst -j ACCEPT
```

#### 使用方法

**方法1: devcontainer.jsonを編集**
```json
"postCreateCommand": "sudo /usr/local/bin/init-firewall-bedrock-bypass.sh"
```

**方法2: Dockerfileを編集**
```dockerfile
COPY init-firewall-bedrock-bypass.sh /usr/local/bin/init-firewall.sh
```

**方法3: コンテナ内で手動実行**
```bash
sudo /usr/local/bin/init-firewall-bedrock-bypass.sh
```

#### 動作確認

スクリプト実行後、以下のような出力で動作を確認できます：

```
=== Bedrock Bypass Status ===
Bedrock IPs in bypass list:
[Bedrock IPアドレスのリスト]

Testing connectivity...
✅ Firewall blocking general traffic as expected
✅ GitHub API accessible
✅ Bedrock endpoint accessible (403 is expected without auth)
```

この設定により：
- ✅ Bedrock APIへの通信は常に許可
- ✅ GitHub、npm、Anthropic APIなど必要なサービスは許可
- ❌ その他の不要な外部通信はブロック

## Transparent Proxy Solution (transparent-proxy-solution.sh)

動的IPアドレス問題に対する別のアプローチとして、透過型プロキシソリューションを用意しました。このスクリプトは、IPベースのフィルタリングではなく、ドメインベースのフィルタリングを実現します。

### 概要

`transparent-proxy-solution.sh`は、socatを使用してローカルプロキシを作成し、Amazon Bedrockエンドポイントへの通信を中継します。これにより、動的IPアドレスの変更を気にすることなく、安定した接続を維持できます。

### 動作原理

1. **ローカルプロキシの作成**
   - `localhost:8443` → `bedrock-runtime.${BEDROCK_REGION}.amazonaws.com:443`
   - `localhost:8444` → `bedrock.${BEDROCK_REGION}.amazonaws.com:443`
   - `localhost:8445` → `sts.${BEDROCK_REGION}.amazonaws.com:443`

2. **socatによる透過的な中継**
   - TCPレベルでの透過的な通信中継
   - フォークモードで複数接続を処理
   - ポートの再利用可能設定

### 使用方法

#### 手動実行
```bash
# コンテナ内で実行
sudo /usr/local/bin/transparent-proxy-solution.sh
```

#### 環境変数の設定
スクリプト実行後、以下の環境変数を設定してAWS SDKがプロキシを使用するようにします：

```bash
export AWS_ENDPOINT_URL_BEDROCK=https://localhost:8443
export AWS_ENDPOINT_URL_BEDROCK_RUNTIME=https://localhost:8443
export AWS_ENDPOINT_URL_STS=https://localhost:8445
```

### メリット

1. **動的IP問題の完全な解決**
   - DNSの変更に自動的に追従
   - IPアドレスの再解決が不要

2. **シンプルな実装**
   - 複雑なファイアウォールルールが不要
   - メンテナンスが容易

3. **デバッグの容易さ**
   - プロキシログで通信を確認可能
   - 接続問題の切り分けが簡単

### 注意事項

- このソリューションはHTTPS証明書の検証に影響を与える可能性があります
- 本番環境での使用は推奨されません（開発環境専用）
- socatプロセスがバックグラウンドで実行され続けます

### トラブルシューティング

プロキシの状態確認：
```bash
# socatプロセスの確認
ps aux | grep socat

# リスニングポートの確認
netstat -tlnp | grep -E '8443|8444|8445'

# プロキシ経由での接続テスト
curl -I https://localhost:8443
```