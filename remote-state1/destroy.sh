#!/bin/bash
set -euo pipefail  # Enable strict error handling

# Set Variables
BUCKET_NAME="bucket-pet-adoption6vg"
AWS_REGION="us-east-1"
PROFILE="pet_team"

# Function to handle errors
handle_error() {
    echo "❌ Error: $1"
    exit 1
}

# Empty the S3 Bucket
echo "🧹 Emptying S3 bucket: $BUCKET_NAME..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE" 2>/dev/null; then
    if ! aws s3 rm "s3://$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE" --recursive; then
        handle_error "Failed to empty S3 bucket '$BUCKET_NAME'."
    fi
    echo "✅ S3 bucket '$BUCKET_NAME' emptied successfully."
else
    echo "⚠️  Bucket '$BUCKET_NAME' does not exist. Skipping deletion."
    exit 0
fi

# Delete the S3 Bucket
echo "🗑️ Deleting S3 bucket: $BUCKET_NAME..."
if ! aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --profile "$PROFILE"; then
    handle_error "Failed to delete S3 bucket '$BUCKET_NAME'."
fi
echo "✅ S3 bucket '$BUCKET_NAME' deleted successfully."

echo "🎉 S3 Remote State Bucket Destroyed!"