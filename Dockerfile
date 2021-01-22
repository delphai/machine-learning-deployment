FROM delphairegistry/dind-az-kctl-helm:v1.6
COPY . /app
RUN chmod 777 /app/run.sh
CMD /app/run.sh