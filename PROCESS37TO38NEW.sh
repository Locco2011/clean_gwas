#!/bin/bash

# =================================================================================
# Bash 脚本: 批量运行GWAS数据处理R脚本
#
# 功能:
#   - 遍历指定输入目录中的所有 .txt 文件。
#   - 为每个文件调用 process_gwas_auto_name.R 脚本进行处理。
#   - 将所有生成的结果文件移动到一个固定的输出目录中。
#
# 如何使用:
#   1. 将此脚本与 process_gwas_auto_name.R 放在同一个目录下。
#   2. 赋予此脚本执行权限: chmod +x batch_process.sh
#   3. 运行脚本，并提供包含源文件的文件夹路径作为参数:
#      ./batch_process.sh /path/to/your/source_files
# =================================================================================

# --- 配置区 ---

# 设置固定的输出目录 (请根据您的实际情况修改 "xxx/xx/xx/" 部分)
# 例如: OUTPUT_DIR="/home/user/my_project/processed_data"
OUTPUT_DIR="xxx/xx/xx/Process"

# R脚本的路径 (假设它与本bash脚本在同一个文件夹)
# SCRIPT_DIR 获取当前脚本所在的目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
R_SCRIPT_PATH="${SCRIPT_DIR}/process_gwas_auto_name.R"


# --- 脚本主体 ---

# 检查是否提供了输入目录参数
if [ "$#" -ne 1 ]; then
    echo "用法错误!"
    echo "请提供一个源文件目录作为参数: $0 <source_directory>"
    exit 1
fi

SOURCE_DIR="$1"

# 检查R脚本是否存在
if [ ! -f "$R_SCRIPT_PATH" ]; then
    echo "错误: R脚本未找到! 请确保 '$R_SCRIPT_PATH' 存在。"
    exit 1
fi

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录 '$SOURCE_DIR' 不存在。"
    exit 1
fi

# 检查并创建输出目录
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "输出目录 '$OUTPUT_DIR' 不存在，正在创建..."
    mkdir -p "$OUTPUT_DIR"
    echo "目录创建成功。"
fi

echo "--------------------------------------------------"
echo "开始批量处理..."
echo "源文件目录: $SOURCE_DIR"
echo "结果输出目录: $OUTPUT_DIR"
echo "使用的R脚本: $R_SCRIPT_PATH"
echo "--------------------------------------------------"

# 查找并遍历源目录中所有的 .txt 文件
# 使用 find 命令可以更好地处理包含特殊字符的文件名
find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.txt" | while read -r input_file; do

    echo "▶ 正在处理文件: $(basename "$input_file")"

    # 执行R脚本
    # R脚本会在当前工作目录下生成结果文件
    Rscript "$R_SCRIPT_PATH" "$input_file"

    # 根据R脚本的逻辑，推断出生成的结果文件名
    # 例如: /path/to/file.txt -> file_hg19.txt
    base_name=$(basename "$input_file" .txt)
    generated_output_file="${base_name}_hg19.txt"

    # 检查结果文件是否成功生成
    if [ -f "$generated_output_file" ]; then
        # 如果成功，将其移动到输出目录
        mv "$generated_output_file" "$OUTPUT_DIR/"
        echo "✔ 处理成功! 结果已保存至: $OUTPUT_DIR/$(basename "$generated_output_file")"
    else
        echo "❌ 错误: R脚本执行后未找到预期的输出文件 '$generated_output_file'。"
        echo "   请检查R脚本的输出或可能的错误信息。"
    fi
    echo "--------------------------------------------------"

done

echo "🎉 全部处理完成!"
