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

ADD httpd-2.4.49.tar.gz /app
WORKDIR /app/httpd-2.4.49

# apply seccomp patch
ADD main.PATCH /tmp
RUN patch /app/server/main.c < /tmp/main.PATCH

# build the apache server
RUN ./configure --prefix=/opt/apache --enable-mods-shared=all --enable-cgi --enable-unixd LDFLAGS="-lseccomp"
RUN make -j$(nproc)
RUN make install

# apply httpd conf patches to make apache vulnerable
ADD http.conf.PATCH /tmp/
RUN patch /opt/apache/conf/httpd.conf < /tmp/http.conf.PATCH

CMD ["/bin/bash"]

