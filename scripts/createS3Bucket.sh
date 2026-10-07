#!/usr/bin/env bash
set -e

BUCKET_NAME="rich-molumby-s3-bucket-20261006"
REGION="us-east-1"

# Check if the bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "State bucket '$BUCKET_NAME' already exists."
else
  echo "Creating S3 state bucket: $BUCKET_NAME..."
  
  # Create the bucket (Note: us-east-1 does not require a LocationConstraint)
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"

  echo "Turn on vesioning for data saftey"
  
  # Turn on versioning for data safety
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
    
  echo "S3 bucket created and configured."
fi
