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
  libpcre3 \
  libpcre3-dev \
  libapr1-dev \ 
  libaprutil1-dev \
  git \ 
  python3.8-venv


WORKDIR /
RUN git clone https://github.com/IAIK/Chestnut.git
WORKDIR /Chestnut/Binalyzer

RUN python3 -m venv venv
RUN . /Chestnut/Binalyzer/venv/bin/activate && pip install --upgrade pip

RUN . /Chestnut/Binalyzer/venv/bin/activate && pip install -r requirements.txt

RUN echo 'source /Chestnut/Binalyzer/venv/bin/activate' >> ~/.bashrc


EXPOSE 6379

CMD ["/bin/bash"]
