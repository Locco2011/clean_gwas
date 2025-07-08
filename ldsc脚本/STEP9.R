#################################################################
#                                                               #
#      批量处理LDSC日志，并进行FDR校正与筛选的R脚本              #
#                                                               #
#             (版本: 最终完整流程)                              #
#                                                               #
#################################################################

# ---------------------------------------------------------------
# 步骤 1: 加载所需R包
# ---------------------------------------------------------------
# install.packages(c("fs", "purrr", "dplyr", "stringr", "readr"))
library(fs)
library(purrr)
library(dplyr)
library(stringr)
library(readr)


# ---------------------------------------------------------------
# 步骤 2: 配置顶层目录路径
# ---------------------------------------------------------------
# !!! 这是唯一需要您手动修改的地方 !!!
main_folder <- "G:/mvLung/result_ldsc/" 


# ---------------------------------------------------------------
# 步骤 3: 递归查找所有.log文件
# ---------------------------------------------------------------
log_files <- dir_ls(main_folder, recurse = TRUE, glob = "**/*.log")


# ---------------------------------------------------------------
# 步骤 4: 定义带详细错误报告的解析函数
# ---------------------------------------------------------------
parse_summary_line_robust <- function(filepath) {
  
  cat("正在处理:", as.character(filepath), "\n")
  
  # 定义一个标准的空/失败结果行结构
  fail_tibble <- tibble(
    p1 = NA_character_, p2 = NA_character_, rg = NA_real_, se = NA_real_,
    z = NA_real_, p = NA_real_, h2_obs = NA_real_, h2_obs_se = NA_real_,
    h2_int = NA_real_, h2_int_se = NA_real_, gcov_int = NA_real_, 
    gcov_int_se = NA_real_
  )
  
  log_lines <- tryCatch({ read_lines(filepath) }, error = function(e) { NULL })
  
  if (is.null(log_lines)) {
    return(fail_tibble %>% mutate(parse_status = "read_error", source_file = as.character(filepath)))
  }
  
  header_pattern <- "p1\\s+p2\\s+rg\\s+se\\s+z\\s+p"
  header_index <- str_which(log_lines, header_pattern)
  
  if (length(header_index) == 0 || header_index >= length(log_lines)) {
    return(fail_tibble %>% mutate(parse_status = "header_not_found", source_file = as.character(filepath)))
  }
  
  table_text <- paste(log_lines[header_index], log_lines[header_index + 1], sep = "\n")
  
  result_table <- tryCatch({
    read_table(table_text, col_types = cols(.default = "c")) %>%
      mutate(across(-c(p1, p2), as.numeric))
  }, error = function(e){ NULL })
  
  if(is.null(result_table) || nrow(result_table) == 0){
    return(fail_tibble %>% mutate(parse_status = "parse_error", source_file = as.character(filepath)))
  }
  
  result_with_source <- result_table %>%
    mutate(
      source_file = as.character(filepath),
      parse_status = "success"
    )
  
  return(result_with_source)
}


# ---------------------------------------------------------------
# 步骤 5: 执行批量处理
# ---------------------------------------------------------------
if (length(log_files) > 0) {
  
  cat("\n--- 开始批量处理", length(log_files), "个日志文件... ---\n")
  all_results <- map_dfr(log_files, parse_summary_line_robust)
  
  cat("\n--- 批量处理完成 ---\n")
  
  # --- 步骤 6: 数据后处理、FDR校正与分步导出 ---
  
  # 步骤 6.1: 保存所有原始解析结果（包括成功和失败的）
  cat("\n--- 步骤 6.1: 保存所有原始解析结果 ---\n")
  readr::write_csv(all_results, "ldsc_all.csv")
  cat("所有", nrow(all_results), "行原始结果已保存到: ldsc_all.csv\n")
  
  # 步骤 6.2: FDR校正
  # 首先创建一个只包含成功解析且p值有效的数据集
  results_to_correct <- all_results %>%
    filter(parse_status == "success" & !is.na(p))
  
  if(nrow(results_to_correct) > 0) {
    cat("\n--- 步骤 6.2: 对", nrow(results_to_correct), "个有效P值进行FDR校正 ---\n")
    
    results_with_fdr <- results_to_correct %>%
      # 新增 p.adj 列，使用 "fdr" (Benjamini-Hochberg) 方法进行多重检验校正
      mutate(p.adj = p.adjust(p, method = "fdr"))
    
    # 保存包含FDR值的未筛选结果
    readr::write_csv(results_with_fdr, "ldsc_all_fdr_unfilter.csv")
    cat("带有FDR校正的完整结果已保存到: ldsc_all_fdr_unfilter.csv\n")
    
    # 步骤 6.3: 筛选显著结果并导出
    cat("\n--- 步骤 6.3: 筛选FDR显著结果 (p.adj < 0.05) ---\n")
    
    significant_results <- results_with_fdr %>%
      filter(p.adj < 0.05) %>%
      # 按校正后的p值升序排列，最重要的结果在最上面
      arrange(p.adj)
    
    if(nrow(significant_results) > 0){
      readr::write_csv(significant_results, "ldsc_all_fdr_filter.csv")
      cat(nrow(significant_results), "个显著结果已保存到: ldsc_all_fdr_filter.csv\n")
    } else {
      cat("未发现FDR校正后显著的结果 (p.adj < 0.05)。\n")
    }
  } else {
    cat("没有可用于FDR校正的有效数据。\n")
  }
  
} else {
  cat("\n--- 警告: 在指定目录中没有找到任何 .log 文件。 ---\n")
}

# --- 脚本结束 ---
