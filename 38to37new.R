# ==============================================================================
# 脚本: GWAS数据处理、坐标转换及清理流程 
# 功能:
# 1. 读取GWAS汇总统计数据。
# 2. 自动将常见的列名标准化 (例如 chr -> CHR, pval -> P)。
# 3. 在坐标转换前，清理所有标准化列中的空值(NA)。
# 4. 将基因组坐标从 hg38 (GRCh38) 转换为 hg19 (GRCh37)。
# 5. 移除MHC区域 (chr6:28,477,797-33,448,354 on hg19) 的数据。
# 6. 将处理完成的数据写入自动生成的新文件名中 (例如 input.tsv -> input_hg19.txt)。
#
# 如何运行:
# Rscript process_gwas_v3.R <input_file.tsv>
# ==============================================================================

# 1. 加载必要的库
# ------------------------------------------------------------------------------
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
  install.packages("tools")
}

library(MungeSumstats)
library(data.table)
library(tools)

# 2. 从命令行获取参数并生成输出文件名
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1) {
  stop("用法错误! 请只提供一个输入文件参数: Rscript process_gwas_v3.R <input_file>", call. = FALSE)
}

input_file <- args[1]
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
sumstats_dt <- tryCatch({
  fread(input_file, header = TRUE)
}, error = function(e) {
  stop(paste("无法读取或处理输入文件:", e$message))
})
cat("  - 读取成功! 文件包含", nrow(sumstats_dt), "行。\n")

# 4. 统一列名
# ------------------------------------------------------------------------------
cat("步骤 2: 标准化列名...\n")
col_map <- c(
  chr = "CHR", pos = "BP", snp = "SNP", effect_allele = "A1",
  other_allele = "A2", samplesize = "N", beta = "BETA", se = "SE",
  pval = "P", eaf = "FRQ"
)

current_names <- names(sumstats_dt)
renamed_cols <- c() # 用于记录哪些列被重命名了

for (old_name in names(col_map)) {
  if (old_name %in% current_names) {
    new_name <- col_map[[old_name]]
    setnames(sumstats_dt, old_name, new_name)
    cat("  - '", old_name, "' 已重命名为 '", new_name, "'\n", sep="")
    renamed_cols <- c(renamed_cols, new_name)
  }
}
cat("  - 列名标准化完成。\n")

# 5. (新步骤) 清理所有已标准化列的空值 (NA)
# ------------------------------------------------------------------------------
cat("步骤 3: 扫描并删除已标准化列中的空值行...\n")
# 只在被重命名的那些列中检查NA
if (length(renamed_cols) > 0) {
  cat("  - 将在以下列中检查空值:", paste(renamed_cols, collapse=", "), "\n")
  
  # 记录清理前的行数
  rows_before_na_clean <- nrow(sumstats_dt)
  
  # 使用 data.table 的 na.omit 高效删除在指定列中有NA的行
  sumstats_dt <- na.omit(sumstats_dt, cols = renamed_cols)
  
  rows_after_na_clean <- nrow(sumstats_dt)
  cat("  - 空值清理完成! 移除了", rows_before_na_clean - rows_after_na_clean, "行，剩余", rows_after_na_clean, "行。\n")
} else {
  cat("  - 未进行任何列名标准化，跳过此步骤的空值清理。\n")
}

# 6. 执行坐标转换 (liftover)
# ------------------------------------------------------------------------------
cat("步骤 4: 开始坐标转换 (hg38 -> hg19/hg37)...\n")
sumstats_dt_hg37 <- MungeSumstats::liftover(
  sumstats_dt = sumstats_dt,
  ref_genome = "hg38",
  convert_ref_genome = "hg19"
)
cat("  - 坐标转换完成! 剩余", nrow(sumstats_dt_hg37), "行 (部分位点可能无法转换而被移除)。\n")

# 7. 移除MHC区域
# ------------------------------------------------------------------------------
cat("步骤 5: 移除MHC区域 (chr6:28,477,797-33,448,354)...\n")
sumstats_dt_hg37[, CHR := as.numeric(as.character(CHR))]
mhc_filtered_dt <- sumstats_dt_hg37[!(CHR == 6 & BP >= 28477797 & BP <= 33448354)]
cat("  - MHC区域过滤完成! 剩余", nrow(mhc_filtered_dt), "行。\n")

# 8. 删除多余的元数据列
# ------------------------------------------------------------------------------
cat("步骤 6: 移除多余的元数据列...\n")
col_to_remove <- "IMPUTATION_gen_build"
if (col_to_remove %in% names(mhc_filtered_dt)) {
  mhc_filtered_dt[, (col_to_remove) := NULL]
  cat("  - '", col_to_remove, "' 列已成功删除。\n", sep="")
} else {
  cat("  - 未找到 '", col_to_remove, "' 列，跳过删除。\n", sep="")
}

# 9. 写出转换后的文件
# ------------------------------------------------------------------------------
cat("步骤 7: 写入最终文件 (不带引号)...\n")
# 注意这里我们使用最后处理完的 mhc_filtered_dt
fwrite(mhc_filtered_dt, file = output_file, sep = "\t", col.names = TRUE, na = "NA", quote = FALSE)

cat("------------------------------------\n")
cat("流程执行完毕!\n")
cat("最终文件已保存至:", output_file, "\n")
cat("------------------------------------\n")
