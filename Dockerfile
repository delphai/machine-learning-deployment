FROM delphairegistry/dind-az-kctl-helm:v1.4
COPY . /app
CMD /app/run.sh