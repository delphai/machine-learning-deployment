FROM delphairegistry/dind-az-kctl-helm:v1.5
COPY . /app
CMD /app/run.sh