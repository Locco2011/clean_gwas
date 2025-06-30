setwd("/home/cgl/clean_gwas/")
path = "/home/cgl/clean_gwas/ukb-b-13447.vcf.gz"
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

vcf_df$P <- 10^(-vcf_df$`LP_UKB-b-13447`)
vcf_df$N<- 462933

data<- data.frame(CHR = vcf_df$chr,
                  SNP = vcf_df$ID,
                  BP = vcf_df$start,
                  A1 = vcf_df$ALT,
                  A2 = vcf_df$REF,
                  P = vcf_df$P,
                  BETA = vcf_df$`ES_UKB-b-13447`,
                  SE = vcf_df$`SE_UKB-b-13447`,
                  FRQ = vcf_df$`AF_UKB-b-13447`,
                  N = vcf_df$N)


data.table::fwrite(data,
       file = "ukb-b-13447.txt",
       sep = "\t",
       quote = FALSE,
       row.names = FALSE,
       col.names = TRUE)
