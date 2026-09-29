#!/usr/bin/env bash

# build_mt86.sh - choose DEBUG/RELEASE build for uMemTest86

# 使用方法:
#  在 EDK2 根目录执行, 例如编译 DDR4 RDIMM 的 DEBUG 固件:
#    cd /home/zmsinance/work/Code/DDR/UEFI/EDK2/edk2-MT86_11.7
#    source edksetup.sh
#    bash okn_build_mt86.sh debug -D OKN_PLATFORM=INTEL_DDR4_RDIMM
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
# source ./edksetup.sh
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
# source ./edksetup.sh
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

DSC="uMemTest86Pkg/uMemTest86SitePkg.dsc"
# DSC="uMemTest86Pkg/uMemTest86ProPkg.dsc"

usage() {
  echo "用法: $0 [debug|release] [-- 其它build参数]"
  echo "示例:"
  echo "  $0 debug"
  echo "  $0 release -- -n  # 透传 -n 给 build"
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

# 确保在含有 .dsc 的目录下运行；若脚本与包同目录，也能自动切到脚本所在处
if [[ ! -f "$DSC" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$SCRIPT_DIR/$DSC" ]]; then
    cd "$SCRIPT_DIR"
  else
    echo "错误: 找不到 $DSC(当前目录: $(pwd))"
    exit 2
  fi
fi

echo "+ build -a X64 -t GCC5 -b $B -p $DSC $*"
build -a X64 -t GCC5 -b "$B" -p "$DSC" "$@"
