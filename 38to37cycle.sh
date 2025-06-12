#!/bin/bash

# 38to37cycle.sh 
#
# 这是一个集成了处理逻辑的脚本，用于批量处理【指定目录】下的所有 .txt 文件。
#
# 用法:
# ./38to37cycle.sh /path/to/your/data_folder
#
# 它会为每个 .txt 文件调用 R 脚本，并将结果移动到目标文件夹内一个
# 新建的 'h38toh37' 子目录中。

# --- 前置检查和路径设置 ---

# 1. 检查是否提供了目录参数
if [ "$#" -ne 1 ]; then
    echo "错误: 请提供一个文件夹路径作为参数。"
    echo "用法: $0 <要处理的文件夹路径>"
    exit 1
fi

# 2. 将第一个参数分配给目标目录变量
TARGET_DIR="$1"

# 3. 检查提供的路径是否存在并且是一个目录
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误: 目录 '$TARGET_DIR' 不存在或不是一个有效的目录。"
    exit 1
fi

# 4. 健壮地获取本脚本所在的目录，以确保总能找到R脚本
#    这使得无论您从哪里运行此脚本，它都能找到旁边的 38to37.R
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
R_SCRIPT="$SCRIPT_DIR/38to37.R"

# 5. 再次检查核心的R脚本是否存在
if [ ! -f "$R_SCRIPT" ]; then
    echo "错误: 核心R脚本 '$R_SCRIPT' 未找到。"
    echo "请确保 '38to37.R' 与本脚本 ('$(basename "${BASH_SOURCE[0]}")') 存放在同一目录下。"
    exit 1
fi

# --- 准备工作 ---
# 在【目标目录】下创建输出文件夹
OUTPUT_DIR_NAME="h38toh37"
FINAL_OUTPUT_DIR="$TARGET_DIR/$OUTPUT_DIR_NAME"

echo "==> 目标文件夹: $TARGET_DIR"
echo "==> 正在创建结果目录: $FINAL_OUTPUT_DIR"
mkdir -p "$FINAL_OUTPUT_DIR"

# --- 核心逻辑 ---
# 使用 shopt -s nullglob 确保在没有找到任何 .txt 文件时，循环不会执行
shopt -s nullglob
# 查找目标目录下的所有.txt文件
files=("$TARGET_DIR"/*.txt)

# 检查是否在目标目录中找到了任何 .txt 文件
if [ ${#files[@]} -eq 0 ]; then
    echo "==> 未在目录 '$TARGET_DIR' 中找到任何 .txt 文件可供处理。"
    exit 0
fi

echo "==> 找到 ${#files[@]} 个 .txt 文件，现在开始逐一处理..."
echo

# 遍历所有找到的 .txt 文件 (变量'file'现在包含完整路径)
for file in "${files[@]}"; do
    echo "------------------------------------"
    echo "--> 正在处理文件: $file"

    # 从完整路径中提取基本名称（去除.txt后缀）
    BASENAME=$(basename "$file" .txt)

    # 构建输出文件名，R脚本将在目标目录中临时生成此文件
    TEMP_OUTPUT_FILE="$TARGET_DIR/${BASENAME}_hg37.txt"

    echo "    输入文件: $file"
    echo "    目标路径: $FINAL_OUTPUT_DIR/${BASENAME}_hg37.txt"

    # 执行R脚本，所有文件路径都使用完整路径，确保准确性
    Rscript "$R_SCRIPT" "$file" "$TEMP_OUTPUT_FILE"

    # 检查R脚本是否成功执行
    if [ "$?" -eq 0 ]; then
        # R脚本报告成功，现在检查输出文件是否真的存在
        if [ -f "$TEMP_OUTPUT_FILE" ]; then
            echo "--> R脚本执行成功，正在移动结果文件..."
            # 将成功生成的文件移动到最终结果目录
            mv "$TEMP_OUTPUT_FILE" "$FINAL_OUTPUT_DIR/"
            echo "--> 文件已成功保存至: $FINAL_OUTPUT_DIR/"
        else
            echo "--> 警告: R脚本报告成功，但未找到预期的输出文件 '$TEMP_OUTPUT_FILE'。"
        fi
    else
        echo "--> 错误: 处理文件 '$file' 时R脚本执行失败。"
        # 如果R脚本失败，它可能会创建一个空的输出文件，最好清理掉
        rm -f "$TEMP_OUTPUT_FILE"
    fi
    echo
done

# --- 结束 ---
echo "------------------------------------"
echo "==> 所有文件处理完成！"
echo "==> 所有成功生成的结果均已存放在 '$FINAL_OUTPUT_DIR' 目录中。"