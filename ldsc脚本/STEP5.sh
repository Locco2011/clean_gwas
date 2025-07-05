#!/bin/bash

echo "--- 开始批量LDSC h2遗传力分析 ---"

# --- 第一部分：定义固定路径和参数 ---
# !!! 请根据您的实际情况修改下面三个路径 !!!
LDSC_PY_PATH="/home/cgl/ldsc/ldsc.py"                             # ldsc.py 脚本的绝对或相对路径
REF_LD_PATH="/home/cgl/ldsc/eur_w_ld_chr/"                       # LD参考文件和权重文件所在目录
INPUT_DIR="/home/cgl/ldsc/format_ldsc"                           # 输入文件目录
MAIN_OUTPUT_DIR="/home/cgl/ldsc/h2"                              # 总输出目录

# 检查关键文件/目录是否存在
if [ ! -f "$LDSC_PY_PATH" ]; then
    echo "错误: LDSC Python脚本未找到, 请检查路径: $LDSC_PY_PATH"
    exit 1
fi
if [ ! -d "$REF_LD_PATH" ]; then
    echo "错误: LD参考目录未找到, 请检查路径: $REF_LD_PATH"
    exit 1
fi
if [ ! -d "$INPUT_DIR" ]; then
    echo "错误: 输入目录未找到: $INPUT_DIR"
    exit 1
fi

# --- 第二部分：准备工作 ---
# 1. 创建总输出目录 (如果不存在)
echo "创建总输出目录: $MAIN_OUTPUT_DIR"
mkdir -p "$MAIN_OUTPUT_DIR"

# 2. 计算使用的核心数 (总核心数的一半，至少为1)
TOTAL_CORES=$(nproc)
MAX_JOBS=$((TOTAL_CORES / 2))
if [ "$MAX_JOBS" -lt 1 ]; then
    MAX_JOBS=1
fi
echo "系统总核心数: $TOTAL_CORES, 将使用 $MAX_JOBS 个核心并行运行。"

# 3. 定义日志文件用于断点续传
LOG_FILE="$MAIN_OUTPUT_DIR/parallel_h2_jobs.log"
echo "任务日志将记录在: $LOG_FILE"


# --- 第三部分：定义核心分析函数 ---
# 将分析逻辑封装在一个函数中，使其更清晰，并能被 GNU Parallel 调用
run_ldsc_h2() {
    # 接收从 parallel 传来的输入文件完整路径
    local infile="$1"

    # 从输入文件路径中提取基础名 (例如, 从'./format_ldsc/COPD.sumstats.gz' 得到 'COPD')
    local base_name
    base_name=$(basename "$infile" .sumstats.gz)

    # 根据基础名创建独立的输出子目录
    local output_subdir="${MAIN_OUTPUT_DIR}/${base_name}"
    mkdir -p "$output_subdir"

    # 构建最终的输出文件前缀
    local out_prefix="${output_subdir}/${base_name}"

    # 执行LDSC命令
    python "$LDSC_PY_PATH" \
        --h2 "$infile" \
        --ref-ld-chr "$REF_LD_PATH" \
        --w-ld-chr "$REF_LD_PATH" \
        --out "$out_prefix"
}

# 将函数导出，以便 parallel 子进程可以访问到它
export -f run_ldsc_h2
# 将变量导出，以便函数内可以访问到它们
export LDSC_PY_PATH REF_LD_PATH MAIN_OUTPUT_DIR

# --- 第四部分：使用 GNU Parallel 执行 ---
#
# *** THIS IS THE CORRECTED SECTION ***
# The entire parallel command is now on a single line to avoid syntax errors.
#
find "$INPUT_DIR" -name "*.sumstats.gz" | parallel --jobs $MAX_JOBS --bar --resume --joblog "$LOG_FILE" run_ldsc_h2 {}

echo "--- 所有 h2 分析任务处理完成 ---"
