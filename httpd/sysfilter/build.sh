docker build -t http-sysfilter-normal --file Dockerfile .
docker build -t http-sysfilter-seccomp --file seccomp.Dockerfile .
