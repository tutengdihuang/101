# OverlayFS - 分层的文件系统

> Docker 镜像分层存储的秘密，像透明胶片一样叠加

## 一个问题引发的思考

假设你有 100 个容器，都基于 Ubuntu 镜像运行。Ubuntu 镜像大约 70MB。

**问题**：这 100 个容器需要占用多少磁盘空间？

**答案 A**：100 × 70MB = 7GB（每个容器一份完整的 Ubuntu）

**答案 B**：70MB + 少量增量（共享同一份 Ubuntu，只存储差异）

如果你选了 A，那你的硬盘会哭泣。Docker 选择了 B，这就是 OverlayFS 的魔力！

---

## 什么是 OverlayFS？

OverlayFS 是一种联合文件系统（Union Filesystem），它可以把多个目录"叠加"成一个目录。

想象一下透明胶片：
- 你有几张透明胶片，每张上面画了一些图案
- 把它们叠在一起，从上往下看
- 你看到的是所有胶片图案的"合成"

```
        从上往下看
            ↓
    ┌─────────────────┐
    │   上层胶片       │  ← 最新的修改
    ├─────────────────┤
    │   中层胶片       │  ← 之前的修改
    ├─────────────────┤
    │   底层胶片       │  ← 原始内容
    └─────────────────┘
            ↓
    你看到的合成图案
```

OverlayFS 就是这个原理：
- **lower（下层）**：只读层，存放原始内容
- **upper（上层）**：可写层，存放修改的内容
- **merged（合并层）**：叠加后的视图，用户看到的文件系统
- **work（工作层）**：OverlayFS 内部使用的临时目录

---

## 动手实验：理解 OverlayFS

### 实验 1：创建实验目录

```bash
# 创建实验目录
mkdir -p ~/overlayfs-lab && cd ~/overlayfs-lab

# 创建四个目录
mkdir lower upper merged work

# 查看目录结构
tree .
```

**实验输出**：
```
.
├── lower
├── merged
├── upper
└── work

4 directories, 0 files
```

### 实验 2：在 lower 和 upper 中创建文件

```bash
# 在 lower（下层）创建文件
echo "我来自 lower 层" > lower/in_lower.txt
echo "我在 lower 层" > lower/in_both.txt

# 在 upper（上层）创建文件
echo "我来自 upper 层" > upper/in_upper.txt
echo "我在 upper 层" > upper/in_both.txt

# 查看目录结构
tree .
```

**实验输出**：
```
.
├── lower
│   ├── in_both.txt      # 内容："我在 lower 层"
│   └── in_lower.txt     # 内容："我来自 lower 层"
├── merged
├── upper
│   ├── in_both.txt      # 内容："我在 upper 层"
│   └── in_upper.txt     # 内容："我来自 upper 层"
└── work

4 directories, 4 files
```

注意：`in_both.txt` 在 lower 和 upper 中都存在，但内容不同。

### 实验 3：挂载 OverlayFS

```bash
# 挂载 OverlayFS
sudo mount -t overlay overlay \
    -o lowerdir=$(pwd)/lower,upperdir=$(pwd)/upper,workdir=$(pwd)/work \
    $(pwd)/merged

# 验证挂载
df -h | grep overlay
```

**实验输出**：
```
overlay    50G   10G   40G  20% /root/overlayfs-lab/merged
```

### 实验 4：查看合并后的视图

```bash
# 查看 merged 目录
ls merged/
```

**实验输出**：
```
in_both.txt  in_lower.txt  in_upper.txt
```

三个文件都出现了！这就是"叠加"的效果。

```bash
# 查看各个文件的内容
cat merged/in_lower.txt
cat merged/in_upper.txt
cat merged/in_both.txt
```

**实验输出**：
```
我来自 lower 层
我来自 upper 层
我在 upper 层
```

关键发现：`in_both.txt` 显示的是 upper 层的内容！

**原理**：当同名文件在多层都存在时，上层会"遮盖"下层。就像透明胶片叠加，上面的图案会遮住下面的。

---

## 动手实验：写时复制（Copy-on-Write）

### 实验 5：在 merged 中创建新文件

```bash
# 在 merged 中创建新文件
echo "我是新创建的文件" > merged/new_file.txt

# 查看文件在哪里
ls -la lower/new_file.txt 2>/dev/null || echo "lower 中没有"
ls -la upper/new_file.txt 2>/dev/null || echo "upper 中没有"
ls -la merged/new_file.txt
```

**实验输出**：
```
lower 中没有
-rw-r--r-- 1 root root 27 Jan 15 11:00 upper/new_file.txt
-rw-r--r-- 1 root root 27 Jan 15 11:00 merged/new_file.txt
```

新文件被写入了 upper 层！lower 层保持不变（只读）。

### 实验 6：修改来自 lower 的文件

```bash
# 修改来自 lower 的文件
echo "我被修改了" >> merged/in_lower.txt

# 查看文件位置
ls -la lower/in_lower.txt
ls -la upper/in_lower.txt
cat merged/in_lower.txt
```

**实验输出**：
```
-rw-r--r-- 1 root root 22 Jan 15 10:50 lower/in_lower.txt
-rw-r--r-- 1 root root 40 Jan 15 11:05 upper/in_lower.txt

我来自 lower 层
我被修改了
```

发生了什么？
1. 原来 `in_lower.txt` 只在 lower 层
2. 修改后，upper 层出现了一个新的 `in_lower.txt`
3. lower 层的文件保持不变

这就是**写时复制（Copy-on-Write）**：
- 读取时，直接读 lower 层
- 修改时，先复制到 upper 层，再修改
- lower 层始终保持只读

### 实验 7：删除文件

```bash
# 删除来自 lower 的文件
rm merged/in_lower.txt

# 查看发生了什么
ls -la lower/in_lower.txt
ls -la upper/in_lower.txt
ls merged/
```

**实验输出**：
```
-rw-r--r-- 1 root root 22 Jan 15 10:50 lower/in_lower.txt
c--------- 1 root root 0, 0 Jan 15 11:10 upper/in_lower.txt

in_both.txt  in_upper.txt  new_file.txt
```

有趣的发现：
- lower 层的文件还在！
- upper 层出现了一个特殊的"白障文件"（whiteout file）
- merged 中看不到这个文件了

**白障文件**是 OverlayFS 的删除机制：它不真正删除 lower 层的文件，而是在 upper 层创建一个标记，表示"这个文件被删除了"。

### 实验 8：清理实验环境

```bash
# 卸载 OverlayFS
sudo umount merged

# 删除实验目录
cd ~
rm -rf ~/overlayfs-lab
```

---

## Docker 如何使用 OverlayFS

Docker 镜像是分层的，每一层都是一个 lower 目录。容器运行时，会在最上面加一个 upper 层（可写层）。

```
┌─────────────────────────────────────────┐
│           容器可写层 (upper)             │  ← 容器的修改写在这里
├─────────────────────────────────────────┤
│           镜像层 3 (lower)              │  ← 应用代码
├─────────────────────────────────────────┤
│           镜像层 2 (lower)              │  ← 依赖包
├─────────────────────────────────────────┤
│           镜像层 1 (lower)              │  ← 基础系统
└─────────────────────────────────────────┘
                    ↓
            merged（容器看到的文件系统）
```

### 实验：查看 Docker 的 OverlayFS

```bash
# 启动一个容器
docker run -d --name overlay-test nginx

# 查看容器的存储信息
docker inspect overlay-test | grep -A 10 "GraphDriver"
```

**实验输出**：
```json
"GraphDriver": {
    "Data": {
        "LowerDir": "/var/lib/docker/overlay2/abc123.../diff:/var/lib/docker/overlay2/def456.../diff",
        "MergedDir": "/var/lib/docker/overlay2/xyz789.../merged",
        "UpperDir": "/var/lib/docker/overlay2/xyz789.../diff",
        "WorkDir": "/var/lib/docker/overlay2/xyz789.../work"
    },
    "Name": "overlay2"
}
```

- `LowerDir`：镜像的各层（只读）
- `UpperDir`：容器的可写层
- `MergedDir`：容器看到的文件系统

```bash
# 在容器中创建一个文件
docker exec overlay-test touch /tmp/test-file

# 查看文件在宿主机的位置
sudo ls /var/lib/docker/overlay2/xyz789.../diff/tmp/
```

**实验输出**：
```
test-file
```

文件被写入了 UpperDir！

```bash
# 清理
docker stop overlay-test && docker rm overlay-test
```

---

## 镜像分层的好处

### 1. 节省磁盘空间

100 个基于 Ubuntu 的容器，只需要存储：
- 1 份 Ubuntu 镜像（70MB）
- 100 份容器的修改（可能只有几 MB）

总共可能只需要 100MB，而不是 7GB！

### 2. 加速镜像拉取

如果你已经有了 Ubuntu 镜像，拉取基于 Ubuntu 的新镜像时，只需要下载新增的层。

```bash
# 第一次拉取，下载所有层
docker pull ubuntu:20.04
# 下载 70MB

# 拉取基于 Ubuntu 的镜像，只下载新增层
docker pull nginx
# 只下载 nginx 相关的层，Ubuntu 层已经有了
```

### 3. 快速启动容器

启动容器时，不需要复制整个镜像，只需要创建一个空的 upper 层。

---

## OverlayFS 的工作原理图解

```
读取文件：
┌─────────────────────────────────────────┐
│  merged: cat /etc/nginx/nginx.conf      │
└─────────────────────────────────────────┘
                    ↓ 查找
┌─────────────────────────────────────────┐
│  upper: 没有这个文件                     │
└─────────────────────────────────────────┘
                    ↓ 继续查找
┌─────────────────────────────────────────┐
│  lower: 找到了！返回内容                 │
└─────────────────────────────────────────┘

修改文件：
┌─────────────────────────────────────────┐
│  merged: echo "new" >> /etc/nginx/...   │
└─────────────────────────────────────────┘
                    ↓ 
┌─────────────────────────────────────────┐
│  1. 从 lower 复制文件到 upper           │
│  2. 在 upper 中修改文件                 │
│  3. lower 保持不变                      │
└─────────────────────────────────────────┘

删除文件：
┌─────────────────────────────────────────┐
│  merged: rm /etc/nginx/nginx.conf       │
└─────────────────────────────────────────┘
                    ↓ 
┌─────────────────────────────────────────┐
│  1. 在 upper 创建白障文件               │
│  2. merged 中看不到这个文件了           │
│  3. lower 中的文件还在                  │
└─────────────────────────────────────────┘
```

---

## 核心要点总结

1. **OverlayFS 是什么**：联合文件系统，把多个目录叠加成一个
2. **四个目录**：
   - lower：只读层（镜像）
   - upper：可写层（容器修改）
   - merged：合并视图（容器看到的）
   - work：内部工作目录
3. **写时复制**：修改 lower 的文件时，先复制到 upper，再修改
4. **白障文件**：删除文件时，在 upper 创建标记，而不是真正删除
5. **Docker 应用**：镜像分层存储，节省空间，加速拉取

记住这个比喻：**OverlayFS 就像透明胶片叠加，上层遮盖下层，修改只在最上层**。

---

## 思考题

1. 如果容器删除后重新创建，之前的修改还在吗？（提示：upper 层会怎样？）
2. 为什么 Docker 镜像要设计成分层的？（提示：想想 Dockerfile 的每一行）
3. 如果 lower 有 10 层，读取一个只在最底层的文件，性能会受影响吗？

---

## 下一步

现在你已经理解了容器的三大核心技术：Namespace、Cgroups、OverlayFS。

但容器之间如何通信？容器如何访问外部网络？

下一篇我们学习容器网络，揭开 Docker 网络的神秘面纱。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[Cgroups - 资源的管家](03-cgroups.md)  
**下一篇**：[容器网络 - 连接的艺术](05-container-network.md)
