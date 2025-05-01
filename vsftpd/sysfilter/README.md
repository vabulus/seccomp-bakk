## vsftpd – sysfilter

### Preparation

#### System Calls Extraction

_Extract the syscalls from the binary `vsftpd` into `/tmp/app.json`_

`docker exec -it vsftpd-sysfilter-seccomp-container bash -c "/sysfilter/extraction/app/sysfilter_extract /app/vsftpd-2.3.4-infected/vsftpd -o /tmp/app.json"`

#### Seccomp Profile enforcement

_Enforce the allowed syscalls for the binary `vsftpd`_

`docker exec -it vsftpd-sysfilter-seccomp-container bash -c "/sysfilter/enforcement/sysfilter_enforce /app/vsftpd-2.3.4-infected/vsftpd /tmp/app.json"`

#### Starting containers

_Start the two container, one with the applied seccomp profile and one without:_

`docker exec -it vsftpd-sysfilter-normal-container /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf`
`docker exec -it vsftpd-sysfilter-seccomp-container /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf`

### Conduct the exploits

First, we verify the IP addresses and IDs of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND       CREATED         STATUS         PORTS                                                                                  NAMES
213fdb0be837   vsftpd-sysfilter-normal    "/bin/bash"   6 minutes ago   Up 6 minutes   0.0.0.0:6200->6200/tcp, [::]:6200->6200/tcp, 0.0.0.0:2100->21/tcp, [::]:2100->21/tcp   vsftpd-sysfilter-normal-container
d62f08338df0   vsftpd-sysfilter-seccomp   "/bin/bash"   6 minutes ago   Up 6 minutes   0.0.0.0:2101->21/tcp, [::]:2101->21/tcp, 0.0.0.0:6201->6200/tcp, [::]:6201->6200/tcp   vsftpd-sysfilter-seccomp-container
```

Note: The attacks are executed from the host machine.

_Seccomp_

The attack on the container with the applied seccomp profile on the binary fails.

```
❯ ./attackSubject.sh 192.168.192.3 "whoami"
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.192.3 "id"
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.192.3 "ls"
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.192.3 "pwd"
read(net): Connection reset by peer
[-] no response!
```

_Normal_

The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
❯ ./attackSubject.sh 192.168.192.2 "whoami"
[+] worked: root
❯ ./attackSubject.sh 192.168.192.2 "id"
[+] worked: uid=0(root) gid=0(root) groups=0(root)
❯ ./attackSubject.sh 192.168.192.2 "ls"
[+] worked: AUDIT
BENCHMARKS
[...]
❯ ./attackSubject.sh 192.168.192.2 "pwd"
[+] worked: /app/vsftpd-2.3.4-infected
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf` we are able to see that just before the process with the pid `76` was killed with the signal `SIGSYS`, the system call `arch_prctl` was executed.

```
[pid 76] execve("/bin/sh", ["sh"], 0x58d9366c9ef0 /_ 5 vars _/) = 0
[pid 76] brk(NULL) = 0x5b71c6596000
[pid 76] access("/etc/ld.so.nohwcap", F_OK) = -1 ENOENT (No such file or directory)
[pid 76] access("/etc/ld.so.preload", R_OK) = -1 ENOENT (No such file or directory)
[pid 76] openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 7
[pid 76] fstat(7, {st_mode=S_IFREG|0644, st_size=19446, ...}) = 0
[pid 76] mmap(NULL, 19446, PROT_READ, MAP_PRIVATE, 7, 0) = 0x77a341b6b000
[pid 76] close(7) = 0
[pid 76] access("/etc/ld.so.nohwcap", F_OK) = -1 ENOENT (No such file or directory)
[pid 76] openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 7
[pid 76] read(7, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\240\35\2\0\0\0\0\0"..., 832) = 832
[pid 76] fstat(7, {st_mode=S_IFREG|0755, st_size=2030928, ...}) = 0
[pid 76] mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x77a341b69000
[pid 76] mmap(NULL, 4131552, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 7, 0) = 0x77a34155c000
[pid 76] mprotect(0x77a341743000, 2097152, PROT_NONE) = 0
[pid 76] mmap(0x77a341943000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 7, 0x1e7000) = 0x77a341943000
[pid 76] mmap(0x77a341949000, 15072, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x77a341949000
[pid 76] close(7) = 0
[pid 76] arch_prctl(ARCH_SET_FS, 0x77a341b6a540) = 158
[pid 76] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 158 was the reason for the `SIGSYS` signal.

```
❯ sudo ausearch -m seccomp --start today
time->Thu Apr  3 12:16:23 2025
type=SECCOMP msg=audit(1743675383.383:24244): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=75231 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7834219e8024 code=0x0
----
time->Thu Apr  3 12:16:55 2025
type=SECCOMP msg=audit(1743675415.104:24259): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=75730 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7a00f42b1024 code=0x0
----
time->Thu Apr  3 12:17:19 2025
type=SECCOMP msg=audit(1743675439.734:24269): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=75897 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7dc54480f024 code=0x0
----
time->Thu Apr  3 12:17:25 2025
type=SECCOMP msg=audit(1743675445.117:24279): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=75950 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7ac8a5e1d024 code=0x0
```

We verify that the system call number `158` maps to `arch_prctl` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 158
158 arch_prctl
```

The last thing we check is, if the system call number `158` was in the applied seccomp profile. The file `/tmp/app.json` shows no presence:

```
[0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,19,20,21,23,24,25,28,32,33,35,37,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,59,60,61,62,63,72,77,78,79,80,82,83,84,87,89,90,91,93,95,96,99,102,105,106,107,108,111,112,113,114,115,116,126,132,157,161,186,201,202,228,229,231,234,257,262,302,307]
```

## Appendix

### Extraction time

The following shows the time needed to extract the system calls from 3 runs:

```
❯ docker exec -it vsftpd-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/vsftpd-2.3.4-infected/vsftpd -o /tmp/app.json"
real	0m5.557s
user	0m5.326s
sys	0m0.147s

❯ docker exec -it vsftpd-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/vsftpd-2.3.4-infected/vsftpd -o /tmp/app.json"
real	0m5.250s
user	0m5.105s
sys	0m0.121s

❯ docker exec -it vsftpd-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/vsftpd-2.3.4-infected/vsftpd -o /tmp/app.json"
real	0m5.481s
user	0m5.332s
sys	0m0.122s
```

`(5,557+5,250+5,481)/3=5,429`
