docker build -t redis-sysfilter-normal --file Dockerfile .
docker build -t redis-sysfilter-seccomp --file seccomp.Dockerfile .
