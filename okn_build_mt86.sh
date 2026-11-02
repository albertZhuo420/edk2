#!/usr/bin/env bash

# docker 容器拉取命令: docker pull ghcr.io/tianocore/containers/ubuntu-22-build:latest
# 没有权限就加sudo

# 把用户加入 docker 组, 这是 Docker 官方提供的免 sudo 方式, Docker 官方说明
# 在宿主机终端执行一次:
#   sudo groupadd -f docker
#   sudo usermod -aG docker "$USER"
#
# 然后重启系统, 再检查:
#   id -nG
#   docker image ls
#     - id -nG 应包含 docker, 且 docker image ls 不再报权限错误。Docker 组拥有接近宿主机 root 的权限, 只应授予受信任的用户。

# build_mt86.sh - choose DEBUG/RELEASE build for uMemTest86

# 使用方法:
#  从任意目录执行, 自动以本脚本所在目录为 EDK2_ROOT.
#  宿主机需要 Docker (容器运行工具); edksetup.sh 在容器内执行.
#  例如编译 DDR4 RDIMM 的 DEBUG 固件:
#    bash /path/to/edk2-MT86_11.7/okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR4_RDIMM
# 
# OKN 输出目录:
# 
# Build/MemTest86-site-Okn/DEBUG_GCC5/X64/
# Build/MemTest86-site-Okn/RELEASE_GCC5/X64/
# 
# 输出目录:
# 
# Build/MemTest86-site/DEBUG_GCC5/X64/
# Build/MemTest86-site/RELEASE_GCC5/X64/
# 
# 
# ### 完整 DEBUG 验证组合
# 
# bash okn_build_mt86.sh debug -D OKN_ENABLE=FALSE
# 
# bash okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR4_RDIMM
# bash okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR5_LPDDR5
# bash okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR5_UDIMM
# bash okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR5_SODIMM
# 
# ### 完整 RELEASE 组合
# 
# bash okn_build_mt86.sh release -D OKN_ENABLE=FALSE
# 
# bash okn_build_mt86.sh release -D OKN_PLATFORM=INTEL_DDR4_RDIMM
# bash okn_build_mt86.sh release -D OKN_PLATFORM=INTEL_DDR5_LPDDR5
# bash okn_build_mt86.sh release -D OKN_PLATFORM=INTEL_DDR5_UDIMM
# bash okn_build_mt86.sh release -D OKN_PLATFORM=INTEL_DDR5_SODIMM
# 
# OKN_ENABLE 默认为 TRUE, 因此 OKN 构建可以省略 -D OKN_ENABLE=TRUE, 但必须指定 OKN_PLATFORM.
# 
# 注意 -D 前不要添加 --. 当前脚本会把剩余参数直接传递给 EDK2 build.
#

set -euo pipefail

EDK2_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
DSC="uMemTest86Pkg/uMemTest86SitePkg.dsc"
# DSC="uMemTest86Pkg/uMemTest86ProPkg.dsc"

usage() {
  echo "用法: $0 [debug|release] [其它build参数]"
  echo "示例:"
  echo "  $0 debug"
  echo "  $0 release -D OKN_PLATFORM=INTEL_DDR5_SODIMM"
  exit 1
}

# 解析构建类型(默认 debug)
# 取第 1 个位置参数($1)；
# 如果 $1 未设置或为空字符串，就使用默认值 debug
# 
# ${var:-word}：未设置或空 → 用 word(不改变 var)
# ${var:=word}：未设置或空 → 用 word 并赋回 var
# ${var:?msg}：未设置或空 → 打印 msg 并退出(常用于必填参数)
# ${var:+word}：已设置且非空 → 用 word；否则空
BTYPE="${1:-debug}"
case "${BTYPE,,}" in
  -h|--help) usage ;;
  d|debug)    B=DEBUG ;;
  r|release)  B=RELEASE ;;
  *) echo "未知构建类型: ${BTYPE}"; usage ;;
esac
shift || true

# EDK2_ROOT 取脚本所在目录, 与调用时的当前目录无关.
if [[ ! -f "$EDK2_ROOT/$DSC" ]]; then
  echo "错误: 找不到 $EDK2_ROOT/$DSC"
  exit 2
fi

# 默认在 Tianocore Ubuntu 22 容器内编译. 只允许容器写 Build/ 和 Conf/,
# 其余 EDK2 源码以只读方式挂载. 标记变量阻止容器内再次启动容器.
if [[ "${OKN_IN_DOCKER:-0}" != "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "错误: 找不到 docker 命令"
    exit 3
  fi
  if [[ ! -d "$EDK2_ROOT/Conf" ]]; then
    echo "错误: 容器构建需要已有的 $EDK2_ROOT/Conf 目录"
    exit 4
  fi
  # sudo 启动时仍以原用户运行容器, 避免构建产物归 root 所有.
  BUILD_UID="${SUDO_UID:-$(id -u)}"
  BUILD_GID="${SUDO_GID:-$(id -g)}"
  # bind mount (绑定挂载) 要求宿主机源目录存在; Build/ 由脚本自动创建.
  if [[ ! -d "$EDK2_ROOT/Build" ]]; then
    mkdir "$EDK2_ROOT/Build"
    if [[ "$(id -u)" == "0" && -n "${SUDO_UID:-}" ]]; then
      chown "$BUILD_UID:$BUILD_GID" "$EDK2_ROOT/Build"
    fi
  fi
  exec docker run --rm \
    --user "$BUILD_UID:$BUILD_GID" \
    --env HOME=/tmp --env OKN_IN_DOCKER=1 \
    --mount "type=bind,src=$EDK2_ROOT,dst=$EDK2_ROOT,readonly" \
    --mount "type=bind,src=$EDK2_ROOT/Build,dst=$EDK2_ROOT/Build" \
    --mount "type=bind,src=$EDK2_ROOT/Conf,dst=$EDK2_ROOT/Conf" \
    --workdir "$EDK2_ROOT" --entrypoint /bin/bash \
    ghcr.io/tianocore/containers/ubuntu-22-build:latest \
    -lc 'okn_setup() { source ./edksetup.sh; }; okn_setup && exec bash ./okn_build_mt86.sh "$@"' \
    bash "$BTYPE" "$@"
fi

cd "$EDK2_ROOT"

echo "+ build -a X64 -t GCC5 -b $B -p $DSC $*"
build -a X64 -t GCC5 -b "$B" -p "$DSC" "$@"
