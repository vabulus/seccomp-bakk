## Apache httpd – sysfilter

### Preparation

#### System Calls Extraction

_Extract the syscalls from the binary `httpd` into `/tmp/app.json` with following command:_

```
docker exec -it http-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /opt/apache/bin/httpd -o /tmp/app.json"
```

#### Seccomp Profile enforcement

_Enforce the allowed syscalls for the binary `httpd`_

```
docker exec -it http-sysfilter-seccomp-container bash -c "/sysfilter/enforcement/sysfilter_enforce /opt/apache/bin/httpd /tmp/app.json"
```

#### Starting containers

_Start the two container, one with the applied seccomp profile and one without:_

```
docker exec -it http-sysfilter-normal-container "/opt/apache/bin/httpd"
docker exec -it http-sysfilter-seccomp-container "/opt/apache/bin/httpd"
```

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
9065cb90a62b http-sysfilter-seccomp "bash" 8 minutes ago Up 8 minutes 0.0.0.0:8081->80/tcp, [::]:8081->80/tcp http-sysfilter-seccomp-container
4e1fa8b2fe0f http-sysfilter-normal "bash" 8 minutes ago Up 8 minutes 0.0.0.0:8082->80/tcp, [::]:8082->80/tcp http-sysfilter-normal-container
```

_Seccomp_
The attack on the container with the applied seccomp profile fails:

```
❯ python3 exploit.py -u http://localhost:8081

[-] Unable to connect to the domain http://localhost:8081

```

_Normal_
The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
❯ python3 exploit.py -u http://localhost:8082
[+] Executing payload http://localhost:8082/icons/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd
[!] http://localhost:8082 is not vulnerable to CVE-2021-41773

[+] Executing payload http://localhost:8082/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh
[!] http://localhost:8082 is vulnerable to Remote Code Execution attack (CVE-2021-41773)
[+] Response:
uid=1(daemon) gid=1(daemon) groups=1(daemon)
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f /opt/apache/bin/httpd` we are able to see that just before the process with the pid `677` was killed with the signal `SIGSYS`, the system call `arch_prctl` was executed.

```
...
[pid   677] openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
[pid   677] read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\240\35\2\0\0\0\0\0"..., 832) = 832
[pid   677] fstat(3, {st_mode=S_IFREG|0755, st_size=2030928, ...}) = 0
[pid   677] mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7ae557cea000
[pid   677] mmap(NULL, 4131552, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 3, 0) = 0x7ae5576de000
[pid   677] mprotect(0x7ae5578c5000, 2097152, PROT_NONE) = 0
[pid   677] mmap(0x7ae557ac5000, 24576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 3, 0x1e7000) = 0x7ae557ac5000
[pid   677] mmap(0x7ae557acb000, 15072, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_ANONYMOUS, -1, 0) = 0x7ae557acb000
[pid   677] close(3)                    = 0
[pid   677] arch_prctl(ARCH_SET_FS, 0x7ae557ceb540) = 158
[pid   677] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number `158` was indeed blocked by seccomp

```
❯ sudo ausearch -m seccomp --start today
time->Thu May  1 08:47:35 2025
type=SECCOMP msg=audit(1746082055.774:1337): auid=4294967295 uid=1 gid=1 ses=4294967295 pid=15656 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=158 compat=0 ip=0x7a2ca4acb024 code=0x0
```

We verify that the system call number `158` maps to `arch_prctl` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 158
158	arch_prctl
```

The last thing we check is, if the system call number `158` was in the applied seccomp profile. The file `/tmp/app.json` shows no presence:

```
[0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,19,20,21,22,23,24,25,28,29,30,31,32,33,34,35,39,40,41,42,43,44,45,46,47,48,49,50,51,52,54,56,58,59,60,61,62,63,64,65,66,67,72,73,78,79,80,82,83,86,87,90,93,96,99,100,102,104,105,106,107,108,111,112,113,114,115,116,117,119,121,128,137,143,144,145,146,147,186,201,202,203,218,228,229,231,232,233,234,257,262,273,288,291,292,302,307,92,95]
```

## Appendix

### Extraction time

The following shows the time needed to extract the system calls from 3 runs:

```
❯ docker exec -it http-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /opt/apache/bin/httpd -o /tmp/app.json"
real 0m10.561s
user 0m10.262s
sys 0m0.264s

❯ docker exec -it http-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /opt/apache/bin/httpd -o /tmp/app.json"
real 0m10.716s
user 0m10.411s
sys 0m0.270s

❯ docker exec -it http-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /opt/apache/bin/httpd -o /tmp/app.json"
real 0m10.486s
user 0m10.200s
sys 0m0.253s
```

(10,561+10,716+10,486)/3=10,587

### Missing system calls

Following system calls are not detected by sysfilter, but needed for the application to start successfully, therefore we added these two to the seccomp-profile `/tmp/app.json`:

- `92` (chown)
- `95` (umask)

```
sed -i '0,/\]/s/\]/,92,95]/' /tmp/app.json
```

### Number of syscalls

```
python -c 'print(len([0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,19,20,21,22,23,24,25,28,29,30,31,32,33,34,35,39,40,41,42,43,44,45,46,47,48,49,50,51,52,54,56,58,59,60,61,62,63,64,65,66,67,72,73,78,79,80,82,83,86,87,90,93,96,99,100,102,104,105,106,107,108,111,112,113,114,115,116,117,119,121,128,137,143,144,145,146,147,186,201,202,203,218,228,229,231,232,233,234,257,262,273,288,291,292,302,307]))'
113
```
