#!/bin/bash

set -e

# Validate input
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <bucket-name> <aws-region>"
  echo "Example: sh ./create_s3_bucket.sh devopslearningcircle-terraform-statefile us-east-1"
  exit 1
fi

BUCKET_NAME="$1"
REGION="$2"

# Check if bucket exists
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'AccessDenied\|AllAccessDisabled\|NoSuchBucket'; then
  echo "Bucket '$BUCKET_NAME' does not exist or is not accessible. Proceeding to create..."
else
  echo "Bucket '$BUCKET_NAME' exists. Deleting..."

  # Delete all objects in the bucket (recursively)
  aws s3 rm "s3://$BUCKET_NAME" --recursive

  # Now delete the bucket
  aws s3 rb "s3://$BUCKET_NAME" --region "$REGION"
  echo "Bucket '$BUCKET_NAME' deleted."
fi

# Create the new bucket
if [ "$REGION" == "us-east-1" ]; then
  aws s3 mb "s3://$BUCKET_NAME"
else
  aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
fi
echo "Bucket '$BUCKET_NAME' created successfully in region '$REGION'."

aws dynamodb create-table --table-name terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST