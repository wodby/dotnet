# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE argument: the ASP.NET Core
# runtime for ordinary images and the .NET SDK, which contains that runtime, for -dev images.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG DOTNET_DEV
LABEL com.wodby.workspace.contract="${DOTNET_DEV:+1}"

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ENV DOTNET_DEV="${DOTNET_DEV}" \
    SSHD_PERMIT_USER_ENV="yes"

# The upstream Alpine images run in globalization-invariant mode because they ship without ICU.
# This image adds ICU and the full culture data, so cultures, collation and SQL Server clients work.
ENV APP_ROOT="/usr/src/app" \
    CONF_DIR="/usr/src/conf" \
    FILES_DIR="/mnt/files" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/wodby/.shrc" \
    \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT="false" \
    DOTNET_CLI_TELEMETRY_OPTOUT="1" \
    DOTNET_NOLOGO="1" \
    \
    GIT_USER_EMAIL="wodby@example.com" \
    GIT_USER_NAME="wodby"

ENV PATH="/home/wodby/.dotnet/tools:${PATH}"

ARG TARGETPLATFORM

# Upgrade inherited packages even when their existing versions satisfy dependencies.
RUN set -xe; \
    apk upgrade --no-cache; \
    \
    # Delete existing user/group if uid/gid occupied. \
    existing_group=$(getent group "${WODBY_GROUP_ID}" | cut -d: -f1 || true); \
    if [ -n "${existing_group}" ]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${WODBY_USER_ID}" | cut -d: -f1 || true); \
    if [ -n "${existing_user}" ]; then deluser "${existing_user}"; fi; \
    \
    addgroup -g "${WODBY_GROUP_ID}" -S wodby; \
    adduser -u "${WODBY_USER_ID}" -D -S -s /bin/bash -G wodby wodby; \
    sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    apk add --update --no-cache -t .wodby-dotnet-run-deps \
        bash \
        ca-certificates \
        curl \
        git \
        gzip \
        icu-data-full \
        icu-libs \
        less \
        make \
        mariadb-client \
        nano \
        openssh \
        openssh-client \
        patch \
        postgresql-client \
        rsync \
        su-exec \
        sudo \
        tar \
        tig \
        tmux \
        tzdata \
        unzip \
        wget; \
    \
    if [ -n "${DOTNET_DEV}" ]; then \
        apk add --no-cache ripgrep jq; \
    fi; \
    \
    # Download helper scripts. \
    dockerplatform=${TARGETPLATFORM:-linux/amd64}; \
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-$(echo "${dockerplatform}" | tr / -).tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    git clone https://github.com/wodby/alpine /tmp/alpine; \
    cd /tmp/alpine; \
    latest=$(git describe --abbrev=0 --tags); \
    git checkout "${latest}"; \
    mv /tmp/alpine/bin/* /usr/local/bin; \
    \
    # Install redis-cli. \
    apk add --update --no-cache redis; \
    mv /usr/bin/redis-cli /tmp/; \
    apk del --purge redis; \
    deluser redis; \
    mv /tmp/redis-cli /usr/bin; \
    \
    install -o wodby -g wodby -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        /home/wodby/.dotnet/tools \
        /home/wodby/.ssh; \
    \
    { \
        echo 'export PS1="\u@$(hostname):\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee /home/wodby/.shrc; \
    \
    cp /home/wodby/.shrc /home/wodby/.bashrc; \
    cp /home/wodby/.shrc /home/wodby/.bash_profile; \
    \
    # Configure sudoers. \
    { \
        echo "Defaults secure_path=\"$PATH\""; \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR DOTNET_ROOT NUGET_PACKAGES"'; \
        \
        if [ -n "${DOTNET_DEV}" ]; then \
            echo 'wodby ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'wodby ALL=(root) NOPASSWD:SETENV: '; \
            echo -n '/usr/local/bin/gen_ssh_keys, '; \
            echo -n '/usr/local/bin/init_container, '; \
            echo -n '/usr/sbin/sshd, '; \
            echo '/usr/sbin/crond'; \
        fi; \
    } | tee /etc/sudoers.d/wodby; \
    \
    touch /etc/ssh/sshd_config; \
    chown wodby:wodby /etc/ssh/sshd_config /home/wodby/.*; \
    \
    rm -rf \
        /etc/crontabs/root \
        /tmp/* \
        /var/cache/apk/*

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 8080

COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY bin /usr/local/bin/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dotnet-app"]

COPY workspace-profile.sh /etc/profile.d/workspace.sh
