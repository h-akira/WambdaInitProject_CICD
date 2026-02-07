# WambdaInitProject CI/CD

WambdaInitProjectのCI/CDパイプライン（CodeBuild）をCloudFormationで管理します。

## 構成

```
WambdaInitProject_CICD/
├── common/
│   └── codebuild-infra.yaml          # Infrastructure (CDK) 用 CodeBuild
├── csr001/
│   ├── codebuild-backend.yaml        # CSR001 Backend (SAM) 用 CodeBuild
│   └── codebuild-frontend.yaml       # CSR001 Frontend (S3) 用 CodeBuild
├── ssr001/
│   └── codebuild-app.yaml            # SSR001 アプリ (SAM + S3) 用 CodeBuild
├── deploy.sh                         # 全スタック一括デプロイスクリプト（実際の設定値）
├── deploy_sample.sh                  # サンプルデプロイスクリプト（テンプレート）
└── README.md
```

**ディレクトリ構成の意図:**
- `common/` - 全サブシステム共通のインフラCI/CD
- `csr001/` - CSR001サブシステムのCI/CD（Backend SAM + Frontend S3）
- `ssr001/` - SSR001サブシステムのCI/CD（SAM + 静的ファイル）
- 将来サブシステムが増えた場合は、同様のディレクトリを追加（例: `csr002/`）

**CSR001の構成:**
- Backend（SAM）とFrontend（Vue.js）を異なるリポジトリで管理
- 独立したデプロイサイクルを実現するため、2つの CodeBuild プロジェクトを使用
- FinanceProjectのパターンに準拠

## デプロイ方法

### 初回セットアップ

1. **deploy.sh の作成**

`deploy_sample.sh` をコピーして `deploy.sh` を作成し、実際の値を設定します：

```bash
cd /Users/hakira/Programs/108_wambda-develop/WambdaInitProject_CICD

# サンプルをコピー
cp deploy_sample.sh deploy.sh

# 以下の値を実際の値に編集
# - CODESTAR_CONNECTION_ARN
# - CSR001_S3_BUCKET_NAME
# - SSR001_S3_BUCKET_NAME
```

**注意**: `deploy.sh` は機密情報を含むため、`.gitignore` で除外されています。

### 簡単デプロイ（推奨）

`deploy.sh`スクリプトで全スタックを一括デプロイできます：

```bash
# AWS_PROFILE を指定して実行
AWS_PROFILE=wambda ./deploy.sh
```

スクリプトは以下の順序でデプロイします：
1. common/codebuild-infra (Infrastructure用)
2. csr001-backend/codebuild-backend (CSR001 Backend用)
3. csr001-frontend/codebuild-frontend (CSR001 Frontend用)
4. ssr001/codebuild-app (SSR001用)

---

### 前提条件

#### 1. CodeStar Connection作成（初回のみ）

GitHub接続を作成します：

```bash
cd /Users/hakira/Programs/108_wambda-develop

AWS_PROFILE=wambda aws codeconnections create-connection \
  --provider-type GitHub \
  --connection-name connect-github-wambda \
  --region ap-northeast-1
```

出力されたARNをメモして、`deploy.sh`の`CODESTAR_CONNECTION_ARN`に設定してください。

次に、AWSコンソールで接続を承認します：
1. CodePipeline → 設定 → 接続
2. 作成した接続を選択
3. 「保留中の接続を更新」→ GitHubで認証

#### 2. S3バケット名の確認

CSR001 と SSR001 の S3 バケット名を確認し、`deploy.sh` に設定します。バケットは CDK で作成されるため、CDK スタックをデプロイする前に名前を決定してください。

---

### 個別デプロイ（マニュアル）

#### Infrastructure CodeBuild のデプロイ

```bash
cd /Users/hakira/Programs/108_wambda-develop

AWS_PROFILE=wambda aws cloudformation deploy \
  --template-file WambdaInitProject_CICD/common/codebuild-infra.yaml \
  --stack-name stack-wambda-cicd-infra \
  --parameter-overrides \
    CodeStarConnectionArn=arn:aws:codeconnections:ap-northeast-1:898133201705:connection/9490a8c2-ed2c-40a2-8067-ce698e531c9a \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

#### CSR001 Backend CodeBuild のデプロイ

```bash
AWS_PROFILE=wambda aws cloudformation deploy \
  --template-file WambdaInitProject_CICD/csr001/codebuild-backend.yaml \
  --stack-name stack-wambda-cicd-csr001-backend \
  --parameter-overrides \
    CodeStarConnectionArn=arn:aws:codeconnections:ap-northeast-1:898133201705:connection/9490a8c2-ed2c-40a2-8067-ce698e531c9a \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

#### CSR001 Frontend CodeBuild のデプロイ

```bash
AWS_PROFILE=wambda aws cloudformation deploy \
  --template-file WambdaInitProject_CICD/csr001/codebuild-frontend.yaml \
  --stack-name stack-wambda-cicd-csr001-frontend \
  --parameter-overrides \
    CodeStarConnectionArn=arn:aws:codeconnections:ap-northeast-1:898133201705:connection/9490a8c2-ed2c-40a2-8067-ce698e531c9a \
    S3BucketName=hakira0627-s3-wambda-csr001-main \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

#### SSR001 App CodeBuild のデプロイ

```bash
AWS_PROFILE=wambda aws cloudformation deploy \
  --template-file WambdaInitProject_CICD/ssr001/codebuild-app.yaml \
  --stack-name stack-wambda-cicd-ssr001-app \
  --parameter-overrides \
    CodeStarConnectionArn=arn:aws:codeconnections:ap-northeast-1:898133201705:connection/9490a8c2-ed2c-40a2-8067-ce698e531c9a \
    S3BucketName=hakira0627-s3-wambda-ssr001-main \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

---

## 更新

CloudFormationテンプレートを修正した後、同じコマンドで更新できます。

---

## 削除

逆順で削除する必要があります：

```bash
cd /Users/hakira/Programs/108_wambda-develop

# SSR001 App CodeBuild 削除
AWS_PROFILE=wambda aws cloudformation delete-stack \
  --stack-name stack-wambda-cicd-ssr001-app \
  --region ap-northeast-1

# CSR001 Frontend CodeBuild 削除
AWS_PROFILE=wambda aws cloudformation delete-stack \
  --stack-name stack-wambda-cicd-csr001-frontend \
  --region ap-northeast-1

# CSR001 Backend CodeBuild 削除
AWS_PROFILE=wambda aws cloudformation delete-stack \
  --stack-name stack-wambda-cicd-csr001-backend \
  --region ap-northeast-1

# Infrastructure CodeBuild 削除
AWS_PROFILE=wambda aws cloudformation delete-stack \
  --stack-name stack-wambda-cicd-infra \
  --region ap-northeast-1
```

---

## スタック状態確認

```bash
cd /Users/hakira/Programs/108_wambda-develop

# Infrastructure
AWS_PROFILE=wambda aws cloudformation describe-stacks \
  --stack-name stack-wambda-cicd-infra \
  --region ap-northeast-1

# CSR001 Backend
AWS_PROFILE=wambda aws cloudformation describe-stacks \
  --stack-name stack-wambda-cicd-csr001-backend \
  --region ap-northeast-1

# CSR001 Frontend
AWS_PROFILE=wambda aws cloudformation describe-stacks \
  --stack-name stack-wambda-cicd-csr001-frontend \
  --region ap-northeast-1

# SSR001 App
AWS_PROFILE=wambda aws cloudformation describe-stacks \
  --stack-name stack-wambda-cicd-ssr001-app \
  --region ap-northeast-1
```

---

## GitHubリポジトリ構成

このCI/CD構成は以下のGitHubリポジトリを想定しています：

- `WambdaInitProject_Infra` - CDKインフラコード
- `WambdaInitProject_CSR001_Backend` - CSR001 Backendコード（SAM）
- `WambdaInitProject_CSR001_Frontend` - CSR001 Frontendコード（Vue.js）
- `WambdaInitProject_SSR001` - SSR001コード（SAM + 静的ファイル）

各リポジトリのmainブランチへのpushで自動的にCodeBuildが起動します。
