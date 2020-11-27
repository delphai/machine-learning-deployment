FROM delphairegistry/dind-az-kctl-helm:v1
COPY . /app
CMD /app/run.sh