FROM delphairegistry/helm:latest
COPY . /app
RUN pip install bentoml
RUN chmod 777 /app/deploy.sh
ENTRYPOINT [ "/app/deploy.sh" ]