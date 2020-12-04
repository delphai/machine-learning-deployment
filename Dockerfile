FROM delphairegistry/dind-az-kctl-helm:v1.3
COPY . /app
CMD /app/run.sh