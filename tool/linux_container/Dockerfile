# Linux build environment for tool/linux_container/test.sh: Ubuntu 24.04, the
# Linux app build tools from README.md, a virtual display and a session bus,
# and Flutter at the version in .fvmrc (test.sh passes it as FLUTTER_VERSION).
FROM ubuntu:24.04
ARG FLUTTER_VERSION
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git curl unzip xz-utils zip \
      clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev \
      xvfb xauth dbus-x11 xdg-utils desktop-file-utils \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m dev
USER dev
WORKDIR /home/dev
RUN test -n "$FLUTTER_VERSION" && git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git
ENV PATH="/home/dev/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-linux-desktop && flutter precache --linux && flutter --version
