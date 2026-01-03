#!/bin/bash

# 阿里云镜像仓库地址
REGISTRY="crpi-j9gshcbjtb1i6c7h.cn-hangzhou.personal.cr.aliyuncs.com"
NAMESPACE="tutengdihuang_docker_image"

# 先登录
echo "=== 登录阿里云镜像仓库 ==="
echo "Aliyun123!" | docker login --username=tutengdihuang@163.com --password-stdin ${REGISTRY}

# 获取所有非阿里云的镜像
echo ""
echo "=== 开始推送镜像 ==="

# 定义要推送的镜像列表（排除已经是阿里云仓库的镜像和 <none> 标签）
docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "crpi-j9gshcbjtb1i6c7h" | grep -v "registry.cn-hangzhou" | grep -v "<none>" | grep -v "182.42.82.135" | while read image; do
    # 跳过空行
    [ -z "$image" ] && continue
    
    # 提取镜像名和标签
    # 处理带有 / 的镜像名，只取最后一部分作为镜像名
    image_name=$(echo "$image" | sed 's|.*/||' | cut -d: -f1)
    tag=$(echo "$image" | cut -d: -f2)
    
    # 如果标签为空，设为 latest
    [ -z "$tag" ] && tag="latest"
    
    # 新的镜像名
    new_image="${REGISTRY}/${NAMESPACE}/${image_name}:${tag}"
    
    echo ""
    echo "----------------------------------------"
    echo "原镜像: $image"
    echo "目标镜像: $new_image"
    
    # 打标签
    echo "打标签..."
    docker tag "$image" "$new_image"
    
    # 推送
    echo "推送中..."
    docker push "$new_image"
    
    if [ $? -eq 0 ]; then
        echo "✅ 推送成功: $new_image"
    else
        echo "❌ 推送失败: $new_image"
    fi
done

echo ""
echo "=== 推送完成 ==="
