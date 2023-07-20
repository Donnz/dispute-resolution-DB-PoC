FROM ubuntu:focal

USER root

RUN apt-get -qq update && \
    apt-get -qq install --yes --no-install-recommends locales curl git htop vim wget python3-pip less unzip lsb-release gpg sudo apt-utils

RUN curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
RUN sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
RUN echo "deb http://cz.archive.ubuntu.com/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/acl.list

RUN sudo apt-get -qq update && \
    sudo apt-get -qq install --yes redis-stack-server redis-tools acl

# Set up locales properly
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Use bash as default shell, rather than sh
ENV SHELL /bin/bash

# Set up user
ARG NB_USER=disputer
ARG NB_UID=1000
ARG GIT_PREFIX=https://github.com
ARG GIT_USER=Donnz
ARG GIT_REPO=dispute-resolution-DB-PoC

ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

RUN setfacl -R -m u:${NB_UID}:rwx ${HOME}

# building the repo
WORKDIR ${HOME}

RUN git clone ${GIT_PREFIX}/${GIT_USER}/${GIT_REPO}
WORKDIR ${HOME}/${GIT_REPO}

RUN apt-get install $(grep -vE "^\s*#" ./binder/apt.txt  | tr "\n" " ")

USER ${NB_USER}
RUN pip3 install -r ./binder/requirements.txt
USER root

RUN apt-get -qq purge && \
    apt-get -qq clean && \
    apt-get autoclean  -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN ./binder/postBuild

USER ${NB_USER}
# Specify the default command to run
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]

CMD jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser --notebook-dir=/jupyter/data --allow-root --NotebookApp.token=''