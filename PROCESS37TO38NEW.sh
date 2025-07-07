#!/bin/bash

OUTPUT_DIR="xxx/xx/xx/Process"
FIXED_INPUT_DIR="/your/fixed/input/path"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
R_SCRIPT_PATH="${SCRIPT_DIR}/process_gwas_auto_name.R"

if [ "$#" -eq 1 ]; then
    SOURCE_DIR="$1"
else
    SOURCE_DIR="$FIXED_INPUT_DIR"
fi

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

echo "--------------------------------------------------"
echo "开始批量处理..."
echo "源文件目录: $SOURCE_DIR"
echo "结果输出目录: $OUTPUT_DIR"
echo "使用的R脚本: $R_SCRIPT_PATH"
echo "--------------------------------------------------"

find "$SOURCE_DIR" -maxdepth 1 -type f -name "*.txt" | while read -r input_file; do

    echo "▶ 正在处理文件: $(basename "$input_file")"

    Rscript "$R_SCRIPT_PATH" "$input_file"

    base_name=$(basename "$input_file" .txt)
    generated_output_file="${base_name}_hg19.txt"

    if [ -f "$generated_output_file" ]; then
        mv "$generated_output_file" "$OUTPUT_DIR/"
        echo "✔ 处理成功! 结果已保存至: $OUTPUT_DIR/$(basename "$generated_output_file")"
    else
        echo "❌ 错误: R脚本执行后未找到预期的输出文件 '$generated_output_file'。"
        echo "   请检查R脚本的输出或可能的错误信息。"
    fi
    echo "--------------------------------------------------"

done

echo "🎉 全部处理完成!"
