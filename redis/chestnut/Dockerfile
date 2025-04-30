FROM vulhub/redis:5.0.7

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
  curl \
  patchelf



WORKDIR /
RUN git clone https://github.com/IAIK/Chestnut.git
WORKDIR /Chestnut/Binalyzer

RUN python3 -m venv venv

ADD full_ldd.py /Chestnut/Binalyzer/
ADD requirements.txt /Chestnut/Binalyzer/

RUN . /Chestnut/Binalyzer/venv/bin/activate && pip install --upgrade pip

RUN . /Chestnut/Binalyzer/venv/bin/activate && pip install -r requirements.txt

RUN echo 'source /Chestnut/Binalyzer/venv/bin/activate' >> ~/.bashrc

ADD attack.sh /tmp/attack.sh
RUN chmod +x /tmp/attack.sh

EXPOSE 6379

CMD ["/bin/bash"]
