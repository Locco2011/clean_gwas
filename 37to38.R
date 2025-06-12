# 37to38.R

# 1. 加载必要的库
# 在脚本开头加上这句，如果用户没有安装会自动提示安装
if (!requireNamespace("MungeSumstats", quietly = TRUE)) {
  message("MungeSumstats not found, installing...")
  BiocManager::install("MungeSumstats")
}
if (!requireNamespace("data.table", quietly = TRUE)) {
  message("data.table not found, installing...")
  install.packages("data.table")
}

library(MungeSumstats)
library(data.table)

# 2. 从命令行获取参数
args <- commandArgs(trailingOnly = TRUE)

# 检查参数数量是否正确
if (length(args) != 2) {
  stop("请提供两个参数: Rscript liftover_hg19_to_hg38.R <input_file> <output_file>", call. = FALSE)
}

# 3. 分配输入和输出文件名
input_file <- args[1]
output_file <- args[2]

cat("------------------------------------\n")
cat("读取文件:", input_file, "\n")

# 4. 读取GWAS汇总数据
sumstats_dt <- tryCatch({
  fread(input_file, header = TRUE)
}, error = function(e) {
  stop(paste("无法读取或处理输入文件:", e$message))
})

cat("开始坐标转换 (hg19/hg37 -> hg38)...\n")

# 5. 执行坐标转换 (liftover)
# 关键修改：指定输入为 hg19，输出为 hg38
# 同时使用更清晰的变量名 sumstats_dt_hg38
sumstats_dt_hg38 <- MungeSumstats::liftover(
  sumstats_dt = sumstats_dt,
  ref_genome = "hg19",
  convert_ref_genome = "hg38"
)

cat("写入文件:", output_file, "\n")

# 6. 写出转换后的文件
fwrite(sumstats_dt_hg38, file = output_file, sep = "\t", col.names = TRUE)

cat("操作完成!\n")
cat("------------------------------------\n")