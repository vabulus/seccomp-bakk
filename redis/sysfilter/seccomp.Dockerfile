# Stage 1: Copy from vulhub's vulnerable redis image
FROM vulhub/redis:5.0.7

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y \
  gcc \
  strace \
  vim \
  build-essential \
  libseccomp-dev \
  python3 \
  iproute2 \
  python3-pip \
  git \
  lcov \
  libreadline-dev \
  gdb \
  lsb-release \
  libc6-dbg \
  python3-parameterized \
  patchelf \
  liblua5.1-0 \
  liblua5.1-0-dev \
  ca-certificates \
  curl \
  wget \
  make \
  automake \
  libtool \
  pkg-config \
  tcl \
  lua5.1

# Clone and build sysfilter
WORKDIR /
RUN git clone --recursive https://gitlab.com/Egalito/sysfilter.git && \
    cd /sysfilter/extraction && make


EXPOSE 6379

CMD ["/bin/bash"]
