# Cgroups - 资源的管家

> 给进程设置"配额"，防止它吃太多、用太多

## 一个故事引入

假设你是一个合租公寓的房东，有 10 个租客。公寓的总电量是 100 度/月。

如果不做任何限制，可能会发生什么？
- 租客 A 挖矿，一个月用了 80 度电
- 其他 9 个租客只能分剩下的 20 度
- 大家怨声载道，纷纷退租

聪明的房东会怎么做？
- 给每个房间装一个电表
- 设置每个房间的用电配额（比如 10 度/月）
- 超过配额就断电或者限速

**Cgroups 就是 Linux 内核里的"电表"和"配额管理系统"**。

---

## 什么是 Cgroups？

Cgroups（Control Groups）是 Linux 内核提供的一种机制，用于限制、记录和隔离进程组使用的物理资源。

简单说：**Cgroups 让你可以给一组进程设置资源配额**。

### Cgroups 能控制什么？

| 子系统 | 控制内容 | 生活比喻 |
|--------|---------|---------|
| **cpu** | CPU 使用时间 | 每天能用几度电 |
| **cpuset** | 绑定到特定 CPU 核心 | 只能用哪几个插座 |
| **memory** | 内存使用量 | 房间能放多少家具 |
| **blkio** | 磁盘 IO 速率 | 每天能用多少水 |
| **pids** | 进程数量 | 房间能住几个人 |
| **net_cls** | 网络流量分类 | 网络带宽配额 |
| **devices** | 设备访问权限 | 能用哪些电器 |
| **freezer** | 暂停/恢复进程 | 暂停房间的电 |

### Cgroups 的层级结构

Cgroups 是树形结构，子节点继承父节点的限制：

```
/sys/fs/cgroup/
├── cpu/
│   ├── docker/
│   │   ├── container1/
│   │   │   ├── cpu.cfs_quota_us
│   │   │   └── cgroup.procs
│   │   └── container2/
│   └── cpu.cfs_period_us
├── memory/
│   ├── docker/
│   │   ├── container1/
│   │   │   ├── memory.limit_in_bytes
│   │   │   └── cgroup.procs
│   │   └── container2/
│   └── memory.limit_in_bytes
└── ...
```

---

## 动手实验：CPU 限制

### 实验目标

创建一个消耗 CPU 的进程，然后用 Cgroups 限制它的 CPU 使用率。

### 实验 1：创建一个"吃 CPU"的程序

首先，我们需要一个会疯狂消耗 CPU 的程序。

```bash
# 创建一个死循环脚本
cat > /tmp/busyloop.sh << 'EOF'
#!/bin/bash
while true; do
    :  # 空操作，疯狂消耗 CPU
done
EOF

chmod +x /tmp/busyloop.sh
```

### 实验 2：运行程序，观察 CPU 使用

```bash
# 后台运行
/tmp/busyloop.sh &

# 记录 PID
BUSY_PID=$!
echo "进程 PID: $BUSY_PID"
```

```bash
# 使用 top 查看 CPU 使用率
top -p $BUSY_PID
```

**实验输出**：
```
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
12345 root      20   0   12345   1234    567 R 100.0  0.0   0:05.23 busyloop.sh
```

CPU 使用率接近 100%！这个进程正在疯狂消耗 CPU。

### 实验 3：创建 Cgroup 目录

```bash
# 进入 CPU cgroup 目录
cd /sys/fs/cgroup/cpu

# 创建一个新的 cgroup
mkdir cpudemo
cd cpudemo

# 查看目录内容
ls
```

**实验输出**：
```
cgroup.clone_children  cpu.cfs_period_us  cpu.shares      cpuacct.usage
cgroup.procs           cpu.cfs_quota_us   cpu.stat        cpuacct.usage_percpu
```

这些文件就是 Cgroups 的"控制面板"：
- `cgroup.procs`：属于这个 cgroup 的进程列表
- `cpu.cfs_quota_us`：CPU 配额（微秒）
- `cpu.cfs_period_us`：CPU 周期（微秒，默认 100000 = 100ms）

### 实验 4：把进程加入 Cgroup

```bash
# 把 busyloop 进程加入 cgroup
echo $BUSY_PID > cgroup.procs

# 验证
cat cgroup.procs
```

**实验输出**：
```
12345
```

### 实验 5：限制 CPU 使用率为 10%

CPU 配额的计算公式：
```
CPU 使用率 = cpu.cfs_quota_us / cpu.cfs_period_us × 100%
```

如果要限制为 10%：
- `cpu.cfs_period_us` = 100000（默认值，100ms）
- `cpu.cfs_quota_us` = 10000（10ms）
- 使用率 = 10000 / 100000 = 10%

```bash
# 设置 CPU 配额为 10%
echo 10000 > cpu.cfs_quota_us

# 验证设置
cat cpu.cfs_quota_us
```

**实验输出**：
```
10000
```

### 实验 6：观察限制效果

```bash
# 再次查看 CPU 使用率
top -p $BUSY_PID
```

**实验输出**：
```
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
12345 root      20   0   12345   1234    567 R  10.0  0.0   0:15.23 busyloop.sh
```

CPU 使用率从 100% 降到了 10%！Cgroups 成功限制了进程的 CPU 使用。

### 实验 7：清理实验环境

```bash
# 杀掉进程
kill $BUSY_PID

# 删除 cgroup（需要先确保没有进程）
cd /sys/fs/cgroup/cpu
rmdir cpudemo
```

---

## 动手实验：内存限制

### 实验目标

创建一个消耗内存的进程，然后用 Cgroups 限制它的内存使用，观察 OOM（Out of Memory）行为。

### 实验 1：创建一个"吃内存"的程序

```bash
# 创建一个不断申请内存的脚本
cat > /tmp/malloc.sh << 'EOF'
#!/bin/bash
# 不断申请内存
data=""
while true; do
    # 每次追加 1MB 数据
    data="${data}$(head -c 1048576 /dev/zero | tr '\0' 'x')"
    echo "当前内存使用: $(echo ${#data} | awk '{printf "%.2f MB", $1/1048576}')"
    sleep 0.5
done
EOF

chmod +x /tmp/malloc.sh
```

### 实验 2：创建 Memory Cgroup

```bash
# 进入 memory cgroup 目录
cd /sys/fs/cgroup/memory

# 创建新的 cgroup
mkdir memorydemo
cd memorydemo

# 查看目录内容
ls
```

**实验输出**：
```
cgroup.procs              memory.limit_in_bytes     memory.stat
memory.failcnt            memory.max_usage_in_bytes memory.usage_in_bytes
memory.force_empty        memory.oom_control        ...
```

关键文件：
- `memory.limit_in_bytes`：内存限制（字节）
- `memory.usage_in_bytes`：当前内存使用量
- `memory.oom_control`：OOM 控制

### 实验 3：设置内存限制为 100MB

```bash
# 设置内存限制为 100MB
echo 104857600 > memory.limit_in_bytes

# 验证设置
cat memory.limit_in_bytes
```

**实验输出**：
```
104857600
```

### 实验 4：运行程序并加入 Cgroup

```bash
# 后台运行
/tmp/malloc.sh &
MALLOC_PID=$!

# 把进程加入 cgroup
echo $MALLOC_PID > cgroup.procs
```

### 实验 5：观察内存使用和 OOM

```bash
# 监控内存使用
watch -n 1 'cat memory.usage_in_bytes | awk "{printf \"%.2f MB\n\", \$1/1048576}"'
```

**实验输出**（随时间变化）：
```
10.00 MB
20.00 MB
30.00 MB
...
95.00 MB
100.00 MB
```

当内存使用接近 100MB 时，进程会被 OOM Killer 杀掉！

```bash
# 检查进程是否还在
ps aux | grep malloc
```

**实验输出**：
```
（没有输出，进程已被杀掉）
```

```bash
# 查看 OOM 次数
cat memory.failcnt
```

**实验输出**：
```
1
```

### 实验 6：清理实验环境

```bash
# 删除 cgroup
cd /sys/fs/cgroup/memory
rmdir memorydemo

# 删除测试脚本
rm /tmp/malloc.sh /tmp/busyloop.sh
```

---

## Docker 如何使用 Cgroups

当你运行 `docker run --memory=512m --cpus=0.5 nginx` 时，Docker 会：

1. 创建一个新的 Cgroup
2. 设置 `memory.limit_in_bytes = 512MB`
3. 设置 `cpu.cfs_quota_us = 50000`（50% CPU）
4. 把容器进程加入这个 Cgroup

### 实验：查看 Docker 容器的 Cgroup 配置

```bash
# 启动一个有资源限制的容器
docker run -d --name cgroup-test --memory=256m --cpus=0.5 nginx

# 获取容器 ID
CONTAINER_ID=$(docker inspect cgroup-test --format '{{.Id}}')

# 查看容器的 cgroup 路径
docker inspect cgroup-test | grep -i cgroup
```

**实验输出**：
```json
"CgroupParent": "",
"Cgroup": "private",
```

```bash
# 查看内存限制
cat /sys/fs/cgroup/memory/docker/$CONTAINER_ID/memory.limit_in_bytes
```

**实验输出**：
```
268435456
```

268435456 字节 = 256 MB，正是我们设置的内存限制！

```bash
# 查看 CPU 配额
cat /sys/fs/cgroup/cpu/docker/$CONTAINER_ID/cpu.cfs_quota_us
```

**实验输出**：
```
50000
```

50000 / 100000 = 50%，正是我们设置的 CPU 限制！

```bash
# 清理
docker stop cgroup-test && docker rm cgroup-test
```

---

## Cgroups v1 vs v2

Linux 有两个版本的 Cgroups：

| 特性 | Cgroups v1 | Cgroups v2 |
|------|-----------|-----------|
| 目录结构 | 每个子系统独立目录 | 统一的层级结构 |
| 配置方式 | 分散在多个目录 | 集中在一个目录 |
| 资源控制 | 可能冲突 | 更一致 |
| 默认版本 | Ubuntu 20.04 及之前 | Ubuntu 22.04+ |

查看你的系统使用哪个版本：

```bash
# 如果存在这个目录，说明是 v2
ls /sys/fs/cgroup/cgroup.controllers

# 如果存在这些目录，说明是 v1
ls /sys/fs/cgroup/cpu /sys/fs/cgroup/memory
```

---

## 核心要点总结

1. **Cgroups 是什么**：Linux 内核特性，用于限制进程组的资源使用
2. **主要子系统**：cpu、memory、blkio、pids 等
3. **核心文件**：
   - `cgroup.procs`：进程列表
   - `cpu.cfs_quota_us`：CPU 配额
   - `memory.limit_in_bytes`：内存限制
4. **工作原理**：
   - 创建 cgroup 目录
   - 设置资源限制
   - 把进程加入 cgroup
5. **Docker 集成**：`--memory`、`--cpus` 等参数最终都是设置 Cgroups

记住这个比喻：**Cgroups 就是给进程的"配额管理系统"，防止它吃太多、用太多**。

---

## 思考题

1. 如果设置 `cpu.cfs_quota_us = 200000`，`cpu.cfs_period_us = 100000`，进程最多能用多少 CPU？（提示：可以超过 100%）
2. 为什么 Docker 默认不限制容器的资源？（提示：想想开发环境和生产环境的区别）
3. 如果一个容器被 OOM Kill，Docker 会怎么处理？（提示：看看 `--restart` 参数）

---

## 下一步

Namespace 实现了隔离，Cgroups 实现了限制。但容器还需要一个独立的文件系统。

下一篇我们学习 OverlayFS，它是 Docker 镜像分层存储的秘密。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[Namespace - 隔离的魔法](02-namespace.md)  
**下一篇**：[OverlayFS - 分层的文件系统](04-overlayfs.md)
