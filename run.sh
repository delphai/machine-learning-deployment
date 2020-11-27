#!/bin/bash

set -e
# Variables
REPO_URL="https://ahmedmahmo:$INPUT_GITHUB_TOKEN@github.com/delphai/$INPUT_REPO_NAME"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# 1 - Authenticate to Azure
cd /app
echo "Authenticating to Azure...."
az login --service-principal --username $INPUT_CLIENT_ID --password $INPUT_CLIENT_SECRET --tenant $INPUT_TENANT_ID
echo "Azure Authentication complete."

# Check Subscription
echo "Checking Subscription..."
SUBSCRIPTION=$(az account show | jq .name -r)
if [ "$SUBSCRIPTION" == "common" ]; then
    echo "Subscription is ${SUBSCRIPTION}"
else
    echo "Subscription not set correctly -> Exit"
    exit
fi

# 2 - Clone Repo 
echo "cloning $INPUT_REPO_NAME...."
cd /app
git clone ${REPO_URL}
echo "$INPUT_REPO_NAME cloned."

# Change Directory to the repo
cd "${DIR}/$INPUT_REPO_NAME" || exit

# 3 - Download the Model
echo "Given Model name is $INPUT_BLOB_MODEL"
echo "Downloading Model from Azure blob..."
az storage blob download-batch -d . -s $INPUT_BLOB_MODEL --account-name tfdelphaicommon --connection-string $INPUT_CONNECTION_STRING
echo "Model $INPUT_BLOB_MODEL successfully downloaded."

# 4 - Bundel the model

echo "BentoML Bundeling..."
python3.8 /app/$INPUT_REPO_NAME/src/save.py
echo "Successfully bundeled."