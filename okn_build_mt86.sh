#!/usr/bin/env bash

# build_mt86.sh - choose DEBUG/RELEASE build for uMemTest86

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
