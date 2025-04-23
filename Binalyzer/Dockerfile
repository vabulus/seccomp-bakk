FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y \
  gcc \
  strace \
  vim \
  build-essential \
  libseccomp-dev \
  python3.8 \
  python3.8-venv \
  python3.8-distutils \
  iproute2 \
  libpcre3 \
  libpcre3-dev \
  libapr1-dev \
  libaprutil1-dev \
  git \
  wget \
  curl

# Set python and pip to point to Python 3.8
RUN ln -sf /usr/bin/python3.8 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.8 /usr/bin/python && \
    wget https://bootstrap.pypa.io/get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py

RUN git clone https://github.com/IAIK/Chestnut.git /Chestnut
WORKDIR /Chestnut/Binalyzer
ADD full_ldd.py /Chestnut/Binalyzer/
ADD requirements.txt /Chestnut/Binalyzer/

# Create venv *after* pip is set up
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip && \
    pip install -r requirements.txt

RUN echo 'source /Chestnut/Binalyzer/venv/bin/activate' >> ~/.bashrc

CMD ["/bin/bash"]
