# =============================================================================
# Terraform Remote State Backend
# =============================================================================
# Uncomment the block below after creating the S3 bucket and DynamoDB table
# for state management. You can create them with:
#
#   aws s3api create-bucket \
#     --bucket rhsim-terraform-state-<ACCOUNT_ID> \
#     --region us-east-1
#
#   aws s3api put-bucket-versioning \
#     --bucket rhsim-terraform-state-<ACCOUNT_ID> \
#     --versioning-configuration Status=Enabled
#
#   aws s3api put-bucket-encryption \
#     --bucket rhsim-terraform-state-<ACCOUNT_ID> \
#     --server-side-encryption-configuration '{
#       "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}}]
#     }'
#
#   aws dynamodb create-table \
#     --table-name rhsim-terraform-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region us-east-1
#
# Then uncomment and update the bucket name below:
# =============================================================================

# terraform {
#   backend "s3" {
#     bucket         = "rhsim-terraform-state-ACCOUNT_ID"
#     key            = "rhsim/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "rhsim-terraform-lock"
#   }
# }
