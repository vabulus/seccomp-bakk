FROM binalyzer-base

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
  libaprutil1-dev


ADD main.c /app/
ADD Makefile /app/

WORKDIR /app

RUN make -j$(nproc)

RUN chmod u+s /usr/bin/python3.6
RUN chmod g+s /usr/bin/find

ADD script.sh /tmp/script.sh
RUN chmod +x /tmp/script.sh

RUN adduser user
RUN chown -R user /app/ && chown -R user /tmp/script.sh && chown -R user /Chestnut/
USER user
RUN echo 'source /Chestnut/Binalyzer/venv/bin/activate' >> /home/user/.bashrc

CMD ["/bin/bash"]
