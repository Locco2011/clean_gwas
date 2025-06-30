#!/bin/bash
set -euo pipefail

if (( $# < 2 )) || (( $# % 2 != 0 )); then
    echo "使用方法: ./ss.sh <vcf文件1.vcf.gz> <N样本数1> [<vcf文件2.vcf.gz> <N样本数2> ...]"
    echo "示例: ./ss.sh ukb-b-13447.vcf.gz 462933 another.vcf.gz 500000"
    exit 1
fi

while (( "$#" )); do
    VCF_FILE="$1"
    N_SAMPLE="$2"

    if [ ! -f "$VCF_FILE" ]; then
        echo "错误: 文件 '${VCF_FILE}' 不存在。跳过此文件。"
        shift 2
        continue
    fi

    OUTPUT_BASENAME=$(basename "$VCF_FILE" .vcf.gz)
    OUTPUT_FILE="${OUTPUT_BASENAME}.txt"

    echo "正在处理: ${VCF_FILE}，样本数: ${N_SAMPLE}，输出文件: ${OUTPUT_FILE}"

    R_SCRIPT_CONTENT=$(cat <<EOF
suppressPackageStartupMessages({
  library(VariantAnnotation)
  library(MungeSumstats)
  library(data.table)
})

path <- "${VCF_FILE}"
N_sample <- ${N_SAMPLE}

vcf <- VariantAnnotation::readVcf(file = path)

vcf_df <- MungeSumstats:::vcf2df(vcf = vcf,
                                 add_sample_names = TRUE,
                                 add_rowranges = TRUE,
                                 drop_empty_cols = TRUE,
                                 unique_cols = TRUE,
                                 unique_rows = TRUE,
                                 unlist_cols = TRUE,
                                 sampled_rows = TRUE,
                                 verbose = TRUE)

vcf_df\$P <- 10^(-vcf_df\$"LP_${OUTPUT_BASENAME}")

data <- data.frame(CHR = vcf_df\$chr,
                   SNP = vcf_df\$ID,
                   BP = vcf_df\$start,
                   A1 = vcf_df\$ALT,
                   A2 = vcf_df\$REF,
                   P = vcf_df\$P,
                   BETA = vcf_df\$"ES_${OUTPUT_BASENAME}",
                   SE = vcf_df\$"SE_${OUTPUT_BASENAME}",
                   FRQ = vcf_df\$"AF_${OUTPUT_BASENAME}",
                   N = N_sample)

data.table::fwrite(data,
                   file = "${OUTPUT_FILE}",
                   sep = "\t",
                   quote = FALSE,
                   row.names = FALSE,
                   col.names = TRUE)
EOF
)

    echo "$R_SCRIPT_CONTENT" | R --slave --no-save --no-restore

    echo "完成 ${VCF_FILE} 的转换。输出文件: ${OUTPUT_FILE}"
    echo "---"

    shift 2
done

echo "所有文件处理完毕。"
