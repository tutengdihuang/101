# Docker 镜像优化 - 让镜像更小更快

> 小镜像 = 快拉取 + 快部署 + 省空间 + 更安全

## 为什么要优化镜像？

假设你有一个 1GB 的镜像，部署到 100 台服务器：
- 拉取时间：每台 5 分钟 × 100 = 500 分钟
- 存储空间：1GB × 100 = 100GB
- 网络带宽：1GB × 100 = 100GB

如果优化到 100MB：
- 拉取时间：每台 30 秒 × 100 = 50 分钟
- 存储空间：100MB × 100 = 10GB
- 网络带宽：100MB × 100 = 10GB

**镜像越小，部署越快，成本越低！**

而且，小镜像意味着更少的组件，更少的攻击面，更安全。

---

## 镜像优化三板斧

### 1. 使用更小的基础镜像
### 2. 多阶段构建
### 3. 减少镜像层数和清理缓存

---

## 第一板斧：使用更小的基础镜像

### 常见基础镜像大小对比

```bash
# 查看常见基础镜像大小
docker images | grep -E "ubuntu|alpine|busybox|distroless"
```

| 镜像 | 大小 | 特点 |
|------|------|------|
| ubuntu:22.04 | ~77MB | 功能完整，包管理方便 |
| debian:slim | ~80MB | 精简版 Debian |
| alpine:3.18 | ~7MB | 超小，使用 musl libc |
| busybox | ~1.5MB | 最小，只有基本命令 |
| gcr.io/distroless/static | ~2MB | Google 出品，无 shell |

### 实验：对比不同基础镜像

```bash
# 拉取并对比大小
docker pull ubuntu:22.04
docker pull alpine:3.18
docker pull busybox:latest

docker images | grep -E "ubuntu|alpine|busybox"
```

**实验输出**：
```
REPOSITORY   TAG       IMAGE ID       SIZE
ubuntu       22.04     xxxx           77.8MB
alpine       3.18      xxxx           7.34MB
busybox      latest    xxxx           1.24MB
```

alpine 只有 ubuntu 的 1/10！

### Alpine 镜像的使用

Alpine 是最常用的小型基础镜像，但有一些注意事项：

```dockerfile
# 使用 Alpine 作为基础镜像
FROM alpine:3.18

# Alpine 使用 apk 而不是 apt
RUN apk add --no-cache \
    curl \
    git \
    python3

# --no-cache 避免缓存占用空间
```

**Alpine 的优缺点**：

| 优点 | 缺点 |
|------|------|
| 体积小（7MB） | 使用 musl libc，可能有兼容性问题 |
| 安全（攻击面小） | 包管理器是 apk，不是 apt |
| 启动快 | 某些软件需要额外配置 |

### Distroless 镜像

Google 的 Distroless 镜像更极端：没有 shell，没有包管理器，只有运行时。

```dockerfile
# 多阶段构建，最终使用 distroless
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o myapp

FROM gcr.io/distroless/static
COPY --from=builder /app/myapp /
CMD ["/myapp"]
```

Distroless 镜像只有 2-3MB，而且没有 shell，黑客即使进入容器也无法执行命令。

---

## 第二板斧：多阶段构建

### 问题：构建工具占用空间

编译一个 Go 程序需要 Go 编译器，但运行时不需要。

**传统方式**：
```dockerfile
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o myapp
CMD ["./myapp"]
```

这个镜像会包含整个 Go 编译器（~1GB），但运行时只需要一个几 MB 的二进制文件！

### 解决方案：多阶段构建

```dockerfile
# 第一阶段：构建
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o myapp

# 第二阶段：运行
FROM alpine:3.18
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]
```

**原理**：
1. 第一阶段用完整的 Go 环境编译
2. 第二阶段只复制编译好的二进制文件
3. 最终镜像不包含 Go 编译器

### 实验：对比多阶段构建效果

创建一个简单的 Go 程序：

```bash
mkdir -p ~/docker-optimize && cd ~/docker-optimize

# 创建 Go 程序
cat > main.go << 'EOF'
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello, Docker!")
    })
    fmt.Println("Server starting on :8080")
    http.ListenAndServe(":8080", nil)
}
EOF

# 创建 go.mod
cat > go.mod << 'EOF'
module myapp
go 1.21
EOF
```

**传统 Dockerfile**：
```bash
cat > Dockerfile.traditional << 'EOF'
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o myapp
CMD ["./myapp"]
EOF
```

**多阶段 Dockerfile**：
```bash
cat > Dockerfile.multistage << 'EOF'
# 构建阶段
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o myapp

# 运行阶段
FROM alpine:3.18
COPY --from=builder /app/myapp /usr/local/bin/
EXPOSE 8080
CMD ["myapp"]
EOF
```

**构建并对比**：
```bash
# 构建传统镜像
docker build -f Dockerfile.traditional -t myapp:traditional .

# 构建多阶段镜像
docker build -f Dockerfile.multistage -t myapp:multistage .

# 对比大小
docker images | grep myapp
```

**实验输出**：
```
REPOSITORY   TAG           IMAGE ID       SIZE
myapp        traditional   xxxx           1.1GB
myapp        multistage    xxxx           15MB
```

从 1.1GB 降到 15MB，减少了 98%！

### 更极致：使用 scratch 或 distroless

```dockerfile
# 构建阶段
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o myapp

# 运行阶段：使用空镜像
FROM scratch
COPY --from=builder /app/myapp /
EXPOSE 8080
CMD ["/myapp"]
```

`scratch` 是一个空镜像，最终镜像只包含你的二进制文件，可能只有几 MB！

---

## 第三板斧：减少层数和清理缓存

### 问题：每条指令都是一层

```dockerfile
# 不好的写法：3 层
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
```

```dockerfile
# 好的写法：1 层
RUN apt-get update && \
    apt-get install -y curl git
```

### 问题：缓存没有清理

```dockerfile
# 不好的写法：缓存留在镜像里
RUN apt-get update
RUN apt-get install -y curl git
# apt 缓存还在！
```

```dockerfile
# 好的写法：清理缓存
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git && \
    rm -rf /var/lib/apt/lists/*
```

### 问题：下载文件没有清理

```dockerfile
# 不好的写法：下载的文件留在镜像里
ADD https://example.com/big.tar.xz /usr/src/things/
RUN tar -xJf /usr/src/things/big.tar.xz -C /usr/src/things
RUN make -C /usr/src/things all
# big.tar.xz 还在！
```

```dockerfile
# 好的写法：下载、解压、编译、清理在一层完成
RUN mkdir -p /usr/src/things && \
    curl -SL https://example.com/big.tar.xz | tar -xJC /usr/src/things && \
    make -C /usr/src/things all && \
    rm -rf /usr/src/things/big.tar.xz
```

### 实验：对比清理缓存的效果

```bash
# 不清理缓存的 Dockerfile
cat > Dockerfile.nocache << 'EOF'
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y curl git vim
EOF

# 清理缓存的 Dockerfile
cat > Dockerfile.clean << 'EOF'
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git vim && \
    rm -rf /var/lib/apt/lists/*
EOF

# 构建并对比
docker build -f Dockerfile.nocache -t test:nocache .
docker build -f Dockerfile.clean -t test:clean .

docker images | grep test
```

**实验输出**：
```
REPOSITORY   TAG       IMAGE ID       SIZE
test         nocache   xxxx           250MB
test         clean     xxxx           180MB
```

清理缓存节省了 70MB！

---

## 最佳实践清单

### Dockerfile 优化清单

```dockerfile
# 1. 使用小型基础镜像
FROM alpine:3.18
# 而不是 FROM ubuntu:22.04

# 2. 合并 RUN 指令，减少层数
RUN apk add --no-cache curl git && \
    rm -rf /var/cache/apk/*

# 3. 使用 --no-cache 或清理缓存
RUN apt-get update && \
    apt-get install -y --no-install-recommends package && \
    rm -rf /var/lib/apt/lists/*

# 4. 使用多阶段构建
FROM golang:1.21 AS builder
# ... 构建 ...
FROM alpine:3.18
COPY --from=builder /app/binary /

# 5. 使用 .dockerignore 排除不需要的文件
# 在 .dockerignore 中添加：
# .git
# node_modules
# *.log

# 6. 把不常变化的层放在前面（利用缓存）
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build

# 7. 使用特定版本的标签
FROM alpine:3.18
# 而不是 FROM alpine:latest
```

### .dockerignore 示例

```bash
cat > .dockerignore << 'EOF'
# Git
.git
.gitignore

# 依赖目录
node_modules
vendor

# 构建产物
dist
build
*.exe
*.dll

# 日志和临时文件
*.log
*.tmp
.DS_Store

# IDE
.idea
.vscode
*.swp

# 测试
*_test.go
test/
EOF
```

---

## 镜像大小分析工具

### 使用 docker history

```bash
# 查看镜像的每一层
docker history myapp:traditional
```

**实验输出**：
```
IMAGE          CREATED        CREATED BY                                      SIZE
xxxx           2 minutes ago  CMD ["./myapp"]                                 0B
xxxx           2 minutes ago  RUN go build -o myapp                           15MB
xxxx           2 minutes ago  COPY . .                                        5KB
xxxx           2 minutes ago  WORKDIR /app                                    0B
xxxx           3 days ago     /bin/sh -c #(nop)  ENV PATH=/go/bin:/usr/...   0B
...
```

### 使用 dive 工具

dive 是一个分析镜像层的工具，可以看到每一层添加/删除了哪些文件。

```bash
# 安装 dive
# macOS
brew install dive

# Linux
wget https://github.com/wagoodman/dive/releases/download/v0.10.0/dive_0.10.0_linux_amd64.deb
sudo dpkg -i dive_0.10.0_linux_amd64.deb

# 分析镜像
dive myapp:traditional
```

---

## 核心要点总结

1. **使用小型基础镜像**：
   - alpine（7MB）替代 ubuntu（77MB）
   - distroless（2MB）用于生产环境
   - scratch（0MB）用于静态编译的程序

2. **多阶段构建**：
   - 构建阶段用完整环境
   - 运行阶段只复制必要文件
   - 最终镜像不包含构建工具

3. **减少层数和清理缓存**：
   - 合并 RUN 指令
   - 使用 `--no-cache` 或 `rm -rf /var/lib/apt/lists/*`
   - 下载、解压、编译、清理在一层完成

4. **其他技巧**：
   - 使用 .dockerignore
   - 把不常变化的层放前面
   - 使用特定版本标签

记住这个公式：**小镜像 = 小基础镜像 + 多阶段构建 + 清理缓存**

---

## 思考题

1. 为什么 Alpine 使用 musl libc 可能导致兼容性问题？（提示：glibc vs musl）
2. 多阶段构建的 `COPY --from=builder` 是如何工作的？（提示：构建缓存）
3. 为什么要把 `COPY go.mod go.sum` 放在 `COPY . .` 前面？（提示：层缓存）

---

## 总结

通过这个系列，你已经掌握了 Docker 的核心技术：

| 技术 | 作用 | 关键点 |
|------|------|--------|
| Namespace | 隔离 | 让进程看不到其他进程 |
| Cgroups | 限制 | 限制 CPU、内存等资源 |
| OverlayFS | 分层 | 镜像分层存储，写时复制 |
| 网络 | 连接 | veth + bridge + iptables |
| 镜像优化 | 效率 | 小基础镜像 + 多阶段构建 |

现在你不仅会用 Docker，还理解了它的底层原理。这些知识对于理解 Kubernetes、排查容器问题都非常有帮助。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[容器网络 - 连接的艺术](05-container-network.md)  
**返回目录**：[README](README.md)
