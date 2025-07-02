#!/bin/bash

echo "### 开始执行GWAS汇总数据标准化流程 ###"

# --- 固定文件路径 (请根据您的环境修改) ---
MUNGE_PY="/home/cgl/ldsc/munge_sumstats.py"
SNP_LIST="/home/cgl/ldsc/eur_w_ld_chr/w_hm3.snplist"

# --- 数据和输出目录 ---
DATA_DIR="./data"
OUTPUT_DIR="./format"

# --- 准备工作 ---
# 下面的 mkdir -p 命令会检查并自动创建输出目录
echo "--> 1. 正在创建输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
echo "目录准备完成。"
echo

echo "--> 2. 开始并行处理任务，使用一半CPU核心并显示进度条..."
echo "-----------------------------------------------------------------"

# --- 核心并行处理命令 ---
find "$DATA_DIR" -maxdepth 1 -type f -name "*.txt" | parallel \
    --bar \
    --halt now,fail=1 \
    -j 50% \
    "python3 ${MUNGE_PY} \
        --sumstats {} \
        --N-col N \
        --out ${OUTPUT_DIR}/{/.} \
        --merge-alleles ${SNP_LIST}"

# --- 结果检查 ---
if [ $? -eq 0 ]; then
    echo "-----------------------------------------------------------------"
    echo "### 所有任务成功完成！ ###"
    echo "处理后的文件已保存至: $OUTPUT_DIR"
else
    echo "-----------------------------------------------------------------"
    echo "### 任务执行失败！ ###"
    echo "请检查上方 parallel 的错误日志以确定问题。"
fi
