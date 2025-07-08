# Title: Batch Process LDSC Log Files (Corrected Version)
# Author: Gemini
# Date: 2025-07-08
# Description: Recursively finds and parses LDSC log files in a directory,
#              extracting key metrics into a single CSV file.

# --- 1. 安装和加载必要的包 ---
# 如果您尚未安装 'tidyverse'，请取消下面的注释并运行它。
# install.packages("tidyverse")

library(tidyverse)
library(stringr)

# --- 2. 用户配置 ---
# ##############################################################################
# ##############################################################################
ROOT_DIRECTORY <- "G:/mvLung/result_ldsc_h2/"  # 您可以保持您已设置的正确路径

# 设置输出文件的名称
OUTPUT_CSV_FILE <- "ldsc_all_h2.csv"


# --- 3. 定义核心处理函数 (已修正) ---

#' @title 解析单个 LDSC 日志文件
#' @description 从文件内容中提取关键的 LDSC 结果。
#' @param file_path 字符串，指向单个日志文件的路径。
#' @return 一个 tibble (数据框)，包含从该文件中提取的所有信息。
parse_ldsc_log <- function(file_path) {
  
  content <- tryCatch({
    read_file(file_path)
  }, error = function(e) {
    message("无法读取文件: ", file_path)
    return("")
  })
  
  extract_match <- function(pattern, text, group_index = 2) {
    match <- str_match(text, pattern)
    if (!is.na(match[1, 1])) {
      return(match[1, group_index])
    } else {
      return(NA_character_)
    }
  }
  
  # --- 已修正的部分 ---
  # 将 extract_match 的参数顺序从 (content, pattern) 改为 (pattern, content)
  out_file <- extract_match("--out\\s+(\\S+)", content)
  h2_file <- extract_match("--h2\\s+(\\S+)", content)
  lambda_gc <- extract_match("Lambda GC:\\s+([\\d\\.\\-eNA]+)", content)
  mean_chi2 <- extract_match("Mean Chi\\^2:\\s+([\\d\\.\\-eNA]+)", content)
  # --- 修正结束 ---
  
  h2_match <- str_match(content, "Total Observed scale h2:\\s+([\\d\\.\\-eNA]+)\\s+\\(([\\d\\.\\-eNA]+)\\)")
  intercept_match <- str_match(content, "Intercept:\\s+([\\d\\.\\-eNA]+)\\s+\\(([\\d\\.\\-eNA]+)\\)")
  ratio_match <- str_match(content, "Ratio:\\s+(.*?)(?:\\s+\\(|$)")
  
  tibble(
    File = basename(file_path),
    Path = file_path,
    Out_File = out_file,
    H2_File = h2_file,
    Total_h2 = if (!is.na(h2_match[1,1])) h2_match[1,2] else NA_character_,
    Total_h2_SE = if (!is.na(h2_match[1,1])) h2_match[1,3] else NA_character_,
    Lambda_GC = lambda_gc,
    Mean_Chi2 = mean_chi2,
    Intercept = if (!is.na(intercept_match[1,1])) intercept_match[1,2] else NA_character_,
    Intercept_SE = if (!is.na(intercept_match[1,1])) intercept_match[1,3] else NA_character_,
    Ratio = if (!is.na(ratio_match[1,1])) str_trim(ratio_match[1,2]) else NA_character_
  )
}


# --- 4. 主执行流程 (无需更改) ---

if (!dir.exists(ROOT_DIRECTORY)) {
  stop("错误: 指定的目录不存在 -> '", ROOT_DIRECTORY, "'")
}

message("开始扫描目录: ", ROOT_DIRECTORY)
all_files <- list.files(path = ROOT_DIRECTORY, recursive = TRUE, full.names = TRUE, no.. = TRUE)

is_ldsc_log <- function(file_path) {
  content <- tryCatch({
    read_lines(file_path, n_max = 20) %>% paste(collapse = "\n")
  }, error = function(e) { return("") })
  str_detect(content, "LD Score Regression \\(LDSC\\)")
}

ldsc_log_files <- keep(all_files, is_ldsc_log)

if (length(ldsc_log_files) == 0) {
  message("在指定目录中未找到任何 LDSC 日志文件。")
} else {
  message(sprintf("找到了 %d 个 LDSC 日志文件，正在处理...", length(ldsc_log_files)))
  
  all_results <- map_df(ldsc_log_files, parse_ldsc_log, .progress = TRUE)
  
  write_csv(all_results, OUTPUT_CSV_FILE)
  
  message(sprintf("\n处理完成！结果已成功保存到: %s", file.path(getwd(), OUTPUT_CSV_FILE)))
}
