#!/bin/bash

echo "--- 开始批量格式化GWAS数据 ---"

PY_SCRIPT_PATH="/path/to/your/ldsc/munge_sumstats.py"
SNP_LIST_PATH="/path/to/your/ldsc/eur_w_ld_chr/w_hm3.snplist"
RAW_DATA_DIR="./raw"
OUTPUT_DIR="./format_ldsc"

if [ ! -f "$PY_SCRIPT_PATH" ]; then
    echo "错误: Python脚本未找到, 请检查路径: $PY_SCRIPT_PATH"
    exit 1
fi

if [ ! -f "$SNP_LIST_PATH" ]; then
    echo "错误: SNP列表文件未找到, 请检查路径: $SNP_LIST_PATH"
    exit 1
fi

echo "创建输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

TOTAL_CORES=$(nproc)
MAX_JOBS=$((TOTAL_CORES / 2))
if [ "$MAX_JOBS" -lt 1 ]; then
    MAX_JOBS=1
fi

echo "系统总核心数: $TOTAL_CORES"
echo "将使用 $MAX_JOBS 个核心并行运行..."

LOG_FILE="$OUTPUT_DIR/parallel_jobs.log"
echo "任务日志将记录在: $LOG_FILE"

find "$RAW_DATA_DIR" -name "*.txt" | parallel --jobs $MAX_JOBS --bar --resume --joblog "$LOG_FILE" \
    "python $PY_SCRIPT_PATH --sumstats {} --N-col N --merge-alleles $SNP_LIST_PATH --out $OUTPUT_DIR/{/.}"

echo "--- 所有任务处理完成 ---"
