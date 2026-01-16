# Namespace - 隔离的魔法

> 让进程活在自己的"小世界"里，看不到外面的世界

## 什么是 Namespace？

想象你住在一个大型合租公寓里。虽然大家住在同一栋楼，但每个人都有自己的房间，有自己的门牌号，有自己的钥匙。你在房间里，看不到隔壁在干什么，也不知道楼上住了谁。

**Namespace 就是给进程的"房间"**。

在 Linux 中，Namespace 是一种内核特性，它可以让一组进程看到一组独立的系统资源。不同 Namespace 中的进程，互相看不到对方。

---

## Namespace 的类型

Linux 提供了 8 种 Namespace，每种隔离不同的资源：

| Namespace | 系统调用参数 | 隔离内容 | 生活比喻 |
|-----------|-------------|---------|---------|
| **PID** | CLONE_NEWPID | 进程 ID | 每个房间有独立的门牌号系统 |
| **NET** | CLONE_NEWNET | 网络设备、IP、端口 | 每个房间有独立的网线和 IP |
| **MNT** | CLONE_NEWNS | 文件系统挂载点 | 每个房间有独立的储物柜 |
| **UTS** | CLONE_NEWUTS | 主机名和域名 | 每个房间有独立的名字 |
| **IPC** | CLONE_NEWIPC | 进程间通信 | 每个房间有独立的对讲机频道 |
| **USER** | CLONE_NEWUSER | 用户和用户组 | 每个房间有独立的住户名单 |
| **CGROUP** | CLONE_NEWCGROUP | Cgroup 根目录 | 每个房间有独立的配额表 |
| **TIME** | CLONE_NEWTIME | 系统时间 | 每个房间有独立的时钟 |

Docker 容器主要使用前 6 种 Namespace。

---

## 深入理解：PID Namespace

PID Namespace 是最容易理解的，我们用它来深入理解 Namespace 的工作原理。

### 没有 PID Namespace 的世界

在没有 PID Namespace 的情况下，所有进程共享同一个 PID 空间：

```
宿主机 PID 空间
├── PID 1: systemd
├── PID 100: sshd
├── PID 200: nginx (容器A)
├── PID 201: nginx worker (容器A)
├── PID 300: mysql (容器B)
└── PID 301: mysql worker (容器B)
```

容器 A 可以看到容器 B 的进程，甚至可以 kill 掉它！这显然不安全。

### 有 PID Namespace 的世界

有了 PID Namespace，每个容器有自己的 PID 空间：

```
宿主机 PID 空间                    容器 A 的 PID 空间
├── PID 1: systemd                ├── PID 1: nginx
├── PID 100: sshd                 └── PID 2: nginx worker
├── PID 200: nginx ─────────────────→ (映射)
├── PID 201: nginx worker ──────────→ (映射)
├── PID 300: mysql                容器 B 的 PID 空间
└── PID 301: mysql worker         ├── PID 1: mysql
                                  └── PID 2: mysql worker
```

在容器 A 里，nginx 的 PID 是 1（容器里的"init 进程"）。容器 A 看不到容器 B 的进程，也看不到宿主机的其他进程。

---

## 动手实验：体验 Namespace

### 实验 1：查看当前进程的 Namespace

每个进程都有自己的 Namespace 信息，存储在 `/proc/<pid>/ns/` 目录下。

```bash
# 查看当前 shell 的 Namespace
ls -la /proc/$$/ns/
```

**实验输出**：
```
total 0
lrwxrwxrwx 1 root root 0 Jan 15 10:00 cgroup -> 'cgroup:[4026531835]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 ipc -> 'ipc:[4026531839]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 mnt -> 'mnt:[4026531840]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 net -> 'net:[4026531992]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 pid -> 'pid:[4026531836]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 uts -> 'uts:[4026531838]'
```

方括号里的数字是 Namespace 的 ID。相同 ID 表示在同一个 Namespace 中。

### 实验 2：创建新的 Network Namespace

`unshare` 命令可以创建新的 Namespace 并在其中运行程序。

```bash
# 创建新的 Network Namespace，并在其中运行 sleep 命令
unshare -fn sleep 60 &
```

**参数说明**：
- `-f`：fork 一个子进程
- `-n`：创建新的 Network Namespace

### 实验 3：查看新创建的 Namespace

```bash
# 查看 sleep 进程
ps -ef | grep sleep
```

**实验输出**：
```
root       32882    4935  0 10:00 pts/0    00:00:00 unshare -fn sleep 60
root       32883   32882  0 10:00 pts/0    00:00:00 sleep 60
```

```bash
# 查看网络 Namespace 列表
lsns -t net
```

**实验输出**：
```
        NS TYPE NPROCS   PID USER   COMMAND
4026531992 net     150     1 root   /sbin/init
4026532508 net       2 32882 root   unshare -fn sleep 60
```

看到了吗？出现了一个新的 Network Namespace（ID: 4026532508），里面有 2 个进程。

### 实验 4：进入新的 Namespace 查看网络配置

```bash
# 使用 nsenter 进入指定进程的 Namespace
nsenter -t 32883 -n ip a
```

**参数说明**：
- `-t 32883`：目标进程的 PID
- `-n`：进入 Network Namespace

**实验输出**：
```
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

新的 Network Namespace 里只有一个 lo 接口，而且是 DOWN 状态。没有 eth0，没有 IP 地址，完全与宿主机隔离！

### 实验 5：对比宿主机的网络配置

```bash
# 在宿主机上查看网络配置
ip a
```

**实验输出**：
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UP
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 00:16:3e:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

宿主机有 lo、eth0、docker0 等多个网络接口，而新的 Namespace 里只有一个空的 lo。

---

## 动手实验：Docker 容器的 Namespace

### 实验 6：查看 Docker 容器的 Namespace

```bash
# 启动一个容器
docker run -d --name test-ns nginx

# 获取容器的 PID
docker inspect test-ns | grep -i '"Pid"'
```

**实验输出**：
```
"Pid": 45678,
```

```bash
# 查看容器进程的 Namespace
ls -la /proc/45678/ns/
```

**实验输出**：
```
lrwxrwxrwx 1 root root 0 Jan 15 10:30 cgroup -> 'cgroup:[4026532512]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 ipc -> 'ipc:[4026532510]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 mnt -> 'mnt:[4026532508]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 net -> 'net:[4026532513]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 pid -> 'pid:[4026532511]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Jan 15 10:30 uts -> 'uts:[4026532509]'
```

注意：容器的 Namespace ID 与宿主机不同（除了 user），说明容器运行在独立的 Namespace 中。

### 实验 7：进入容器的 Namespace

```bash
# 进入容器的 Network Namespace 查看网络
nsenter -t 45678 -n ip a
```

**实验输出**：
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UP
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
15: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
```

容器有自己的 eth0 和 IP 地址（172.17.0.2），与宿主机完全隔离。

```bash
# 进入容器的 PID Namespace 查看进程
nsenter -t 45678 -p -r ps aux
```

**实验输出**：
```
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  10632  5432 ?        Ss   10:30   0:00 nginx: master
nginx       29  0.0  0.0  11036  2520 ?        S    10:30   0:00 nginx: worker
```

在容器的 PID Namespace 里，nginx 的 PID 是 1，它是容器里的"init 进程"。

### 实验 8：清理实验环境

```bash
# 停止并删除容器
docker stop test-ns && docker rm test-ns

# 结束 sleep 进程
pkill -f "unshare -fn sleep"
```

---

## Namespace 的工作原理

### 系统调用

Linux 提供了三个系统调用来操作 Namespace：

| 系统调用 | 作用 | 类比 |
|---------|------|------|
| `clone()` | 创建新进程时创建新 Namespace | 生孩子时给他一个新房间 |
| `unshare()` | 让当前进程加入新 Namespace | 搬到新房间 |
| `setns()` | 让当前进程加入已有 Namespace | 搬到别人的房间 |

### Docker 如何使用 Namespace

当你运行 `docker run` 时，Docker 会：

1. 调用 `clone()` 创建新进程
2. 为新进程创建独立的 Namespace（PID、NET、MNT、UTS、IPC）
3. 在新 Namespace 中执行容器的启动命令

```
docker run nginx
    │
    ├── clone(CLONE_NEWPID | CLONE_NEWNET | CLONE_NEWNS | ...)
    │       │
    │       └── 新进程（在新的 Namespace 中）
    │               │
    │               └── exec("nginx")
    │
    └── 父进程（Docker daemon）
```

---

## 核心要点总结

1. **Namespace 是什么**：Linux 内核特性，让进程拥有独立的系统资源视图
2. **8 种 Namespace**：PID、NET、MNT、UTS、IPC、USER、CGROUP、TIME
3. **核心作用**：隔离，让容器里的进程看不到宿主机和其他容器的资源
4. **关键命令**：
   - `unshare`：创建新 Namespace
   - `nsenter`：进入已有 Namespace
   - `lsns`：列出 Namespace

记住这个比喻：**Namespace 就是给进程的"房间"，让它活在自己的小世界里**。

---

## 思考题

1. 为什么容器里的 PID 1 进程这么重要？（提示：想想 Linux 的 init 进程）
2. 如果两个容器需要共享网络，应该怎么做？（提示：`--network container:xxx`）
3. 为什么 Docker 默认不隔离 USER Namespace？（提示：想想权限问题）

---

## 下一步

Namespace 实现了隔离，但隔离还不够。如果一个容器把 CPU 和内存全部占满，其他容器怎么办？

下一篇我们学习 Cgroups，它负责限制容器能使用多少资源。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[容器技术概览](01-container-overview.md)  
**下一篇**：[Cgroups - 资源的管家](03-cgroups.md)
