FROM delphairegistry/dind-az-kctl-helm:v1.6
COPY . /app
RUN chmod 777 /app/bento.sh
CMD /app/bento.sh