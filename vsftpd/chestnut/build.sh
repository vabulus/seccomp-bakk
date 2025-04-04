docker build -t vsftpd-chestnut-normal --file Dockerfile .
docker build -t vsftpd-chestnut-seccomp --file seccomp.Dockerfile .
