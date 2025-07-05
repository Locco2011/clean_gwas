#!/bin/bash

echo "--- 开始批量LDSC rg遗传相关性分析  ---"

# --- 第一部分：定义固定路径和参数 ---
# !!! 请根据您的实际情况修改下面三个路径 !!!
LDSC_PY_PATH="/path/to/your/ldsc/ldsc.py"             # ldsc.py 脚本的绝对或相对路径
REF_LD_PATH="/path/to/your/ldsc/eur_w_ld_chr/"      # LD参考文件和权重文件所在目录
INPUT_DIR="./format_ldsc"                           # 输入文件目录
MAIN_OUTPUT_DIR="./rg"                              # 总输出目录

# --- 检查与准备 ---
if [ ! -f "$LDSC_PY_PATH" ]; then echo "错误: LDSC Python脚本未找到: $LDSC_PY_PATH"; exit 1; fi
if [ ! -d "$REF_LD_PATH" ]; then echo "错误: LD参考目录未找到: $REF_LD_PATH"; exit 1; fi
if [ ! -d "$INPUT_DIR" ]; then echo "错误: 输入目录未找到: $INPUT_DIR"; exit 1; fi

echo "创建总输出目录: $MAIN_OUTPUT_DIR"
mkdir -p "$MAIN_OUTPUT_DIR"

# 计算使用的核心数
TOTAL_CORES=$(nproc)
MAX_JOBS=$((TOTAL_CORES / 2))
[ "$MAX_JOBS" -lt 1 ] && MAX_JOBS=1
echo "系统总核心数: $TOTAL_CORES, 将使用 $MAX_JOBS 个核心并行运行。"

# 定义日志文件用于断点续传
LOG_FILE="$MAIN_OUTPUT_DIR/parallel_rg_all_pairs_jobs.log"
echo "任务日志将记录在: $LOG_FILE"

# --- 第二部分：定义核心分析函数 ---
# 此函数接收两个文件作为输入，并执行rg分析
run_ldsc_rg_ordered() {
    local file1="$1"
    local file2="$2"

    # 从完整路径中提取基础名
    local base1
    local base2
    base1=$(basename "$file1" .sumstats.gz)
    base2=$(basename "$file2" .sumstats.gz)

    # *** CHANGED LOGIC ***
    # 直接按接收到的顺序组合文件名，不再进行字母排序
    local out_name="${base1}_${base2}"

    # 创建独立的输出子目录
    local output_subdir="${MAIN_OUTPUT_DIR}/${out_name}"
    mkdir -p "$output_subdir"

    # 构建最终的输出文件前缀
    local out_prefix="${output_subdir}/${out_name}"

    # 执行LDSC命令
    python "$LDSC_PY_PATH" \
        --rg "${file1},${file2}" \
        --ref-ld-chr "$REF_LD_PATH" \
        --w-ld-chr "$REF_LD_PATH" \
        --out "$out_prefix"
}

# 将函数和变量导出，以便 parallel 子进程可以访问
export -f run_ldsc_rg_ordered
export LDSC_PY_PATH REF_LD_PATH MAIN_OUTPUT_DIR

# --- 第三部分：生成任务对并使用 GNU Parallel 执行 ---

# 将所有输入文件读入一个数组
shopt -s nullglob
files=("$INPUT_DIR"/*.sumstats.gz)
shopt -u nullglob

num_files=${#files[@]}
if [ "$num_files" -lt 1 ]; then
    echo "在 $INPUT_DIR 中没有找到 .sumstats.gz 文件！"
    exit 1
fi
# *** CHANGED LOGIC ***
# 计算 N * N 个任务
echo "找到了 $num_files 个文件，将生成 $((num_files * num_files)) 个分析任务。"

# *** CHANGED LOGIC ***
# 两个循环都从0开始，以生成所有 N*N 的组合
{
    for (( i=0; i<num_files; i++ )); do
        for (( j=0; j<num_files; j++ )); do
            # 输出两个文件名，用制表符分隔
            printf "%s\t%s\n" "${files[i]}" "${files[j]}"
        done
    done
} | parallel --colsep '\t' --jobs $MAX_JOBS --bar --resume --joblog "$LOG_FILE" run_ldsc_rg_ordered {1} {2}


echo "--- 所有 rg 分析任务处理完成 ---"
