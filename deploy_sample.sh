#!/bin/bash
set -euo pipefail

# ============================================================
# Deploy WambdaInitProject CICD CloudFormation Stacks
# ============================================================

REGION=ap-northeast-1

CODESTAR_CONNECTION_ARN="arn:aws:codeconnections:REGION:ACCOUNT_ID:connection/CONNECTION_ID"

# S3 bucket names (replace with actual values)
CSR001_S3_BUCKET_NAME="your-s3-bucket-name-csr001"
SSR001_S3_BUCKET_NAME="your-s3-bucket-name-ssr001"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Deploying WambdaInitProject CICD Stacks ==="

# 1. Common: Infra CodeBuild
echo ""
echo "--- [1/5] common/codebuild-infra ---"
aws cloudformation deploy \
  --region "$REGION" \
  --template-file "$SCRIPT_DIR/common/codebuild-infra.yaml" \
  --stack-name stack-wambda-cicd-infra \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodeStarConnectionArn="$CODESTAR_CONNECTION_ARN"

# 2. CSR001: Backend CodeBuild
echo ""
echo "--- [2/5] csr001-backend/codebuild-backend ---"
aws cloudformation deploy \
  --region "$REGION" \
  --template-file "$SCRIPT_DIR/csr001-backend/codebuild-backend.yaml" \
  --stack-name stack-wambda-cicd-csr001-backend \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodeStarConnectionArn="$CODESTAR_CONNECTION_ARN"

# 3. CSR001: Frontend CodeBuild
echo ""
echo "--- [3/5] csr001-frontend/codebuild-frontend ---"
aws cloudformation deploy \
  --region "$REGION" \
  --template-file "$SCRIPT_DIR/csr001-frontend/codebuild-frontend.yaml" \
  --stack-name stack-wambda-cicd-csr001-frontend \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodeStarConnectionArn="$CODESTAR_CONNECTION_ARN" \
    S3BucketName="$CSR001_S3_BUCKET_NAME"

# 4. SSR001: App CodeBuild
echo ""
echo "--- [4/5] ssr001/codebuild-app ---"
aws cloudformation deploy \
  --region "$REGION" \
  --template-file "$SCRIPT_DIR/ssr001/codebuild-app.yaml" \
  --stack-name stack-wambda-cicd-ssr001-app \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodeStarConnectionArn="$CODESTAR_CONNECTION_ARN" \
    S3BucketName="$SSR001_S3_BUCKET_NAME"

echo ""
echo "=== All CICD stacks deployed successfully ==="
