ARG FEDORA_VERSION=44
FROM fedora:${FEDORA_VERSION}

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Etc/UTC

RUN dnf -y install --setopt=install_weak_deps=False \
        sudo \
        curl \
        wget \
        ca-certificates \
        gnupg2 \
        glibc-langpack-en \
        tzdata \
        git \
        file \
        findutils \
        diffutils \
        procps-ng \
        shadow-utils \
        util-linux \
        @development-tools \
    && dnf clean all

RUN useradd -m -s /bin/bash -G wheel tester \
    && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
    && chmod 0440 /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester/repo
