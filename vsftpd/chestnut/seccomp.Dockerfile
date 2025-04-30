FROM binalyzer-base

RUN apt-get update -y && apt-get install -y \
  gcc \
  strace \
  vim \
  build-essential \
  libseccomp-dev \
  iproute2


RUN adduser ftp
RUN chmod 555 /home/ftp
RUN mkdir -p /var/share/empty

ADD vsftpd-2.3.4-infected.tar.gz /app
ADD vsftpd.conf /app/vsftpd-2.3.4-infected
ADD Makefile.PATCH /app/vsftpd-2.3.4-infected

WORKDIR /app/vsftpd-2.3.4-infected

# RUN patch /app/main.c /app/main.c.PATCH && patch /app/Makefile /app/Makefile.PATCH
RUN patch Makefile Makefile.PATCH

RUN make

ADD script.sh /tmp/script.sh
RUN chmod +x /tmp/script.sh

ADD rewrite.sh /Chestnut/ChestnutPatcher
RUN chmod +x /Chestnut/ChestnutPatcher/rewrite.sh

CMD ["/bin/bash"]

