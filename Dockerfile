FROM delphairegistry/dind-az-kctl-helm:v1.1
COPY . /app
CMD /app/test.sh