# dynamic-website-terraform
Create site using terraform to aws 

Usage

    Deploy the infrastructure:
    bash

chmod +x deploy.sh
./deploy.sh

Update the dynamic string:
bash

# Replace YOUR_API_URL with the actual API Gateway URL from outputs
curl -X POST https://YOUR_API_URL/update \
  -H "Content-Type: application/json" \
  -d '{"string": "Hello from Lambda!"}'
