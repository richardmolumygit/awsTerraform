#!/usr/bin/env bash
set -e

BUCKET_NAME="rich-molumby-s3-bucket-20261006"
REGION="us-east-1"

# Check if the bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then

  echo
  echo "Fetch versions and delete them if they exist for S3 bucket: $BUCKET_NAME"
  
  # 1. Fetch versions and delete if they exist
  aws s3api list-object-versions --bucket $BUCKET_NAME \
   --output json --query 'Versions[].{Key:Key,VersionId:VersionId}' | grep -q "Key" \
   && aws s3api delete-objects \
   --bucket $BUCKET_NAME \
   --delete "$(aws s3api list-object-versions \
      --bucket $BUCKET_NAME \
      --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}')" || \
      echo "No versions to delete."

  echo "Delete all delete markers for S3 bucket: $BUCKET_NAME..."
  
  # Delete all delete markers
  aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --output json --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' | grep -q "Key" \
      && aws s3api delete-objects \
      --bucket $BUCKET_NAME \
      --delete "$(aws s3api list-object-versions \
      --bucket $BUCKET_NAME \
      --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}')" || echo "No delete markers to delete."

  # Delete the bucket
  echo "Deleting S3 bucket: $BUCKET_NAME..."
  aws s3 rb s3://$BUCKET_NAME
    
  echo "S3 bucket '$BUCKET_NAME' deleted."

fi
