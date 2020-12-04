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
git clone ${REPO_URL}
echo "$INPUT_REPO_NAME cloned."

# Change Directory to the repo
cd /app/$INPUT_REPO_NAME || exit
echo "Current dircetory is:"
pwd

# 3 - Download the Model
echo "Given Model name is $INPUT_BLOB_MODEL"
echo "Downloading Model from Azure blob..."
az storage blob download-batch -d . -s $INPUT_BLOB_MODEL --account-name tfdelphaicommon --connection-string $INPUT_CONNECTION_STRING
echo "Model $INPUT_BLOB_MODEL successfully downloaded."

# 4 - Install dependencies 
echo "Install dependencies..."
python3 -V
python -V
apt-get install python-dev -y
apt-get install python3-dev -y
pipenv lock -r > requirements.txt
pip3 install -r requirements.txt
# 4 - Bundel the model
echo "BentoML Bundeling..."
pipenv run python3.8 /app/$INPUT_REPO_NAME/src/save.py
echo "Successfully bundeled."

# 5 - Build Docker Image 
echo "Start Building BentoML image..."
SAVED_PATH=$(bentoml get $INPUT_CLASS_NAME:latest --print-location --quiet)
docker build -t $INPUT_REPO_NAME:latest ${SAVED_PATH}

# 6 - Push docker image
echo "Authenticating Docker..."
REGISTRY_PASSWORD=$(az acr credential show -n delphaicommon | jq .passwords | jq '.[0]' | jq .value -r)
REGISTRY_USERNAME=$(az acr credential show -n delphaicommon | jq .username -r)
REGISTRY=delphaicommon.azurecr.io
docker login ${REGISTRY} -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} 
echo "Docker Successfilly authenticated."
echo "Pushing Image to delphai registry..."
docker push ${REGISTRY}/$INPUT_REPO_NAME:latest
IMAGE=docker inspect --format='{{index .RepoDigests 0}}' delphaicommon.azurecr.io/$INPUT_REPO_NAME:latest

# 7 - Set Kubernetes Kontext
echo "Setting Kubernetes Kontext..."
az aks get-credentials -n delphai-common -g tf-cluster 
kubectl config current-context
DOMAIN=$(kubectl get secret domain -o json --namespace default | jq .data.domain -r | base64 -d)

# 8 - Deploy to kubernetes
echo "Deploying to kubernetes..."
kubectl create namespace $INPUT_REPO_NAME --output yaml --dry-run=client | kubectl apply -f -
kubectl patch serviceaccount default --namespace $INPUT_REPO_NAME -p "{\"imagePullSecrets\": [{\"name\": \"acr-credentials\"}]}"
helm repo add delphai https://delphai.github.io/helm-charts && helm repo update
echo "Using helm delphai-knative service"
    helm upgrade --install --wait --atomic \
          $INPUT_REPO_NAME \
          delphai/delphai-knative-service \
          --namespace=$INPUT_REPO_NAME \
          --set image=${IMAGE} \
          --set httpPort=5000 \
          --set grpcPort=8080 \
          --set isPublic=true \
          --set isUi=false \
          --set domain=${DOMAIN} \
          --set delphaiEnvironment=common

kubectl patch deployment $INPUT_REPO_NAME --namespace $INPUT_REPO_NAME -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"