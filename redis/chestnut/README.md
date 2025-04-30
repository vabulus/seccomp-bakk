## Redis – chestnut

### Preparation

_For the container with seccomp, we execute the file `/tmp/script.sh` which is extracting the system calls from the binary `redis-server`, creating a seccomp-profile based on these detected system calls and subsequently applying the profile on the binary. Afterwards, the binary is automatically run._

```
docker exec -it redis-chestnut-seccomp-container bash -c "source /Chestnut/Binalyzer/venv/bin/activate && /tmp/script.sh"
```

For the container without seccomp, we just have to start it with following command:

```
docker exec -it redis-chestnut-normal-container redis-server
```

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
^C # no response
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

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

When starting the container with the command `strace -f /Chestnut/ChestnutPatcher/rewrite.sh /usr/bin/redis-server` we are able to see that the system call `pipe2` remains `<unfinished>` with the pid `199`.

```
[pid   199] getpid()                    = 199
[pid   199] openat(AT_FDCWD, 0x7fffffffd2b0, O_RDONLY) = 9
[pid   199] read(9, 0x7fffffffd3b0, 4096) = 315
[pid   199] close(9)                    = 0
[pid   199] read(3, 0x7fffffffe477, 1)  = -1 EAGAIN (Resource temporarily unavailable)
[pid   199] epoll_wait(5, 0x7ffff6f22200, 10128, 100) = 1
[pid   199] read(8, 0x7ffff6f66f05, 16384) = 218
[pid   199] openat(AT_FDCWD, 0x7ffff6e61af0, O_RDONLY|O_CLOEXEC) = 9
[pid   199] read(9, 0x7fffffffd808, 832) = 832
[pid   199] fstat(9, 0x7fffffffd6b0)    = 0
[pid   199] close(9)                    = 0
[pid   199] pipe2( <unfinished ...>)    = ?
[pid   195] <... wait4 resumed>0x7fffffffe070, 0, NULL) = ? ERESTARTSYS (To be restarted if SA_RESTART is set)
[pid   200] <... futex resumed>)        = ? ERESTARTSYS (To be restarted if SA_RESTART is set)
[pid   195] --- SIGWINCH {si_signo=SIGWINCH, si_code=SI_KERNEL} ---
[pid   200] --- SIGWINCH {si_signo=SIGWINCH, si_code=SI_KERNEL} ---
[pid   195] wait4(-1,  <unfinished ...>
[pid   200] futex(0x555555650408, FUTEX_WAIT_PRIVATE, 0, NULL

```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number `293` was most probably the reason for the `<unfinished>` state of the system call.

```
time->Wed Apr 30 23:01:34 2025
type=SECCOMP msg=audit(1746046894.641:3239): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=140049 comm="redis-server_pa" exe="/usr/bin/redis-server_patched" sig=31 arch=c000003e syscall=293 compat=0 ip=0x7ffff75f6b7b code=0x0
```

We verify that the system call number `293` maps to ``with the`ausyscall` tool:

```
❯ ausyscall --dump | grep 293
293	pipe2
```

The last thing we check is, if the system call number `293` was in the applied seccomp profile. The file `/Chestnut/ChestnutPatcher/policy__usr_bin_redis-server.json` shows no presence:

```json
{
  "version": 1,
  "syscalls": [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 24,
    28, 32, 33, 36, 38, 39, 41, 42, 43, 44, 46, 47, 48, 49, 50, 51, 52, 54, 55,
    56, 59, 60, 62, 63, 72, 73, 74, 75, 76, 77, 79, 80, 82, 83, 84, 85, 86, 87,
    88, 89, 90, 91, 96, 98, 99, 102, 112, 125, 131, 137, 142, 144, 147, 157,
    158, 164, 186, 201, 202, 203, 213, 217, 228, 230, 231, 232, 233, 234, 257,
    262, 268, 273, 277, 280, 302, 309, 22
  ]
}
```

## Appendix

The following shows the time needed to extract the system calls from 3 runs:

```
docker exec -it redis-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /usr/bin/redis-server"
...
real	1m21.029s
user	1m18.301s
sys	0m1.798s

docker exec -it redis-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /usr/bin/redis-server"
...
real	1m19.806s
user	1m17.710s
sys	0m1.688s

docker exec -it redis-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /usr/bin/redis-server"
...
real	1m19.500s
user	1m17.354s
sys	0m1.734s
```

Following system calls are not detected by chestnut, but needed for the application to start successfully, therefore we added these two to the seccomp-profile `/tmp/app.json`:

- `22` (pipe)

```
sed -i '/"syscalls"/ s/\]/, 22]/' /Chestnut/ChestnutPatcher/policy__usr_bin_redis-server.json
```
