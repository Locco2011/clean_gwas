#!/bin/bash

echo "--- 开始批量LDSC rg遗传相关性分析 (固定性状 vs 其他) ---"

# --- 第一部分：定义固定路径和参数 ---
# !!! 请根据您的实际情况修改下面四个路径和文件 !!!
FIXED_TRAIT_FILE="/path/to/your/fixed_trait.sumstats.gz" # <-- 【新增】指定您要作为基准的那个固定性状文件
LDSC_PY_PATH="/path/to/your/ldsc/ldsc.py"              # ldsc.py 脚本的绝对或相对路径
REF_LD_PATH="/path/to/your/ldsc/eur_w_ld_chr/"          # LD参考文件和权重文件所在目录
INPUT_DIR="./format_ldsc"                             # 【其他】性状的输入文件目录
MAIN_OUTPUT_DIR="./rg_fixed_vs_others"                # 总输出目录 (建议使用新目录名)

# --- 检查与准备 ---
if [ ! -f "$FIXED_TRAIT_FILE" ]; then echo "错误: 固定性状文件未找到: $FIXED_TRAIT_FILE"; exit 1; fi
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

# 定义日志文件用于断点续传 (使用新日志名以避免混淆)
LOG_FILE="$MAIN_OUTPUT_DIR/parallel_rg_fixed_vs_all_jobs.log"
echo "任务日志将记录在: $LOG_FILE (用于断点续传)"

# --- 第二部分：定义核心分析函数 (此部分无需修改) ---
# 此函数接收两个文件作为输入，并执行rg分析
run_ldsc_rg_ordered() {
    local file1="$1"
    local file2="$2"

    # 从完整路径中提取基础名
    local base1
    local base2
    base1=$(basename "$file1" .sumstats.gz)
    base2=$(basename "$file2" .sumstats.gz)

    # 按接收到的顺序组合文件名
    local out_name="${base1}_vs_${base2}"

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

# --- 第三部分：生成任务对并使用 GNU Parallel 执行 (逻辑已修改) ---

# 将所有【其他】性状文件读入一个数组
shopt -s nullglob
other_files=("$INPUT_DIR"/*.sumstats.gz)
shopt -u nullglob

num_files=${#other_files[@]}
if [ "$num_files" -lt 1 ]; then
    echo "在 $INPUT_DIR 中没有找到 .sumstats.gz 文件！"
    exit 1
fi

echo "找到了 $num_files 个其他性状文件，将与固定性状 $FIXED_TRAIT_FILE 进行配对分析。"

# 生成任务列表：固定性状 vs. 每一个其他性状
# 然后通过管道 | 将任务列表传递给 parallel 命令
{
    for other_file in "${other_files[@]}"; do
        # (可选) 如果固定性状文件本身也在INPUT_DIR中，跳过自己和自己的比较
        if [ "$other_file" == "$FIXED_TRAIT_FILE" ]; then
            echo "跳过与自身的比较: $other_file" >&2 # 将消息输出到标准错误，不影响管道
            continue
        fi
        
        # 输出两个文件名，用制表符分隔。固定性状在前。
        printf "%s\t%s\n" "$FIXED_TRAIT_FILE" "$other_file"
    done
} | parallel \
    --colsep '\t' \
    --jobs $MAX_JOBS \
    --bar \
    --eta \
    --resume \
    --joblog "$LOG_FILE" \
    run_ldsc_rg_ordered {1} {2}


echo "--- 所有 rg 分析任务处理完成 ---"
