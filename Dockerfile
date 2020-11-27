FROM teracy/ubuntu:18.04-dind-latest
WORKDIR /app
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.0/bin/linux/amd64/kubectl
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN  ./get_helm.sh
RUN apt update && apt install software-properties-common -y
RUN add-apt-repository ppa:deadsnakes/ppa -y
RUN apt install python3.8 -y
RUN apt update && apt install python3-pip -y
RUN pip3 --version
RUN pip3 install bentoml
COPY . /app
ENTRYPOINT [ "bash", "/app/run.sh" ]