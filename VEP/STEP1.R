# 处理常规GWAS为vcf格式

library(data.table)

# 读取 GWAS 文件
gwas <- fread("./clean_gwas/data/J10_COPD.txt", sep = "\t", header = TRUE)

# 如果 SNP 列缺失或为 ".", 用 "." 占位
gwas[is.na(SNP) | SNP == "", SNP := "."]

# 构建 VCF 数据框
vcf <- data.table(
  CHROM = gwas$CHR,
  POS = gwas$BP,
  ID = gwas$SNP,
  REF = gwas$A1,
  ALT = gwas$A2,
  QUAL = ".",
  FILTER = ".",
  INFO = "."
)

# 写入 VCF 文件
vcf_file <- "./clean_gwas/data/gwas.vcf"

# 打开文件连接
con <- file(vcf_file, open = "wt")

# 写 VCF header
writeLines("##fileformat=VCFv4.2", con)
writeLines(paste(colnames(vcf), collapse = "\t"), con)

# 写 VCF body
write.table(
  vcf,
  file = con,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  col.names = FALSE
)

# 关闭连接
close(con)
