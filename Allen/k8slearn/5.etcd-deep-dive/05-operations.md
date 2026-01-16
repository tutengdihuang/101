# etcd 运维实践 - 保持健康运行

> 预防胜于治疗

## 监控指标

### 关键指标

| 指标 | 说明 | 告警阈值 |
|------|------|---------|
| etcd_server_has_leader | 是否有 Leader | = 0 告警 |
| etcd_server_leader_changes_seen_total | Leader 切换次数 | 频繁切换告警 |
| etcd_disk_wal_fsync_duration_seconds | WAL 同步延迟 | > 100ms 告警 |
| etcd_disk_backend_commit_duration_seconds | 后端提交延迟 | > 100ms 告警 |
| etcd_server_proposals_failed_total | 失败的提案数 | > 0 告警 |
| etcd_mvcc_db_total_size_in_bytes | 数据库大小 | > 80% 配额告警 |

### 查看端点状态

```bash
# 查看端点状态
etcdctl endpoint status -w table

# 查看健康状态
etcdctl endpoint health

# 查看 metrics（Prometheus 格式）
curl http://127.0.0.1:2379/metrics
```

---

## 存储配额管理

etcd 默认存储配额是 2GB，超过后会拒绝写入。

### 实验：存储配额

```bash
# 启动一个小配额的 etcd（16MB）
etcd --quota-backend-bytes=$((16*1024*1024)) &

# 查看当前状态
etcdctl endpoint status -w table
```

### 实验：写爆磁盘

```bash
# 持续写入直到超过配额
while [ 1 ]; do
  dd if=/dev/urandom bs=1024 count=1024 2>/dev/null | etcdctl put key || break
done
```

**实验输出**：
```
Error: etcdserver: mvcc: database space exceeded
```

### 查看告警

```bash
# 查看告警列表
etcdctl alarm list
```

**实验输出**：
```
memberID:8e9e05c52164694d alarm:NOSPACE
```

### 解决空间不足

```bash
# 1. 获取当前 revision
rev=$(etcdctl endpoint status --write-out="json" | jq '.[0].Status.header.revision')

# 2. 压缩历史版本
etcdctl compact $rev

# 3. 碎片整理
etcdctl defrag

# 4. 清除告警
etcdctl alarm disarm

# 5. 验证
etcdctl endpoint status -w table
etcdctl alarm list
```

---

## 碎片整理（Defrag）

etcd 删除数据后，磁盘空间不会立即释放，需要碎片整理。

### 为什么需要碎片整理？

```
删除前：[数据1][数据2][数据3][数据4]
删除后：[数据1][空洞][数据3][空洞]
整理后：[数据1][数据3]
```

### 实验：碎片整理

```bash
# 写入大量数据
for i in $(seq 1 1000); do
  etcdctl put /test/key$i "value$i"
done

# 查看数据库大小
etcdctl endpoint status -w table

# 删除数据
etcdctl del --prefix /test/

# 再次查看（大小没变）
etcdctl endpoint status -w table

# 碎片整理
etcdctl defrag

# 再次查看（大小减小了）
etcdctl endpoint status -w table
```

### 自动压缩

```bash
# 启动时配置自动压缩（保留 1 小时历史）
etcd --auto-compaction-retention=1h

# 或者保留最近 1000 个 revision
etcd --auto-compaction-retention=1000 --auto-compaction-mode=revision
```

### 手动压缩

```bash
# 获取当前 revision
rev=$(etcdctl endpoint status --write-out="json" | jq '.[0].Status.header.revision')

# 压缩到当前 revision
etcdctl compact $rev

# 碎片整理
etcdctl defrag
```

---

## 性能调优

### 硬件建议

| 组件 | 建议配置 | 说明 |
|------|---------|------|
| CPU | 4+ 核 | Raft 共识需要 CPU |
| 内存 | 8GB+ | 缓存数据 |
| 磁盘 | SSD | 必须！HDD 性能太差 |
| 网络 | 低延迟 | 节点间通信 |

### 关键参数

```bash
etcd \
  --heartbeat-interval=100 \           # 心跳间隔（ms）
  --election-timeout=1000 \            # 选举超时（ms）
  --snapshot-count=10000 \             # 快照触发阈值
  --quota-backend-bytes=8589934592 \   # 存储配额（8GB）
  --auto-compaction-retention=1 \      # 自动压缩（1小时）
  --max-request-bytes=1572864          # 最大请求大小（1.5MB）
```

### 磁盘性能测试

```bash
# 测试磁盘写入性能
fio --name=etcd-test --filename=/var/lib/etcd/test \
  --rw=write --bs=4k --direct=1 --numjobs=1 \
  --time_based --runtime=60 --group_reporting

# etcd 要求：
# - 99th percentile fsync < 10ms
# - 平均 fsync < 1ms
```

---

## 故障排查

### 常见问题 1：Leader 频繁切换

**症状**：
```bash
etcdctl endpoint status -w table
# RAFT TERM 不断增加
```

**原因**：
- 网络延迟高
- 磁盘 I/O 慢
- CPU 不足

**解决**：
```bash
# 增加选举超时
etcd --election-timeout=5000

# 检查磁盘性能
iostat -x 1

# 检查网络延迟
ping <other-node>
```

### 常见问题 2：空间不足

**症状**：
```
Error: etcdserver: mvcc: database space exceeded
```

**解决**：
```bash
# 压缩 + 碎片整理 + 清除告警
etcdctl compact $(etcdctl endpoint status -w json | jq '.[0].Status.header.revision')
etcdctl defrag
etcdctl alarm disarm
```

### 常见问题 3：请求超时

**症状**：
```
Error: context deadline exceeded
```

**原因**：
- 网络问题
- etcd 负载过高
- 磁盘 I/O 慢

**解决**：
```bash
# 增加超时时间
etcdctl --command-timeout=30s get /key

# 检查 etcd 负载
etcdctl endpoint status -w table
```

---

## 监控告警配置

### Prometheus 告警规则

```yaml
groups:
- name: etcd
  rules:
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd 集群没有 Leader"
      
  - alert: EtcdHighFsyncDuration
    expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd WAL 同步延迟过高"
      
  - alert: EtcdDatabaseSpaceExceeded
    expr: etcd_mvcc_db_total_size_in_bytes / etcd_server_quota_backend_bytes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd 存储空间使用超过 80%"
```

---

## 核心要点

1. **监控**：关注 Leader 状态、磁盘延迟、存储空间
2. **压缩**：定期压缩历史版本，释放空间
3. **碎片整理**：删除数据后执行 defrag
4. **告警**：配置关键指标告警
5. **硬件**：SSD 是必须的

---

## 下一步

运维实践掌握了，最后学习如何在 K8s 集群中操作 etcd。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[etcd 备份恢复](04-backup-restore.md)  
**下一篇**：[K8s 中的 etcd](06-etcd-in-k8s.md)
