FROM ubuntu:focal

USER root

ENV TZ=Etc/Universal
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -qq update && \
    apt-get -qq install --yes --no-install-recommends locales curl git htop vim wget python3-pip less unzip lsb-release gpg sudo apt-utils gnupg

RUN curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
RUN curl https://downloads.apache.org/cassandra/KEYS | sudo apt-key add -
RUN curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor

RUN sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
RUN echo "deb https://debian.cassandra.apache.org 41x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
RUN echo "deb http://cz.archive.ubuntu.com/ubuntu trusty main" | sudo tee /etc/apt/sources.list.d/acl.list
RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

RUN curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
sudo apt-get install -y nodejs

RUN sudo apt-get -qq update && \
    sudo apt-get -qq install --yes redis-stack-server redis-tools acl cassandra mongodb-org

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

ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}
WORKDIR ${HOME}

RUN setfacl -R -m u:root:rwx ${HOME}
RUN setfacl -R -m u:${NB_UID}:rwx ${HOME}
RUN setfacl -R -m u:${NB_UID}:rwx /var
RUN chown -R ${NB_UID} /etc /bin /home /var /opt /srv

COPY . ./
RUN apt-get install -y --no-install-recommends - $(grep -vE "^\s*#" ./setup/apt.txt  | tr "\n" " ")

RUN pip3 install -r ./setup/requirements.txt

RUN apt-get -qq purge && \
    apt-get -qq clean && \
    apt-get autoclean  -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x ./setup/postBuild
RUN ./setup/postBuild

RUN chmod +x ./setup/start
RUN ./setup/start

USER ${NB_USER}
# Specify the default command to run
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]

CMD jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser --notebook-dir=/labs --allow-root --NotebookApp.token=''