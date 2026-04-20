#!/usr/bin/env bash
# push_efi.sh - 推送 MemTest86SiteX64.efi 到远端 /srv/tftp 并命名为 BOOTX64.efi
#
# 关键点：
# 1) /srv/tftp 通常只有 root 可写，不能直接 scp 到该目录；
# 2) 正确做法：先 scp 到远端临时目录(默认 /tmp)，再 ssh -t 在远端 sudo install 到 /srv/tftp。
#
# 依赖：scp, ssh；远端需要 okn 具备 sudo 权限（可交互输入 sudo 密码）。

set -euo pipefail

# ===== 默认配置 =====
BUILD_ROOT="./Build/MemTest86-site"        # 构建根目录
TYPE="DEBUG_GCC5"                          # DEBUG_GCC5 / RELEASE_GCC5
ARCH_PATH="X64/uMemTest86Pkg/uMemTest86Site/OUTPUT/MemTest86SiteX64.efi"

BASE_IP="192.168.101"                      # 固定前三段
LAST_OCTET="56"                            # 只改最后一段（默认 30）
FULL_IP=""                                 # 若传入则覆盖 BASE_IP/LAST_OCTET
USER="okn"
TARGET_DIR="/srv/tftp"
DEST_NAME="BOOTX64.efi"

TMP_DIR="/tmp"                             # 远端临时目录（必须 okn 可写）
IDENTITY=""                                # ssh 私钥路径(可选)
PORT=""                                    # ssh/scp 端口(可选)
DRYRUN=0
KEEP_TMP=0

usage() {
  cat <<EOF
用法: $0 [-t debug|release] [-o LAST_OCTET] [-I FULL_IP] [-u USER] [-k ID_RSA] [-d BUILD_ROOT] [-T TMP_DIR] [-p PORT] [-K] [-n]
  -t    构建类型: debug=DEBUG_GCC5, release=RELEASE_GCC5 (默认: debug)
  -o    只改最后一段 IP(默认: ${LAST_OCTET}), 与 -I 互斥
  -I    直接指定完整 IP, 覆盖 -o/BASE_IP
  -u    远端用户名 (默认: ${USER})
  -k    指定 ssh 私钥路径 (例如 ~/.ssh/id_rsa)；同时用于 scp/ssh
  -d    构建根目录 (默认: ${BUILD_ROOT})
  -T    远端临时目录 (默认: ${TMP_DIR})
  -p    端口 (scp 用 -P, ssh 用 -p)
  -K    保留远端临时文件（默认会删除）
  -n    dry-run: 仅打印将执行的命令, 不实际传输/执行
示例:
  $0 -t debug   -o 30
  $0 -t release -o 88
  $0 -t release -I 10.0.0.25 -u okn -k ~/.ssh/id_rsa
EOF
  exit 1
}

run_cmd() {
  # 打印并执行命令（支持 dry-run）
  echo "+ $*"
  if [[ "${DRYRUN}" -eq 0 ]]; then
    eval "$@"
  else
    echo "(dry-run) 未执行。"
  fi
}

# 解析参数
while getopts ":t:o:I:u:k:d:T:p:Kn" opt; do
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
    T) TMP_DIR="${OPTARG}" ;;
    p) PORT="${OPTARG}" ;;
    K) KEEP_TMP=1 ;;
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

REMOTE="${USER}@${HOST}"

# 校验
if [[ ! -f "${SRC}" ]]; then
  echo "错误: 找不到构建产物: ${SRC}"
  exit 2
fi

# 远端临时文件名（避免覆盖冲突）
TS="$(date +%Y%m%d_%H%M%S)"
REMOTE_TMP="${TMP_DIR}/${DEST_NAME}.${TS}.$$"

# scp/ssh 参数组装
SCP_CMD=(scp)
SSH_CMD=(ssh)

if [[ -n "${PORT}" ]]; then
  SCP_CMD+=(-P "${PORT}")
  SSH_CMD+=(-p "${PORT}")
fi

if [[ -n "${IDENTITY}" ]]; then
  SCP_CMD+=(-i "${IDENTITY}")
  SSH_CMD+=(-i "${IDENTITY}")
fi

# 1) 先把文件 scp 到远端临时目录
run_cmd "${SCP_CMD[@]} \"${SRC}\" \"${REMOTE}:${REMOTE_TMP}\""

# 2) 远端用 sudo install 到 /srv/tftp
#    注意：sudo 在很多机器上需要 TTY，因此用 ssh -t
if [[ "${USER}" == "root" ]]; then
  REMOTE_INSTALL="install -m 0644 \"${REMOTE_TMP}\" \"${TARGET_DIR}/${DEST_NAME}\""
  REMOTE_RM="rm -f \"${REMOTE_TMP}\""
  SSH_TTY_CMD=( "${SSH_CMD[@]}" )
else
  REMOTE_INSTALL="sudo install -m 0644 \"${REMOTE_TMP}\" \"${TARGET_DIR}/${DEST_NAME}\""
  REMOTE_RM="sudo rm -f \"${REMOTE_TMP}\""
  SSH_TTY_CMD=( "${SSH_CMD[@]}" -t )
fi

REMOTE_CMD="set -e; ${REMOTE_INSTALL}; sudo ls -l \"${TARGET_DIR}/${DEST_NAME}\""
if [[ "${KEEP_TMP}" -eq 0 ]]; then
  REMOTE_CMD="${REMOTE_CMD}; ${REMOTE_RM}"
else
  REMOTE_CMD="${REMOTE_CMD}; echo \"(keep) 临时文件保留在 ${REMOTE_TMP}\""
fi

run_cmd "${SSH_TTY_CMD[@]} \"${REMOTE}\" '${REMOTE_CMD}'"

echo "✅ 已推送到 ${REMOTE}:${TARGET_DIR}/${DEST_NAME}"