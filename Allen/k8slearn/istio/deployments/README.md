# Istio 部署文件

此目录包含 Istio 的所有部署脚本和配置文件。

## 目录结构

- `install/` - Istio 安装相关文件
  - `istio-operator.yaml` - Istio Operator 部署文件
  - `istio-profile.yaml` - Istio 自定义配置文件
  - `install.sh` - 安装脚本

- `examples/` - 示例应用
  - `bookinfo/` - Bookinfo 示例应用
  - `hello-world/` - 简单的 Hello World 示例

- `gateways/` - Gateway 配置
  - `ingress-gateway.yaml` - 入口网关配置
  - `egress-gateway.yaml` - 出口网关配置

- `virtualservices/` - VirtualService 配置
  - `bookinfo-vs.yaml` - Bookinfo 应用路由配置

- `destinationrules/` - DestinationRule 配置
  - `bookinfo-dr.yaml` - Bookinfo 应用流量规则

- `authorizationpolicies/` - 授权策略
  - `allow-all.yaml` - 允许所有流量
  - `deny-specific.yaml` - 拒绝特定流量

- `telemetry/` - 可观测性配置
  - `metrics.yaml` - 指标配置
  - `access-logging.yaml` - 访问日志配置
  - `tracing.yaml` - 链路追踪配置

## 使用方法

1. 安装 Istio:
   ```bash
   cd install
   ./install.sh
   ```

2. 部署示例应用:
   ```bash
   cd examples/bookinfo
   kubectl apply -f .
   ```

3. 配置网关和路由:
   ```bash
   kubectl apply -f gateways/
   kubectl apply -f virtualservices/
   ```

## 注意事项

- 所有文件在部署到远程服务器前，请先在本地修改
- 使用以下命令部署到远程服务器:
  ```bash
  kubectl apply -f <file.yaml>
  ```
