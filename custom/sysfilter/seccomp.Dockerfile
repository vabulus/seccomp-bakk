FROM sysfilter-base

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

RUN adduser user
RUN chown -R user /app/
USER user


CMD ["/bin/bash"]

