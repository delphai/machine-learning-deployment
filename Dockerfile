FROM delphairegistry/dind-az-kctl-helm:v1.2
COPY . /app
CMD /app/run.sh