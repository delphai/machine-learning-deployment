
#!/bin/bash

set -e
# Variables
REPO_URL="https://ahmedmahmo:$INPUT_GITHUB_TOKEN@github.com/delphai/$REPOSITORY_NAME"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# 1 - Authenticate to Azure
cd /app
echo "Authenticating to Azure...."
az login --service-principal --username $INPUT_CLIENT_ID --password $INPUT_CLIENT_SECRET --tenant $INPUT_TENANT_ID
echo "Azure Authentication complete."

# Check Subscription
echo "Checking Subscription..."
SUBSCRIPTION=$(az account show | jq .name -r)
echo "${SUBSCRIPTION}"
# 2 - Clone Repo 
echo "cloning $REPOSITORY_NAME...."
git clone ${REPO_URL}
echo "$REPOSITORY_NAME cloned."

# Change Directory to the repo
cd /app/$REPOSITORY_NAME || exit
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
pipenv lock -r > requirements.txt
python3.8 -m pip install -r requirements.txt
# 4 - Bundel the model
echo "BentoML Bundeling..."
python3.8 /app/$REPOSITORY_NAME/src/save.py
echo "Successfully bundeled."

# 5 - Build Docker Image 
echo "Start Building BentoML image..."
SAVED_PATH=$(bentoml get $INPUT_CLASS_NAME:latest --print-location --quiet)
echo "Saved path for bundeled app is ${SAVED_PATH}"

# add cuda
d=${SAVED_PATH}/Dockerfile
cat << EOF >> $d                                                                                                            
FROM nvidia/cuda:11.2.1-devel-ubuntu20.04
WORKDIR /app/
ENV PORT 5000
EXPOSE $PORT
COPY --from=0 /bento .
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y curl \
    && apt-get install unzip \
    && apt-get -y install python3.8 \
    && apt-get -y install python3-pip
RUN pip3 install -r requirements.txt && pip3 install bentoml
ENTRYPOINT [ "./docker-entrypoint.sh" ]
CMD ["bentoml", "serve-gunicorn", "/app"]
EOF

echo "Building docker image..."
REGISTRY=delphaicommon.azurecr.io
docker build -t ${REGISTRY}/$REPOSITORY_NAME:latest ${SAVED_PATH}

# 6 - Push docker image
echo "Authenticating Docker..."
REGISTRY_PASSWORD=$(az acr credential show -n delphaicommon | jq .passwords | jq '.[0]' | jq .value -r)
REGISTRY_USERNAME=$(az acr credential show -n delphaicommon | jq .username -r)
docker login ${REGISTRY} -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} 
echo "Docker Successfilly authenticated."
echo "Pushing Image to delphai registry..."
docker push ${REGISTRY}/$REPOSITORY_NAME:latest
IMAGE=$(docker inspect --format='{{index .RepoDigests 0}}' delphaicommon.azurecr.io/$REPOSITORY_NAME:latest)

# 7 - Set Kubernetes Kontext
echo "Setting Kubernetes Kontext..."
az aks get-credentials -n delphai-common -g tf-cluster 
kubectl config current-context
DOMAIN=$(kubectl get secret domain -o json --namespace default | jq .data.domain -r | base64 -d)

# 8 - Deploy to kubernetes
echo "Deploying to kubernetes..."
kubectl create namespace $REPOSITORY_NAME --output yaml --dry-run=client | kubectl apply -f -
kubectl patch serviceaccount default --namespace $REPOSITORY_NAME -p "{\"imagePullSecrets\": [{\"name\": \"acr-credentials\"}]}"
helm repo add delphai https://delphai.github.io/helm-charts && helm repo update

echo "Using helm delphai-machine-learning"
  
helm upgrade --install --atomic  --reset-values\
    $REPOSITORY_NAME\
    delphai/delphai-machine-learning \
    --namespace=$REPOSITORY_NAME \
    --set domain=${DOMAIN} \
    --set image=${IMAGE} \
    --set httpPort=5000 \
    --set delphaiEnvironment=common \
    --set minScale=1 \
    --set concurrency=50
