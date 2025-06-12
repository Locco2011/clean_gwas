#!/bin/bash

# 37to38cycle.sh
# 用法 1: ./37to38cycle.sh [目标文件夹路径]
#   - 处理指定文件夹内的所有 .txt 文件。
#   - 结果将保存在 [目标文件夹路径]/h37toh38/ 中。
#
# 用法 2: ./37to38cycle.sh
#   - 不提供路径时，默认处理当前脚本所在文件夹内的 .txt 文件。
#   - 结果将保存在 ./h37toh38/ 中。

# --- 配置 ---
# 定义要调用的R脚本名称
R_SCRIPT="37to38.R"
# 定义存放结果的输出目录名称
OUTPUT_DIR_NAME="h37toh38"

# --- 脚本开始 ---

# 1. 检查R脚本是否存在于当前目录
if [ ! -f "$R_SCRIPT" ]; then
    echo "错误: R脚本 '$R_SCRIPT' 未在当前目录找到。"
    echo "请确保 37to38cycle.sh 和 $R_SCRIPT 在同一个目录下。"
    exit 1
fi

# 2. 判断并设置要处理的目标文件夹
if [ "$#" -eq 1 ]; then
    # 如果用户提供了一个参数，则将其作为目标文件夹
    PROCESS_DIR="$1"
    echo "==> 已指定目标文件夹: $PROCESS_DIR"
else
    # 如果没有提供参数，则使用当前目录
    PROCESS_DIR="."
    echo "==> 未指定文件夹，将处理当前目录"
fi

# 3. 验证目标文件夹是否存在且有效
if [ ! -d "$PROCESS_DIR" ]; then
    echo "错误: 目标文件夹 '$PROCESS_DIR' 不存在或不是一个有效的目录。"
    exit 1
fi

# 4. 在目标文件夹内创建输出目录
OUTPUT_DIR_PATH="${PROCESS_DIR}/${OUTPUT_DIR_NAME}"
echo "==> 准备输出目录: $OUTPUT_DIR_PATH"
mkdir -p "$OUTPUT_DIR_PATH"
echo "------------------------------------"

# 标记是否找到文件
found_files=0

# 5. 查找并循环处理目标文件夹中的所有.txt文件
for INPUT_FILE in "${PROCESS_DIR}"/*.txt; do
    # 检查是否有匹配的.txt文件
    if [ ! -f "$INPUT_FILE" ]; then
        continue # 如果没有匹配项，跳过本次循环
    fi

    found_files=1 # 标记已找到文件
    echo "==> 正在处理文件: $INPUT_FILE"

    # 从输入文件路径中提取基本名称（去除.txt后缀）
    BASENAME=$(basename "$INPUT_FILE" .txt)

    # 构建输出文件的完整路径
    OUTPUT_FILE_PATH="${OUTPUT_DIR_PATH}/${BASENAME}_hg38.txt"

    echo "    输入: $INPUT_FILE"
    echo "    输出: $OUTPUT_FILE_PATH"

    # 使用 Rscript 命令执行R脚本
    Rscript "$R_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE_PATH"

    # 检查R脚本是否成功执行
    if [ "$?" -eq 0 ]; then
        echo "==> 成功生成文件: $OUTPUT_FILE_PATH"
    else
        echo "==> R脚本执行失败: $INPUT_FILE"
    fi
    echo "------------------------------------"
done

# 6. 根据是否找到文件给出最终提示
if [ "$found_files" -eq 0 ]; then
    echo "在目录 '$PROCESS_DIR' 中未找到任何 .txt 文件。"
fi

echo "所有任务已完成！"