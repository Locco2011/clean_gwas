# 设置工作目录
my_dir <- "/path/to/your/folder"

# 递归列出所有文件（不包括目录本身）
files <- list.files(
  path = my_dir, 
  full.names = TRUE, 
  recursive = TRUE
)

# 只保留是文件的路径
files <- files[file.info(files)$isdir == FALSE]

# 遍历每个文件
for (file_path in files) {
  # 提取文件名
  file_name <- basename(file_path)
  
  # 如果文件名包含 _hg
  if (grepl("_hg19", file_name)) {
    # 删除文件名中的 _hg
    new_file_name <- gsub("_hg19", "", file_name)
    
    # 拼接新路径
    new_file_path <- file.path(dirname(file_path), new_file_name)
    
    # 防止覆盖已有文件
    if (!file.exists(new_file_path)) {
      file.rename(file_path, new_file_path)
      message(sprintf("Renamed: %s -> %s", file_path, new_file_path))
    } else {
      message(sprintf("Skipped (target exists): %s", new_file_path))
    }
  }
}
