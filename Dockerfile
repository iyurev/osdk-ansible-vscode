FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu

ENV OS=linux
ENV ARCH=amd64
#Tools versions
ARG OPM_VERSION=v1.19.1
ARG OPERATOR_SDK_VERSION=v1.22.0
ARG KUSTOMIZE_VERSION=v3.8.7



#Install Docker CLI
RUN apt-get update && \
    apt-get -y install ca-certificates curl gnupg lsb-release && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" |  tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get -y install docker-ce-cli

#Install kustomize
RUN cd /tmp && \
    curl -L -O https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz && \
    tar -xzf kustomize_${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz && \
    mv ./kustomize  /usr/local/bin/ && \
    rm -f  /tmp/kustomize_${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz && \
    chmod +x /usr/local/bin/kustomize


#Install OPM
RUN curl -L -o /usr/local/bin/opm https://github.com/operator-framework/operator-registry/releases/download/${OPM_VERSION}/${OS}-${ARCH}-opm && \
    chmod +x /usr/local/bin/opm

#Install operator-sdk
RUN curl -L -o /usr/local/bin/operator-sdk  https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_${OS}_{$ARCH} && \
    chmod +x /usr/local/bin/operator-sdk 


WORKDIR /root
# Copy python dependencies (including ansible) to be installed using Pipenv
COPY Pipfile* ./
# Instruct pip(env) not to keep a cache of installed packages,
# to install into the global site-packages and
# to clear the pipenv cache as well
ENV PIP_NO_CACHE_DIR=1 \
    PIPENV_SYSTEM=1 \
    PIPENV_CLEAR=1

RUN ln -s /usr/bin/python3.8 /usr/bin/python \
  && apt update && apt -y install pipenv \
  && pip3 install --upgrade pip~=21.1.0 \
  && pip3 install pipenv==2022.1.8 \
  && pipenv install --deploy \
  && rm -rf /var/cache/apt

#Install ansible-operator 
RUN curl -L -o /usr/local/bin/ansible-operator  https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/ansible-operator_${OS}_${ARCH} && \
    chmod +x /usr/local/bin/ansible-operator

#Install OpenShift client and kubectl  tools 
RUN curl -L -o ./oc.tar.gz  https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.8.33/openshift-client-linux-4.8.33.tar.gz && \
    tar -xzf ./oc.tar.gz && \
    mv ./oc /usr/local/bin/ && \
    chmod +x /usr/local/bin/oc &&  \
    rm -f ./oc.tar.gz && \
    mv ./kubectl /usr/local/bin/kubectl

#Install kubectl 
#RUN curl -L -o /usr/local/bin/kubectl  https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && chmod +x /usr/local/bin/kubectl

#Install required ansible collections
USER vscode
COPY --chown=vscode:vscode  requirements.yml /home/vscode/
RUN  ansible-galaxy collection install -r /home/vscode/requirements.yml
#Do the same for root user
USER 0
COPY requirements.yml /root/
RUN  ansible-galaxy collection install -r /root/requirements.yml