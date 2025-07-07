# ==============================================================================
# 脚本: GWAS数据处理、坐标转换及清理流程 (v2 - 自动命名输出)
# 功能:
# 1. 读取GWAS汇总统计数据。
# 2. 自动将常见的列名标准化 (例如 chr -> CHR, pval -> P)。
# 3. 将基因组坐标从 hg38 (GRCh38) 转换为 hg19 (GRCh37)。
# 4. 移除MHC区域 (chr6:28,477,797-33,448,354 on hg19) 的数据。
# 5. 清理关键列中包含空值(NA)的行。
# 6. 将处理完成的数据写入自动生成的新文件名中 (例如 input.tsv -> input_hg19.txt)。
#
# 如何运行:
# Rscript process_gwas_auto_name.R <input_file.tsv>
# ==============================================================================

# 1. 加载必要的库
# ------------------------------------------------------------------------------
# 在脚本开头加上这句，如果用户没有安装会自动提示安装
if (!requireNamespace("MungeSumstats", quietly = TRUE)) {
  message("MungeSumstats not found, installing...")
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
  }
  BiocManager::install("MungeSumstats")
}
if (!requireNamespace("data.table", quietly = TRUE)) {
  message("data.table not found, installing...")
  install.packages("data.table")
}
if (!requireNamespace("tools", quietly = TRUE)) {
  # 'tools' 包用于处理文件名，通常是R自带的，但以防万一
  install.packages("tools")
}

library(MungeSumstats)
library(data.table)
library(tools)

# 2. 从命令行获取参数并生成输出文件名
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

# 检查参数数量是否正确 (现在只需要一个参数)
if (length(args) != 1) {
  stop("用法错误! 请只提供一个输入文件参数: Rscript process_gwas_auto_name.R <input_file>", call. = FALSE)
}

# 分配输入文件名
input_file <- args[1]

# 自动生成输出文件名 (例如: /path/to/data.tsv -> data_hg19.txt)
base_name <- file_path_sans_ext(basename(input_file))
output_file <- paste0(base_name, "_hg19.txt")


cat("------------------------------------\n")
cat("初始化流程...\n")
cat("  - 输入文件:", input_file, "\n")
cat("  - 自动生成输出文件:", output_file, "\n")
cat("------------------------------------\n")

# 3. 读取并预处理GWAS汇总数据
# ------------------------------------------------------------------------------
cat("步骤 1: 读取文件...\n")
# 使用 tryCatch 来处理文件不存在或格式错误的情况
sumstats_dt <- tryCatch({
  fread(input_file, header = TRUE)
}, error = function(e) {
  stop(paste("无法读取或处理输入文件:", e$message))
})
cat("  - 读取成功! 文件包含", nrow(sumstats_dt), "行。\n")


# 4. 统一列名
# ------------------------------------------------------------------------------
cat("步骤 2: 标准化列名...\n")
# 定义列名映射规则：常见名 -> 标准名
col_map <- c(
  chr = "CHR",
  pos = "BP",
  snp = "SNP",
  effect_allele = "A1",
  other_allele = "A2",
  samplesize = "N",
  beta = "BETA",
  se = "SE",
  pval = "P",
  eaf = "FRQ"
)

# 获取当前文件已有的列名
current_names <- names(sumstats_dt)

# 遍历映射规则，如果旧列名存在，则将其重命名为标准列名
for (old_name in names(col_map)) {
  if (old_name %in% current_names) {
    setnames(sumstats_dt, old_name, col_map[[old_name]])
    cat("  - '", old_name, "' 已重命名为 '", col_map[[old_name]], "'\n", sep="")
  }
}
cat("  - 列名标准化完成。\n")


# 5. 执行坐标转换 (liftover)
# ------------------------------------------------------------------------------
cat("步骤 3: 开始坐标转换 (hg38 -> hg19/hg37)...\n")
# 假设输入文件是 hg38，目标是 hg19 (等同于 hg37)
sumstats_dt_hg37 <- MungeSumstats::liftover(
  sumstats_dt = sumstats_dt,
  ref_genome = "hg38",
  convert_ref_genome = "hg19"
)
cat("  - 坐标转换完成! 剩余", nrow(sumstats_dt_hg37), "行 (部分位点可能无法转换而被移除)。\n")


# 6. 移除MHC区域
# ------------------------------------------------------------------------------
cat("步骤 4: 移除MHC区域 (chr6:28,477,797-33,448,354)...\n")
# 确保CHR列是数值类型以便比较
sumstats_dt_hg37[, CHR := as.numeric(as.character(CHR))]

# 过滤掉MHC区域
mhc_filtered_dt <- sumstats_dt_hg37[!(CHR == 6 & BP >= 28477797 & BP <= 33448354)]
cat("  - MHC区域过滤完成! 剩余", nrow(mhc_filtered_dt), "行。\n")


# 7. 清理空值 (NA)
# ------------------------------------------------------------------------------
cat("步骤 5: 扫描并删除包含空值的行...\n")
# 定义需要检查的强制性列
required_cols <- c("SNP", "CHR", "BP", "A1", "A2", "BETA", "SE", "FRQ", "N")

# 获取数据中实际存在的、需要检查的列
cols_to_check <- intersect(required_cols, names(mhc_filtered_dt))
cat("  - 将在以下列中检查空值:", paste(cols_to_check, collapse=", "), "\n")

# 使用 data.table 的 na.omit 高效删除在指定列中有NA的行
cleaned_dt <- na.omit(mhc_filtered_dt, cols = cols_to_check)
cat("  - 空值清理完成! 最终剩余", nrow(cleaned_dt), "行。\n")


# 8. 写出转换后的文件
# ------------------------------------------------------------------------------
cat("步骤 6: 写入最终文件...\n")
fwrite(cleaned_dt, file = output_file, sep = "\t", col.names = TRUE, na = "NA")

cat("------------------------------------\n")
cat("操作全部完成!\n")
cat("最终处理后的文件已保存至:", output_file, "\n")
cat("------------------------------------\n")
