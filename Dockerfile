FROM delphairegistry/dind-az-kctl-helm:v1.6
COPY . /app
CMD /app/run.sh