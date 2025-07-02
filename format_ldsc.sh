#!/bin/bash

echo "### 开始执行GWAS汇总数据标准化流程###"

# --- 固定文件路径 (请根据您的环境修改) ---
MUNGE_PY="/home/cgl/ldsc/munge_sumstats.py"
SNP_LIST="/home/cgl/ldsc/eur_w_ld_chr/w_hm3.snplist"

# --- 数据和输出目录 ---
DATA_DIR="./data"
OUTPUT_DIR="./format"

# --- 准备工作 ---
# 检查并自动创建输出目录
echo "--> 1. 正在创建输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
echo "目录准备完成。"
echo

echo "--> 2. 开始逐个处理文件，将自动跳过已完成的任务..."
echo "-----------------------------------------------------------------"

# 使用 find 和 for 循环来逐个处理文件
# find 命令找到所有目标文件
# for 循环遍历每一个找到的文件
for INPUT_FILE in $(find "$DATA_DIR" -maxdepth 1 -type f -name "*.txt"); do

    # --- 断点续传的核心逻辑 ---
    # 1. 获取不带路径和后缀的文件名 (例如: 从 ./data/COPD.txt 得到 COPD)
    BASENAME=$(basename "$INPUT_FILE" .txt)

    # 2. 构建预期的输出文件名
    EXPECTED_OUTPUT="${OUTPUT_DIR}/${BASENAME}.sumstats.gz"

    # 3. 检查输出文件是否已经存在
    if [ -f "$EXPECTED_OUTPUT" ]; then
        # 如果文件存在，打印跳过信息，并继续下一次循环
        echo "已跳过: $BASENAME (输出文件已存在)"
        continue
    fi

    # --- 如果文件未被处理，则执行标准化 ---
    echo "正在处理: $BASENAME ..."

    python3 "${MUNGE_PY}" \
        --sumstats "$INPUT_FILE" \
        --N-col N \
        --out "${OUTPUT_DIR}/${BASENAME}" \
        --merge-alleles "${SNP_LIST}"

    # 检查上一个命令是否成功，如果不成功则中止脚本
    if [ $? -ne 0 ]; then
        echo "-----------------------------------------------------------------"
        echo "### 错误：处理文件 $BASENAME 失败！脚本已中止。 ###"
        echo "请检查上方 munge_sumstats.py 的错误日志。"
        exit 1 # 退出脚本，并返回一个错误码
    fi

done

echo "-----------------------------------------------------------------"
echo "### 所有任务成功完成！ ###"
echo "处理后的文件已保存至: $OUTPUT_DIR"
