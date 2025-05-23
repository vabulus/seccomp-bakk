## Redis – sysfilter

### Preparation

#### System Calls Extraction

_Extract the syscalls from the binary `redis-server` into `/tmp/app.json`_

`docker exec -it redis-sysfilter-seccomp-container bash -c "/sysfilter/extraction/app/sysfilter_extract /usr/bin/redis-server -o /tmp/app.json"`

#### Seccomp Profile enforcement

_Enforce the allowed syscalls for the binary `redis-server`_

`docker exec -it redis-sysfilter-seccomp-container bash -c "/sysfilter/enforcement/sysfilter_enforce /usr/bin/redis-server /tmp/app.json"`

#### Starting containers

_Start the two container, one with the applied seccomp profile and one without:_

```bash
docker exec -it redis-sysfilter-seccomp-container redis-server
docker exec -it redis-sysfilter-normal-container redis-server
```

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                     COMMAND       CREATED              STATUS              PORTS                                         NAMES
765c07e65c4a   redis-sysfilter-seccomp   "/bin/bash"   About a minute ago   Up About a minute   0.0.0.0:6380->6379/tcp, [::]:6380->6379/tcp   redis-sysfilter-seccomp-container
17f7d1887ae8   redis-sysfilter-normal    "/bin/bash"   About a minute ago   Up About a minute   0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp   redis-sysfilter-normal-container
```

Note: the attacks are executed inside each container. The script `attack.sh` is in the current directory.
_seccomp_
The attack on the container with the applied seccomp profile on the binary fails.

```
root@765c07e65c4a:/# ./attack.sh whoami
""
root@765c07e65c4a:/# ./attack.sh id
""
root@765c07e65c4a:/# ./attack.sh ls
""
root@765c07e65c4a:/# ./attack.sh pwd
""
```

_Normal_
The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```bash
root@17f7d1887ae8:/# ./attack.sh whoami
"root\n"
root@17f7d1887ae8:/# ./attack.sh id
"uid=0(root) gid=0(root) groups=0(root)\n"
root@17f7d1887ae8:/# ./attack.sh ls
"attack.sh\nbin\nboot\ndev\netc\nhome\nlib\nlib32\nlib64\nlibx32\nmedia\nmnt\nopt\nproc\nroot\nrun\nsbin\nsrv\nsys\nsysfilter\ntmp\nusr\nvar\n"
root@17f7d1887ae8:/# ./attack.sh pwd
"/\n"
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f redis-server` we are able to see that just before the process with the pid `172` was killed with the signal `SIGSYS`, the system calls `read` and `arch_prctl` were executed.

```
[pid 172] execve("/bin/sh", ["sh", "-c", "ls"], 0x75c17042f000 /_ 11 vars _/ <unfinished ...>
[pid 172] <... execve resumed>) = 0
[pid 172] brk(NULL <unfinished ...>
[pid 172] <... brk resumed>) = 0x5c564f124000
[pid 172] arch_prctl(0x3001 /\* ARCH*??? \*/, 0x7ffe17c42740 <unfinished ...>
[pid 172] <... arch_prctl resumed>) = 158
[pid 172] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 158 was the reason for the `SIGSYS` signal.

```
❯ sudo ausearch -m seccomp --start today
time->Wed Apr 2 13:32:52 2025
type=SECCOMP msg=audit(1743593572.872:338): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=215422 comm="sh" exe="/usr/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x783aeffc3bf5 code=0x0
---
time->Wed Apr 2 13:33:24 2025
type=SECCOMP msg=audit(1743593604.555:358): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=215597 comm="sh" exe="/usr/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7d0baaf22bf5 code=0x0
---
time->Wed Apr 2 13:34:51 2025
type=SECCOMP msg=audit(1743593691.233:403): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=216207 comm="sh" exe="/usr/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x764924e16bf5 code=0x0
---
time->Wed Apr 2 13:35:31 2025
type=SECCOMP msg=audit(1743593731.378:418): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=216786 comm="sh" exe="/usr/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x79f5bb818bf5 code=0x0
```

We verify that the system call number `158` maps to `arch_prctl` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 158
158 arch_prctl
```

The last thing we check is, if the system call number `158` was in the applied seccomp profile. The file `/tmp/app.json` shows no presence:

```
[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,19,20,21,22,24,25,28,32,33,38,39,41,42,43,44,45,46,47,48,49,50,51,52,54,55,56,59,60,61,62,63,72,73,74,75,76,77,79,80,81,82,83,84,85,87,89,90,96,98,99,102,104,105,106,109,112,113,114,116,117,119,131,142,143,144,145,146,147,157,186,201,202,203,204,213,217,218,228,230,231,232,233,234,257,262,273,277,292,293,302,307,309]
```

## Appendix

### Extraction time

The following shows the time needed to extract the system calls from 3 runs:

```
❯ docker exec -it redis-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /usr/bin/redis-server -o /tmp/app.json"
real	0m17.434s
user	0m16.664s
sys	0m0.616s

❯ docker exec -it redis-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /usr/bin/redis-server -o /tmp/app.json"
real	0m17.391s
user	0m16.732s
sys	0m0.604s

❯ docker exec -it redis-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /usr/bin/redis-server -o /tmp/app.json"
real	0m16.925s
user	0m16.306s
sys	0m0.565s
```

`(17,434 + 17,391 + 16,925) / 3 = 17,25 Sekunden`

### Number of syscalls

```
python -c "print(len([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,19,20,21,22,24,25,28,32,33,38,39,41,42,43,44,45,46,47,48,49,50,51,52,54,55,56,59,60,61,62,63,72,73,74,75,76,77,79,80,81,82,83,84,85,87,89,90,96,98,99,102,104,105,106,109,112,113,114,116,117,119,131,142,143,144,145,146,147,157,186,201,202,203,204,213,217,218,228,230,231,232,233,234,257,262,273,277,292,293,302,307,309]))"
109
```
