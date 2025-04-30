FROM ubuntu:18.04

RUN apt-get update && apt-get -y install \
    build-essential \
    libc6-dbg \
    git \
    lcov \
    libreadline-dev \
    gdb \
    lsb-release \
    vim \
    python3-parameterized \
    patchelf 

WORKDIR /
RUN git clone --recursive https://gitlab.com/Egalito/sysfilter.git
RUN cd /sysfilter/extraction && make

CMD ["/bin/bash"]
