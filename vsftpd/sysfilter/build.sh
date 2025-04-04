docker build -t vsftpd-sysfilter-normal --file Dockerfile .
docker build -t vsftpd-sysfilter-seccomp --file seccomp.Dockerfile .
