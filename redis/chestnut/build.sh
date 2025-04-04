docker build -t redis-chestnut-normal --file Dockerfile .
docker build -t redis-chestnut-seccomp --file seccomp.Dockerfile .
