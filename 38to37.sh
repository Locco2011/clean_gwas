#!/bin/bash

# 38to37.sh

# 检查是否提供了输入文件参数
if [ "$#" -ne 1 ]; then
    echo "用法: ./38to37.sh <你的文件名.txt>"
    exit 1
fi

# 获取输入文件名
INPUT_FILE="$1"

# 检查输入文件是否存在
if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 输入文件 '$INPUT_FILE' 不存在。"
    exit 1
fi

# 从输入文件名中提取基本名称（去除.txt后缀）
BASENAME=$(basename "$INPUT_FILE" .txt)

# 构建输出文件名
OUTPUT_FILE="${BASENAME}_hg37.txt"

# 定义R脚本的名称
R_SCRIPT="38to37.R"

# 检查R脚本是否存在
if [ ! -f "$R_SCRIPT" ]; then
    echo "错误: R脚本 '$R_SCRIPT' 未在当前目录找到。"
    exit 1
fi


echo "==> 开始处理..."
echo "    输入文件: $INPUT_FILE"
echo "    输出文件: $OUTPUT_FILE"

# 使用 Rscript 命令执行R脚本，并传递输入和输出文件名作为参数
Rscript "$R_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE"

# 检查R脚本是否成功执行
if [ "$?" -eq 0 ]; then
    echo "==> 成功生成文件: $OUTPUT_FILE"
else
    echo "==> R脚本执行失败。"
fi
