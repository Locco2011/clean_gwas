#!/bin/bash

# --- 配置区域 ---
OUTPUT_DIR="xxx/xx/xx/Process"
FIXED_INPUT_DIR="/your/fixed/input/path"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
R_SCRIPT_PATH="${SCRIPT_DIR}/process_gwas_auto_name.R"

# --- 参数处理 ---
if [ "$#" -eq 1 ]; then
    SOURCE_DIR="$1"
else
    SOURCE_DIR="$FIXED_INPUT_DIR"
fi

# --- 环境检查 ---
if [ ! -f "$R_SCRIPT_PATH" ]; then
    echo "错误: R脚本未找到! 请确保 '$R_SCRIPT_PATH' 存在。"
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录 '$SOURCE_DIR' 不存在。"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "输出目录 '$OUTPUT_DIR' 不存在，正在创建..."
    mkdir -p "$OUTPUT_DIR"
    echo "目录创建成功。"
fi

# --- 开始处理 ---
echo "--------------------------------------------------"
echo "开始批量处理..."
echo "源文件目录: $SOURCE_DIR"
echo "结果输出目录: $OUTPUT_DIR"
echo "使用的R脚本: $R_SCRIPT_PATH"
echo "模式: 已开启断点续传"
echo "--------------------------------------------------"

find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.txt" | while read -r input_file; do

    # ## --- 新增的断点续传逻辑开始 --- ## #
    
    # 1. 根据输入文件名，推断出对应的输出文件名
    base_name=$(basename "$input_file" .txt)
    expected_output_file="$OUTPUT_DIR/${base_name}_hg19.txt"

    # 2. 检查输出文件是否已经存在
    if [ -f "$expected_output_file" ]; then
        echo "⏩ 已找到结果文件，跳过: $(basename "$input_file")"
        echo "--------------------------------------------------"
        continue # 跳过当前循环，处理下一个文件
    fi

    # ## --- 新增的断点续传逻辑结束 --- ## #


    # --- 原有的处理逻辑 ---
    echo "▶ 正在处理文件: $(basename "$input_file")"

    # 执行R脚本 (注意：R脚本可能会在当前目录生成输出文件)
    Rscript "$R_SCRIPT_PATH" "$input_file"

    # 检查R脚本是否在当前目录成功生成了预期的文件
    # R脚本的输出文件名需要与这里的命名规则一致
    generated_output_file_in_cwd="${base_name}_hg19.txt"

    if [ -f "$generated_output_file_in_cwd" ]; then
        # 将生成的输出文件移动到最终的输出目录
        mv "$generated_output_file_in_cwd" "$OUTPUT_DIR/"
        echo "✔ 处理成功! 结果已保存至: $OUTPUT_DIR/$(basename "$generated_output_file_in_cwd")"
    else
        echo "❌ 错误: R脚本执行后未找到预期的输出文件 '$generated_output_file_in_cwd'。"
        echo "   请检查R脚本的输出或可能的错误信息。"
    fi
    echo "--------------------------------------------------"

done

echo "🎉 全部处理完成!"
