# Kubernetes集群安装指南

## 目录
1. [环境说明](#1-环境说明)
2. [前置准备](#2-前置准备)
3. [安装步骤](#3-安装步骤)
4. [集群初始化](#4-集群初始化)
5. [网络配置](#5-网络配置)
6. [节点加入](#6-节点加入)
7. [验证部署](#7-验证部署)
8. [故障排查](#8-故障排查)
9. [常见问题总结](#9-常见问题总结)

## 1. 环境说明

### 1.1 服务器配置

| 角色 | 外网IP | 内网IP | 主机名 |
|------|---------|---------|---------|
| Master | 182.42.82.135 | 10.0.3.231 | k8s-master |
| Worker1 | 182.42.80.121 | 10.0.1.149 | k8s-worker1 |
| Worker2 | 182.42.95.71 | 10.0.0.32 | k8s-worker2 |

### 1.2 系统要求

- 操作系统：Ubuntu 20.04 LTS
- CPU：2核或更多
- 内存：2GB或更多（Master节点建议4GB）
- 磁盘：20GB或更多
- 容器运行时：Containerd 1.6.x
- Kubernetes版本：1.28.2

### 1.3 网络要求

- 所有节点之间网络互通
- 节点间防火墙已关闭或配置了必要端口
- 支持的网络插件：Calico（本文档使用）
- Pod网段：10.244.0.0/16
- Service网段：10.96.0.0/12

## 2. 前置准备

### 2.1 主机名配置（所有节点）

```bash
# 1. 配置时间同步（所有节点都需要先配置）
# 配置国内apt源（可选，但建议配置）
# 备份原始源文件
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 替换为阿里云源
cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 更新源
apt-get update

# 安装chrony
apt-get install -y chrony

# 配置chrony使用国内NTP服务器
cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak

cat > /etc/chrony/chrony.conf << EOF
# 使用国内NTP服务器
pool ntp1.aliyun.com iburst maxsources 2
pool ntp2.aliyun.com iburst maxsources 2
pool ntp.tencent.com iburst maxsources 2
pool ntp.cloud.tencent.com iburst maxsources 2

# 本地时钟设置
local stratum 10

# 允许所有网络的NTP客户端访问
allow all

# 记录日志
logdir /var/log/chrony
log measurements statistics tracking

# 设置漂移文件位置
driftfile /var/lib/chrony/chrony.drift

# 启用RTC同步
rtcsync

# 设置租用目录
keyfile /etc/chrony/chrony.keys
leapsectz right/UTC
makestep 1.0 3
EOF

# 设置权限
chown -R root:root /etc/chrony
chmod 644 /etc/chrony/chrony.conf

mkdir -p /var/log/chrony
chown -R _chrony:_chrony /var/log/chrony

# 重新加载systemd配置
systemctl daemon-reload

# 停止其他时间同步服务（如果存在）
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd

# 启动chrony服务
systemctl enable chrony
systemctl start chrony

# 验证服务状态
systemctl status chrony
chronyc sources
chronyc tracking

# 2. 配置Master节点
# 设置主机名
hostnamectl set-hostname k8s-master
# 确保主机名写入/etc/hostname
echo "k8s-master" > /etc/hostname
# 验证设置
hostname
hostname -f

# 3. 配置Worker1节点
hostnamectl set-hostname k8s-worker1
echo "k8s-worker1" > /etc/hostname
# 验证设置
hostname
hostname -f

# 4. 配置Worker2节点
hostnamectl set-hostname k8s-worker2
echo "k8s-worker2" > /etc/hostname
# 验证设置
hostname
hostname -f

# 4. 在所有节点配置hosts文件
# 先备份原有hosts文件
cp /etc/hosts /etc/hosts.bak

# 添加集群节点信息
cat >> /etc/hosts << EOF
# Kubernetes集群内部通信
10.0.3.231 k8s-master k8s-master-internal
10.0.1.149 k8s-worker1
10.0.0.32  k8s-worker2

# 外部访问地址
182.42.82.135 k8s-master-external
182.42.80.121 k8s-worker1-external
182.42.95.71  k8s-worker2-external
EOF

# 5. 验证hosts文件配置
cat /etc/hosts

# 6. 测试节点间连通性
ping -c 3 k8s-master-internal
ping -c 3 k8s-worker1
ping -c 3 k8s-worker2

# 7. 如果系统中存在cloud-init，需要禁用其主机名管理
# 检查是否安装了cloud-init
if [ -f /etc/cloud/cloud.cfg ]; then
    # 备份原始配置
    cp /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.bak
    # 禁用cloud-init的主机名管理
    sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
    # 如果没有找到该行，则添加
    grep -q "preserve_hostname" /etc/cloud/cloud.cfg || echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
fi

# 8. 验证配置
# 检查当前主机名
hostname
# 检查完整主机名
hostname -f
# 检查DNS解析
getent hosts k8s-master-internal
getent hosts k8s-worker1
getent hosts k8s-worker2

# 注意：完成配置后建议重启系统验证主机名是否持久化
# reboot
# 重启后执行以下命令验证：
# hostname
# cat /etc/hostname
# cat /etc/hosts
```

### 2.2 系统配置（所有节点）

```bash
# 关闭swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# 加载必要的内核模块
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 设置内核参数
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 配置时间同步
# 配置国内apt源
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

apt-get update
apt-get install -y chrony

# 配置chrony使用国内NTP服务器
cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
cat > /etc/chrony/chrony.conf << EOF
# 使用国内NTP服务器
pool ntp1.aliyun.com iburst maxsources 2
pool ntp2.aliyun.com iburst maxsources 2
pool ntp.tencent.com iburst maxsources 2
pool ntp.cloud.tencent.com iburst maxsources 2

# 本地时钟设置
local stratum 10

# 允许所有网络的NTP客户端访问
allow all

# 记录日志
logdir /var/log/chrony
log measurements statistics tracking

# 设置漂移文件位置
driftfile /var/lib/chrony/chrony.drift

# 启用RTC同步
rtcsync

# 设置租用目录
keyfile /etc/chrony/chrony.keys
leapsectz right/UTC
makestep 1.0 3
EOF

systemctl enable chrony
systemctl restart chrony

# 关闭防火墙
systemctl stop ufw
systemctl disable ufw
```

### 2.3 安装容器运行时（所有节点）

```bash
# 配置国内apt源（如果还没有配置）
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF

# 安装containerd
apt-get update
apt-get install -y containerd

# 创建默认配置文件
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# 配置containerd使用阿里云镜像加速
cat > /etc/containerd/config.toml << EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.6"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
EOF

# 重启containerd
systemctl restart containerd
systemctl enable containerd

# 验证安装
ctr version
```

## 3. 安装步骤

### 3.1 安装kubeadm、kubelet和kubectl（所有节点）

```bash
# 安装依赖包
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# 添加Kubernetes仓库的GPG密钥（使用阿里云）
mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# 添加Kubernetes apt仓库（使用阿里云）
cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

# 更新apt包索引
apt-get update

# 安装kubelet、kubeadm和kubectl
apt-get install -y kubelet kubeadm kubectl

# 锁定版本
apt-mark hold kubelet kubeadm kubectl

# 启动kubelet
systemctl enable kubelet
systemctl start kubelet

# 验证安装
kubeadm version
kubectl version --client

# 配置kubectl命令补全（可选）
apt-get install -y bash-completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

## 4. 集群初始化

### 4.1 初始化Master节点

```bash
# 配置containerd使用阿里云镜像加速
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml << EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.6"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
          endpoint = ["https://registry.aliyuncs.com/google_containers"]
EOF

systemctl restart containerd

# 在Master节点创建kubeadm配置文件
cat > kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 10.0.3.231  # Master节点内网IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
imageRepository: registry.aliyuncs.com/google_containers  # 使用阿里云镜像仓库
kubernetesVersion: v1.28.2
networking:
  serviceSubnet: "10.96.0.0/12"
  podSubnet: "10.244.0.0/16"
  dnsDomain: "cluster.local"
controlPlaneEndpoint: "k8s-master-internal:6443"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

# 预先拉取所需镜像
kubeadm config images pull --config kubeadm-config.yaml

# 初始化集群
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.log

# 配置kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

### 按照提示加入work级群

## 5. 网络配置

### 5.1 安装Calico网络插件（在Master节点）

```bash
# 下载Calico配置文件（使用最新的v3.29版本）
# 使用阿里云镜像加速
curl https://mirrors.aliyun.com/kubernetes/charts/calico-v3.29.0.tgz -O
tar -zxvf calico-v3.29.0.tgz

# 修改配置文件中的镜像源为阿里云镜像
sed -i 's#docker.io/calico/#registry.cn-hangzhou.aliyuncs.com/google_containers/calico-#g' calico/templates/*.yaml

# 应用配置
kubectl apply -f calico/templates/calico.yaml

# 验证网络插件安装
kubectl get pods -n kube-system | grep calico

# 等待所有Calico相关的Pod状态变为Running
kubectl wait --namespace=kube-system --for=condition=ready pod -l k8s-app=calico-node --timeout=90s
```

注意：Calico v3.29已在以下Kubernetes版本中经过测试：
- v1.29
- v1.30
- v1.31

虽然尚未正式声明支持Kubernetes v1.32，但通常新版本的Kubernetes都会兼容。如果遇到兼容性问题，可以考虑：
1. 降级到Kubernetes v1.31版本
2. 等待Calico发布支持v1.32的新版本
3. 使用其他CNI插件（如Flannel）

## 6. 节点加入

### 6.1 加入Worker节点

```bash
# 在Master节点获取加入命令
kubeadm token create --print-join-command

# 在Worker节点执行上面命令的输出
# 格式类似：
kubeadm join 10.0.3.231:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## 7. 验证部署

### 7.1 检查节点状态（在Master节点）

```bash
# 查看节点状态
kubectl get nodes -o wide

# 查看系统Pod状态
kubectl get pods --all-namespaces

# 验证DNS服务
kubectl run test-dns --image=registry.cn-hangzhou.aliyuncs.com/google_containers/busybox:1.28 -- sleep 3600
kubectl exec -it test-dns -- nslookup kubernetes.default
```

### 7.2 部署测试应用

```bash
# 部署nginx测试服务
kubectl create deployment nginx --image=registry.cn-hangzhou.aliyuncs.com/google_containers/nginx:latest
kubectl expose deployment nginx --port=80 --type=NodePort

# 查看服务状态
kubectl get svc nginx
```

## 8. 故障排查

### 8.1 常见问题及解决方法

1. 节点NotReady
```bash
# 检查kubelet状态
systemctl status kubelet
journalctl -xeu kubelet

# 检查网络插件
kubectl get pods -n kube-system | grep calico
```

2. Pod一直处于Pending
```bash
# 检查节点资源
kubectl describe node <node-name>

# 检查Pod事件
kubectl describe pod <pod-name>
```

3. 网络故障
```bash
# 检查DNS
kubectl run test-dns --image=registry.cn-hangzhou.aliyuncs.com/google_containers/busybox:1.28 -- nslookup kubernetes.default

# 检查网络连接
kubectl run test-net --image=registry.cn-hangzhou.aliyuncs.com/google_containers/netshoot -- sleep 3600
kubectl exec -it test-net -- bash
```

4. 时间同步问题
```bash
# 如果chrony服务启动失败，可以尝试以下步骤：

# 1. 完全清理现有配置
systemctl stop chrony
apt-get remove --purge chrony
apt-get autoremove
rm -rf /etc/chrony
rm -f /etc/chrony.conf

# 2. 重新安装
apt-get update
apt-get install -y chrony

# 3. 如果服务仍然无法启动，检查：
# 检查服务单元文件
systemctl cat chrony.service

# 检查系统日志
journalctl -xe | grep chrony

# 检查是否有其他时间同步服务
ps aux | grep ntp
systemctl status systemd-timesyncd

# 4. 重新配置或重装
dpkg-reconfigure chrony
# 或者
apt-get install --reinstall chrony
```

### 8.2 日志收集

```bash
# 收集kubelet日志
journalctl -u kubelet > kubelet.log

# 收集容器运行时日志
journalctl -u containerd > containerd.log

# 收集系统日志
dmesg > dmesg.log
```

### 8.3 重要配置文件位置

- `/etc/kubernetes/`: Kubernetes配置文件目录
- `/etc/kubernetes/manifests/`: 静态Pod配置目录
- `/etc/kubernetes/pki/`: 证书目录
- `/var/lib/kubelet/`: kubelet工作目录
- `/var/log/containers/`: 容器日志目录
- `/etc/containerd/`: containerd配置目录

### 8.4 常用调试命令

```bash
# 查看组件状态
kubectl get componentstatuses

# 查看事件
kubectl get events --all-namespaces

# 查看日志
kubectl logs -n kube-system <pod-name>

# 查看配置
kubectl describe configmap -n kube-system kubeadm-config
```

## 9. 常见问题总结

本节总结了Kubernetes集群部署过程中可能遇到的常见问题及其解决方案。

### 9.1 初始化Master节点时的端口和文件冲突

**症状**：执行`kubeadm init`命令时报错，提示端口已被占用或文件已存在。
```bash
[ERROR Port-10259]: Port 10259 is in use
[ERROR Port-10257]: Port 10257 is in use
[ERROR FileAvailable--etc-kubernetes-manifests-kube-apiserver.yaml]: /etc/kubernetes/manifests/kube-apiserver.yaml already exists
```

**原因**：之前的Kubernetes组件未完全清理，或存在失败的安装。

**解决方案**：
1. 重置Kubernetes集群：`kubeadm reset -f`
2. 清理残留文件：
   ```bash
   rm -rf /etc/kubernetes/* /var/lib/kubelet/* /var/lib/etcd/*
   iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
   ```
3. 检查并终止相关进程：
   ```bash
   ps -ef | grep kube
   ps -ef | grep etcd
   ```
4. 重启服务器或重新初始化

### 9.2 Worker节点加入时的容器运行时错误

**症状**：执行`kubeadm join`命令时报错，提示container runtime未运行。
```bash
[ERROR CRI]: container runtime is not running: output: E0319 07:54:03.847318 564451 remote_runtime.go:616] "Status from runtime service failed" err="rpc error: code = DeadlineExceeded desc = context deadline exceeded"
```

**原因**：containerd服务未正确运行或配置。

**解决方案**：
1. 检查containerd服务状态：`systemctl status containerd`
2. 创建正确的containerd配置：
   ```bash
   mkdir -p /etc/containerd
   cat > /etc/containerd/config.toml << EOF
   version = 2
   [plugins]
     [plugins."io.containerd.grpc.v1.cri"]
       sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.6"
       [plugins."io.containerd.grpc.v1.cri".containerd]
         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
           [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
             runtime_type = "io.containerd.runc.v2"
             [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
               SystemdCgroup = true
   EOF
   ```
3. 重启containerd：`systemctl restart containerd`

### 9.3 crictl工具连接问题

**症状**：执行`crictl info`命令报错，显示无法连接到容器运行时。

**原因**：crictl配置不正确，默认使用旧的dockershim套接字。

**解决方案**：
1. 创建正确的crictl配置：
   ```bash
   cat > /etc/crictl.yaml << EOF
   runtime-endpoint: unix:///run/containerd/containerd.sock
   image-endpoint: unix:///run/containerd/containerd.sock
   timeout: 10
   debug: false
   EOF
   ```
2. 确认containerd套接字文件存在：`ls -la /run/containerd/containerd.sock`

### 9.4 Worker节点缺少kubelet配置

**症状**：查询kubelet配置文件不存在：`/var/lib/kubelet/kubeadm-flags.env: No such file or directory`

**原因**：kubelet未正确初始化或之前的加入过程被中断。

**解决方案**：
1. 手动创建kubelet配置：
   ```bash
   mkdir -p /var/lib/kubelet
   cat > /var/lib/kubelet/kubeadm-flags.env << EOF
   KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.6"
   EOF
   ```
2. 重启kubelet：`systemctl restart kubelet`
3. 重新加入集群

### 9.5 Worker节点加入集群缓慢或卡住

**症状**：执行`kubeadm join`命令后，卡在TLS Bootstrap阶段。
```bash
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
[kubelet-check] Initial timeout of 40s passed.
```

**原因**：可能是网络连通性问题，证书问题，或kubelet配置不正确。

**解决方案**：
1. 检查kubelet日志：`journalctl -u kubelet --since "20 minutes ago" | grep -i error`
2. 测试网络连通性：`nc -zv k8s-master-internal 6443`
3. 使用IP地址代替主机名：`kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>`
4. 彻底清理Worker节点并重新加入

### 9.6 节点加入后处于NotReady状态

**症状**：节点成功加入集群，但所有节点状态显示为NotReady。
```bash
NAME          STATUS     ROLES           AGE     VERSION
k8s-master    NotReady   control-plane   57m     v1.28.2
k8s-worker1   NotReady   <none>          28m     v1.28.2
k8s-worker2   NotReady   <none>          8m28s   v1.28.2
```

**原因**：未安装网络插件（CNI）或网络插件未正确配置。

**解决方案**：
1. 安装Calico网络插件：
   ```bash
   curl https://docs.projectcalico.org/manifests/calico.yaml -O
   sed -i 's#docker.io/calico/#registry.cn-hangzhou.aliyuncs.com/google_containers/calico-#g' calico.yaml
   kubectl apply -f calico.yaml
   ```
2. 检查网络插件状态：`kubectl get pods -n kube-system | grep calico`
3. 等待所有节点变为Ready状态

### 9.7 排查技巧

1. **查看日志**是关键：
   - kubelet日志：`journalctl -u kubelet`
   - containerd日志：`journalctl -u containerd`
   - API服务器日志：`kubectl logs -n kube-system kube-apiserver-k8s-master`

2. **增加命令详细程度**：
   - 使用`--v=5`或更高数值增加日志详细程度
   - 例如：`kubeadm init --config=kubeadm-config.yaml --v=5`

3. **检查网络连通性**：
   - 测试节点间通信：`ping k8s-master-internal`
   - 测试特定端口：`nc -zv k8s-master-internal 6443`

4. **查看详细状态**：
   - 节点详情：`kubectl describe node k8s-master`
   - Pod状态：`kubectl get pods --all-namespaces -o wide`

5. **循序渐进**：
   - 先确保master节点Ready
   - 再添加worker节点
   - 部署测试应用验证功能 



### 9.6 无法下载calico

1. github下载

```shell
curl -O -L "https://github.com/projectcalico/calico/releases/download/v3.29.1/calicoctl-linux-amd64"
```

2. 拷贝到服务器 