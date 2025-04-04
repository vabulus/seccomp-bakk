## Redis – chestnut

### Preparation

For the seccomp container we follow these steps, to create a policy for the `httpd` binary and apply it:

1. Enter the seccomp container:
   `docker exec -it redis-chestnut-seccomp-container bash`

2. Run following commands inside the container. After executing `rewrite.sh` the binary will get executed:

```
mkdir -p /Chestnut/Binalyzer/cached_results/
sed -i 's/from cfg import cached_results_folder/cached_results_folder = "cached_results"/' /Chestnut/Binalyzer/syscalls.py
cd /Chestnut/Binalyzer
python3 /Chestnut/Binalyzer/syscalls.py /usr/bin/redis-server
python3 /Chestnut/Binalyzer/policy.py /usr/bin/redis-server
cp /Chestnut/Binalyzer/cached_results/policy__usr_bin_redis-server.json /Chestnut/ChestnutPatcher/
cd /Chestnut/ChestnutPatcher && make
/Chestnut/ChestnutPatcher/rewrite.sh /usr/bin/redis-server
```

For the container without seccomp, we just have to start it with following command:
`docker exec -it vsftpd-chestnut-normal-container /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf`

### Conduct the exploits

First, we verify the IDs of the container, to ensure we target the right containers:

```
❯ docker ps
503cd4aa6e93   redis-chestnut-normal     "/bin/bash"   20 hours ago    Up 9 minutes   0.0.0.0:6381->6379/tcp, [::]:6381->6379/tcp   redis-chestnut-normal-container
516bf0d387cf   redis-chestnut-seccomp    "/bin/bash"   20 hours ago    Up 9 minutes   0.0.0.0:6382->6379/tcp, [::]:6382->6379/tcp   redis-chestnut-seccomp-container
```

_Seccomp_:

```bash
(venv) root@516bf0d387cf:~# ./attack.sh whoami
"root\n"
(venv) root@516bf0d387cf:~# ./attack.sh id
"uid=0(root) gid=0(root) groups=0(root)\n"
(venv) root@516bf0d387cf:~# ./attack.sh ls
"Makefile\ncJSON.c\ncJSON.h\ncJSON.o\ninject-lib.py\nlibchestnut.c\nlibchestnut.o\nlibchestnut.so\npolicy__usr_bin_redis-server.json\nrequirements.txt\nrewrite.sh\nsample-target\nsample-target.c\n"
(venv) root@516bf0d387cf:~# ./attack.sh pwd
"/Chestnut/ChestnutPatcher\n"
```

_Normal_:

```bash
(venv) root@503cd4aa6e93:~# ./attack.sh whoami
"root\n"
(venv) root@503cd4aa6e93:~# ./attack.sh id
"uid=0(root) gid=0(root) groups=0(root)\n"
(venv) root@503cd4aa6e93:~# ./attack.sh ls
"cfg.py\ncreate-seccomp-wrapper.py\ncsv\nfilter.py\nfull_ldd.py\nlibsandboxing.so\npolicy.py\nrequirements.txt\nsymbols.py\nsyscalls.py\ntests\nvenv\nwhitelists\n"
(venv) root@503cd4aa6e93:~# ./attack.sh pwd
"/Chestnut/Binalyzer\n"
```

### Analysis

Both containers are still vulnerable!

The used seccomp policy `policy__usr_bin_redis-server.json`:

```
{"version": 1, "syscalls": [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58, 59, 60, 61, 62, 63, 64, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 201, 202, 203, 204, 213, 216, 217, 218, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 240, 241, 242, 243, 244, 245, 247, 253, 254, 255, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 275, 276, 277, 278, 280, 281, 283, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 316, 318, 319, 322, 325, 326, 327, 328, 329, 330, 331, 332]}
```

No strace output, because the tested commands succeeded and nothing was blocked by seccomp.
