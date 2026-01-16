# 容器网络 - 连接的艺术

> 让隔离的容器能够互相通信，连接内外世界

## 一个问题引发的思考

我们已经知道，容器有自己独立的 Network Namespace，网络是隔离的。

但问题来了：
- 容器 A 如何访问容器 B？
- 容器如何访问外部网络（比如访问百度）？
- 外部如何访问容器里的服务？

如果网络完全隔离，容器就成了"孤岛"，毫无用处。

**Docker 是如何解决这个问题的？**

---

## 容器网络的核心组件

Docker 网络就像一个小区的网络系统：

| 组件 | 作用 | 生活比喻 |
|------|------|---------|
| **veth pair** | 虚拟网络设备对 | 两个房间之间的对讲机 |
| **docker0 网桥** | 连接所有容器 | 小区的交换机 |
| **iptables** | 网络地址转换 | 小区的门卫（转发快递） |

```
┌─────────────────────────────────────────────────────────────┐
│                        宿主机                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │   容器 A     │    │   容器 B     │    │    外部网络      │  │
│  │  ┌───────┐  │    │  ┌───────┐  │    │                 │  │
│  │  │ eth0  │  │    │  │ eth0  │  │    │                 │  │
│  │  └───┬───┘  │    │  └───┬───┘  │    │                 │  │
│  └──────┼──────┘    └──────┼──────┘    │                 │  │
│         │                  │           │                 │  │
│      veth-A             veth-B         │                 │  │
│         │                  │           │                 │  │
│         └────────┬─────────┘           │                 │  │
│                  │                     │                 │  │
│           ┌──────┴──────┐              │                 │  │
│           │   docker0   │──────────────┤     eth0        │  │
│           │  (网桥)     │   iptables   │   (物理网卡)     │  │
│           └─────────────┘              │                 │  │
│                                        └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心概念详解

### 1. Veth Pair：虚拟网线

Veth Pair 是一对虚拟网络设备，就像一根网线的两端：
- 从一端发送的数据，会从另一端出来
- 一端在容器里（eth0），一端在宿主机上（连接到网桥）

```
容器内部                    宿主机
┌──────────┐              ┌──────────┐
│   eth0   │ ←──veth──→  │  veth-A  │
└──────────┘              └──────────┘
    ↑                          ↑
容器看到的网卡            连接到 docker0
```

### 2. Docker0 网桥：小区交换机

Docker0 是一个虚拟网桥，所有容器的 veth 都连接到它：
- 容器之间通过 docker0 通信
- 容器访问外部网络也要经过 docker0

```
        docker0 (172.17.0.1)
              │
    ┌─────────┼─────────┐
    │         │         │
 veth-A    veth-B    veth-C
    │         │         │
容器 A     容器 B     容器 C
172.17.0.2 172.17.0.3 172.17.0.4
```

### 3. iptables：门卫和翻译官

iptables 负责网络地址转换（NAT）：
- 容器访问外部：把容器 IP 转换成宿主机 IP（SNAT）
- 外部访问容器：把宿主机端口映射到容器端口（DNAT）

---

## 动手实验：从零构建容器网络

我们来手动构建一个容器网络，深入理解 Docker 网络的工作原理。

### 实验目标

1. 启动一个没有网络的容器
2. 手动创建 veth pair
3. 把容器连接到 docker0 网桥
4. 配置 IP 地址和路由
5. 验证网络连通性

### 实验 1：准备工作

```bash
# 创建 netns 目录（如果不存在）
sudo mkdir -p /var/run/netns

# 清理可能存在的旧链接
sudo find -L /var/run/netns -type l -delete
```

### 实验 2：启动一个没有网络的容器

```bash
# 启动 nginx 容器，但不配置网络
docker run --network=none -d --name net-test nginx

# 查看容器
docker ps | grep net-test
```

**实验输出**：
```
abc123  nginx  "/docker-entrypoint.…"  Up 10 seconds  net-test
```

### 实验 3：获取容器的 PID

```bash
# 获取容器的 PID
PID=$(docker inspect net-test -f '{{.State.Pid}}')
echo "容器 PID: $PID"
```

**实验输出**：
```
容器 PID: 12345
```

### 实验 4：查看容器当前的网络配置

```bash
# 进入容器的网络命名空间，查看网络配置
nsenter -t $PID -n ip a
```

**实验输出**：
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
```

只有 lo 接口，没有 eth0，无法访问外部网络。

### 实验 5：创建网络命名空间链接

```bash
# 创建符号链接，让 ip netns 命令能识别容器的网络命名空间
ln -s /proc/$PID/ns/net /var/run/netns/$PID

# 验证
ip netns list
```

**实验输出**：
```
12345
```

### 实验 6：查看宿主机的 docker0 网桥

```bash
# 查看网桥信息
brctl show
```

**实验输出**：
```
bridge name     bridge id               STP enabled     interfaces
docker0         8000.0242ac110001       no
```

```bash
# 查看 docker0 的 IP 地址
ip addr show docker0
```

**实验输出**：
```
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether 02:42:ac:11:00:01 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

docker0 的 IP 是 172.17.0.1，这是容器网络的网关。

### 实验 7：创建 veth pair

```bash
# 创建一对 veth 设备
ip link add A type veth peer name B

# 查看创建的设备
ip link show A
ip link show B
```

**实验输出**：
```
5: B@A: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN
6: A@B: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN
```

A 和 B 是一对 veth，数据从 A 进，从 B 出，反之亦然。

### 实验 8：配置宿主机端（A）

```bash
# 把 A 连接到 docker0 网桥
brctl addif docker0 A

# 启动 A
ip link set A up

# 验证
brctl show docker0
```

**实验输出**：
```
bridge name     bridge id               STP enabled     interfaces
docker0         8000.0242ac110001       no              A
```

A 已经连接到 docker0 了。

### 实验 9：配置容器端（B）

```bash
# 设置容器的 IP 地址
CONTAINER_IP=172.17.0.10
NETMASK=16
GATEWAY=172.17.0.1

# 把 B 移动到容器的网络命名空间
ip link set B netns $PID

# 在容器中重命名为 eth0
ip netns exec $PID ip link set dev B name eth0

# 启动 eth0
ip netns exec $PID ip link set eth0 up

# 配置 IP 地址
ip netns exec $PID ip addr add $CONTAINER_IP/$NETMASK dev eth0

# 配置默认路由
ip netns exec $PID ip route add default via $GATEWAY
```

### 实验 10：验证容器网络配置

```bash
# 查看容器的网络配置
nsenter -t $PID -n ip a
```

**实验输出**：
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
7: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    link/ether 8a:1b:2c:3d:4e:5f brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.10/16 scope global eth0
```

容器现在有 eth0 了，IP 是 172.17.0.10！

```bash
# 查看路由
nsenter -t $PID -n ip route
```

**实验输出**：
```
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.10
```

### 实验 11：测试网络连通性

```bash
# 从宿主机访问容器
curl http://172.17.0.10
```

**实验输出**：
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
</html>
```

成功了！我们手动构建的容器网络可以工作了！

### 实验 12：清理实验环境

```bash
# 删除网络命名空间链接
rm /var/run/netns/$PID

# 停止并删除容器
docker stop net-test && docker rm net-test
```

---

## Docker 网络模式

Docker 提供了多种网络模式：

| 模式 | 说明 | 使用场景 |
|------|------|---------|
| **bridge** | 默认模式，容器连接到 docker0 | 大多数场景 |
| **host** | 容器使用宿主机网络 | 需要高性能网络 |
| **none** | 没有网络 | 安全隔离场景 |
| **container** | 共享另一个容器的网络 | Pod 模式（K8s） |

### Bridge 模式（默认）

```bash
# 默认就是 bridge 模式
docker run -d nginx

# 等同于
docker run -d --network bridge nginx
```

### Host 模式

```bash
# 容器直接使用宿主机网络
docker run -d --network host nginx

# 容器里的 nginx 直接监听宿主机的 80 端口
curl localhost:80
```

### None 模式

```bash
# 没有网络，完全隔离
docker run -d --network none nginx
```

### Container 模式

```bash
# 启动第一个容器
docker run -d --name container1 nginx

# 第二个容器共享第一个容器的网络
docker run -d --network container:container1 --name container2 busybox sleep 3600

# 两个容器有相同的 IP
docker exec container1 ip a
docker exec container2 ip a
```

---

## 端口映射的原理

当你运行 `docker run -p 8080:80 nginx` 时，Docker 会：

1. 在宿主机上监听 8080 端口
2. 配置 iptables 规则，把 8080 端口的流量转发到容器的 80 端口

```bash
# 查看 iptables 规则
iptables -t nat -L -n | grep 8080
```

**实验输出**：
```
DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:8080 to:172.17.0.2:80
```

这条规则的意思是：访问宿主机 8080 端口的 TCP 流量，转发到 172.17.0.2:80（容器）。

---

## 核心要点总结

1. **容器网络三大组件**：
   - veth pair：虚拟网线，连接容器和网桥
   - docker0：虚拟网桥，连接所有容器
   - iptables：网络地址转换，连接内外网络

2. **网络配置流程**：
   - 创建 veth pair
   - 一端连接到 docker0
   - 另一端放入容器的网络命名空间
   - 配置 IP 地址和路由

3. **四种网络模式**：
   - bridge：默认，通过 docker0 通信
   - host：使用宿主机网络
   - none：没有网络
   - container：共享其他容器的网络

4. **端口映射**：通过 iptables DNAT 实现

记住这个比喻：**容器网络就像小区网络，veth 是网线，docker0 是交换机，iptables 是门卫**。

---

## 思考题

1. 为什么 Kubernetes 的 Pod 里多个容器可以用 localhost 通信？（提示：container 网络模式）
2. 如果两个容器在不同的宿主机上，如何通信？（提示：overlay 网络）
3. 为什么 host 模式的网络性能更好？（提示：少了一层网桥）

---

## 下一步

现在你已经掌握了 Docker 的核心技术：Namespace、Cgroups、OverlayFS、网络。

最后一篇，我们学习如何优化 Docker 镜像，让镜像更小、构建更快。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[OverlayFS - 分层的文件系统](04-overlayfs.md)  
**下一篇**：[Docker 镜像优化](06-image-optimization.md)
