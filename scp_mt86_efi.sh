#!/usr/bin/env bash
# push_efi.sh - SCP 推送 MemTest86SiteX64.efi 到 TFTP 目录并命名为 BOOTX64.efi

set -euo pipefail

# ===== 默认配置 =====
BUILD_ROOT="./Build/MemTest86-site"        # 构建根目录
TYPE="DEBUG_GCC5"                          # 可选: DEBUG_GCC5 / RELEASE_GCC5
ARCH_PATH="X64/uMemTest86Pkg/uMemTest86Site/OUTPUT/MemTest86SiteX64.efi"

BASE_IP="192.168.101"                      # 固定前三段
LAST_OCTET="56"                            # 只改最后一段
FULL_IP=""                                 # 若传入则覆盖 BASE_IP/LAST_OCTET
USER="okn"
TARGET_DIR="/srv/tftp"
DEST_NAME="BOOTX64.efi"
IDENTITY=""                                # ssh 私钥路径(可选)
DRYRUN=0

usage() {
  cat <<EOF
用法: $0 [-t debug|release] [-o LAST_OCTET] [-I FULL_IP] [-u USER] [-k ID_RSA] [-d BUILD_ROOT] [-n]
  -t    构建类型: debug=DEBUG_GCC5, release=RELEASE_GCC5 (默认: debug)
  -o    只改最后一段 IP(默认: 53), 与 -I 互斥
  -I    直接指定完整 IP, 覆盖 -o/BASE_IP
  -u    远端用户名 (默认: ${USER})
  -k    指定 ssh 私钥路径 (例如 ~/.ssh/id_rsa)
  -d    构建根目录 (默认: ${BUILD_ROOT})
  -n    dry-run: 仅打印将执行的命令, 不实际传输
示例:
  $0 -t debug -o 53
  $0 -t release -o 88
  $0 -t release -I 10.0.0.25 -u root -k ~/.ssh/id_rsa
EOF
  exit 1
}

# 解析参数
while getopts ":t:o:I:u:k:d:n" opt; do
  case "$opt" in
    t)
      case "${OPTARG,,}" in
        debug|d)   TYPE="DEBUG_GCC5" ;;
        release|r) TYPE="RELEASE_GCC5" ;;
        *) echo "未知构建类型: ${OPTARG}"; usage ;;
      esac
      ;;
    o) LAST_OCTET="${OPTARG}" ;;
    I) FULL_IP="${OPTARG}" ;;
    u) USER="${OPTARG}" ;;
    k) IDENTITY="${OPTARG}" ;;
    d) BUILD_ROOT="${OPTARG}" ;;
    n) DRYRUN=1 ;;
    *) usage ;;
  esac
done

# 计算源文件与目标
SRC="${BUILD_ROOT}/${TYPE}/${ARCH_PATH}"
if [[ -n "${FULL_IP}" ]]; then
  HOST="${FULL_IP}"
else
  HOST="${BASE_IP}.${LAST_OCTET}"
fi
DEST="${USER}@${HOST}:${TARGET_DIR}/${DEST_NAME}"

# 校验
if [[ ! -f "${SRC}" ]]; then
  echo "错误: 找不到构建产物: ${SRC}"
  exit 2
fi

SCP_CMD=(scp)
if [[ -n "${IDENTITY}" ]]; then
  SCP_CMD+=(-i "${IDENTITY}")
fi
SCP_CMD+=("${SRC}" "${DEST}")

echo "+ ${SCP_CMD[*]}"
if [[ ${DRYRUN} -eq 0 ]]; then
  "${SCP_CMD[@]}"
  echo "已推送到 ${DEST}"
else
  echo "(dry-run) 未执行传输。"
fi
