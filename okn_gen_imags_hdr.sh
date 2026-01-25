#!/usr/bin/env bash
set -euo pipefail

printf "################################################\n"
printf "Generating header files from PNG images start\n"
printf "################################################\n\n"

# 以脚本所在目录为基准, 避免从不同工作目录执行导致找不到路径
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

MT86_PATH="${SCRIPT_DIR}/uMemTest86Pkg"
PY_TOOL="${SCRIPT_DIR}/bin2header.py"

IMG_DIR="${MT86_PATH}/images"

# 基本检查
if [[ ! -d "$IMG_DIR" ]]; then
  echo "ERROR: images directory not found: $IMG_DIR" >&2
  exit 1
fi
if [[ ! -f "$PY_TOOL" ]]; then
  echo "ERROR: tool not found: $PY_TOOL" >&2
  exit 1
fi

# 没有匹配时让 glob 展开为空(而不是字面量 *.png)
# shopt 是 Bash 内建命令（shell option）
# -s 表示 set/开启
# nullglob 就是这个选项名
shopt -s nullglob

for file in "$IMG_DIR"/*.png; do
  base="$(basename -- "$file" .png)"
  out="${file%.png}.h"

  python3 "$PY_TOOL" -o "$out" -n "${base}_png_bin" "$file"
  echo "Generated: $out"
done
