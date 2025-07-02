#!/bin/bash

# =================================================================
#            LDSC Munge Sumstats 并行处理脚本
# =================================================================
#
# 功能:
# 1. 在指定数据目录下创建名为 "sumstats" 的输出文件夹。
# 2. 遍历数据目录下的所有 .txt 文件。
# 3. 对每个 .txt 文件并行运行 munge_sumstats.py。
# 4. 使用系统一半的CPU核心执行任务。
# 5. 显示总体任务进度条。
#
#==================================================================

echo "### 开始执行GWAS汇总数据标准化流程 ###"

# --- 第一步: 定义固定路径和变量 ---
# 使用变量使脚本更清晰且易于维护

# 固定文件路径 (根据您的要求第二点)
MUNGE_PY="/home/cgl/ldsc/munge_sumstats.py"
SNP_LIST="/home/cgl/ldsc/eur_w_ld_chr/w_hm3.snplist"

# 数据和输出目录
DATA_DIR="/home/cgl/ldsc/data"
OUTPUT_DIR="$DATA_DIR/sumstats"


# --- 第二步: 创建输出目录 ---
# (根据您的要求第一点)
# 使用 -p 参数，如果目录已存在则不会报错
echo "--> 1. 正在创建输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
echo "目录准备完成。"
echo

# --- 第三步: 查找输入文件并并行处理 ---
# (根据您的要求第三、四、五点)
echo "--> 2. 正在查找 $DATA_DIR 目录下的所有 .txt 文件并开始并行处理..."
echo "-----------------------------------------------------------------"

# 使用 GNU Parallel 执行命令
# -j 50% : 使用一半的CPU核心 (您的要求第五点)
# --bar  : 显示百分比进度条 (您的要求第五点)
# --halt now,fail=1 : 如果有任何一个任务失败，立即停止所有任务
# {}     : 代表 parallel 传入的完整输入路径 (例如: /home/cgl/ldsc/data/COPD.txt)
# {/.}   : 代表输入路径，但移除了路径和后缀 (例如: COPD)

# 查找所有txt文件，并通过管道传给 parallel
find "$DATA_DIR" -maxdepth 1 -type f -name "*.txt" | parallel \
    --bar \
    --halt now,fail=1 \
    -j 50% \
    "python3 ${MUNGE_PY} \
        --sumstats {} \
        --N-col N \
        --out ${OUTPUT_DIR}/{/.} \
        --merge-alleles ${SNP_LIST}"

# 检查 parallel 的退出状态
if [ $? -eq 0 ]; then
    echo "-----------------------------------------------------------------"
    echo "### 所有任务成功完成！ ###"
    echo "处理后的文件已保存至: $OUTPUT_DIR"
else
    echo "-----------------------------------------------------------------"
    echo "### 任务执行失败！ ###"
    echo "请检查上方 parallel 的错误日志以确定问题。"
fi
