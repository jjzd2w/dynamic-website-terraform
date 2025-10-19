#!/bin/bash

# Create ZIP files for Lambda functions
echo "Creating Lambda deployment packages..."
cd lambda
zip -r get_string.zip get_string.py
zip -r update_string.zip update_string.py
cd ..

# Initialize and deploy Terraform
echo "Deploying infrastructure with Terraform..."
terraform init
terraform apply -auto-approve

# Get the API endpoint
API_URL=$(terraform output -raw api_url)

# Update the Lambda function with the API URL
echo "Updating Lambda environment variables..."
aws lambda update-function-configuration \
    --function-name get_dynamic_string \
    --environment "Variables={TABLE_NAME=DynamicStringTable,API_URL=$API_URL}"

echo "Deployment complete!"
echo "Website URL: $(terraform output -raw website_url)"
echo "API URL: $API_URL"
