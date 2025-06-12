# 38to37.R

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
# args[1] จะเป็นไฟล์อินพุต, args[2] จะเป็นไฟล์เอาต์พุต
args <- commandArgs(trailingOnly = TRUE)

# 检查参数数量是否正确
if (length(args) != 2) {
  stop("请提供两个参数: Rscript liftover_script.R <input_file> <output_file>", call. = FALSE)
}

# 3. 分配输入和输出文件名
input_file <- args[1]
output_file <- args[2]

cat("------------------------------------\n")
cat("读取文件:", input_file, "\n")

# 4. 读取GWAS汇总数据
# 使用 tryCatch 来处理文件不存在或格式错误的情况
sumstats_dt <- tryCatch({
  fread(input_file, header = TRUE)
}, error = function(e) {
  stop(paste("无法读取或处理输入文件:", e$message))
})

cat("开始坐标转换 (hg38 -> hg19/hg37)...\n")

# 5. 执行坐标转换 (liftover)
# 假设输入文件是 hg38，目标是 hg19 (等同于 hg37)
# 注意：如果您的原始数据不是hg38，请修改 ref_genome 参数
sumstats_dt_hg37 <- MungeSumstats::liftover(
  sumstats_dt = sumstats_dt,
  ref_genome = "hg38",
  convert_ref_genome = "hg19"
)

cat("写入文件:", output_file, "\n")

# 6. 写出转换后的文件
fwrite(sumstats_dt_hg37, file = output_file, sep = "\t", col.names = TRUE)

cat("操作完成!\n")
cat("------------------------------------\n")
