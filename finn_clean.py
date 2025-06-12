# -*- coding: utf-8 -*-
import os
import glob
import pandas as pd
import multiprocessing
from tqdm import tqdm
from functools import partial

# --- 工作者函数：处理单个文件的所有逻辑 ---
def process_single_file(gz_file_path, metadata_df, column_rename_map, final_columns):
    """
    这个函数包含了处理单个.gz文件的所有步骤。
    它将被每个独立的进程调用。
    """
    try:
        filename = os.path.basename(gz_file_path)
        
        # 从文件名中提取 phenocode
        phenocode = filename.replace('finngen_R12_', '').replace('.gz', '')

        # 根据 phenocode 查找对应的 num_cases 和 num_controls
        try:
            row = metadata_df.loc[phenocode]
            num_cases = row['num_cases']
            num_controls = row['num_controls']
            n_value = num_cases + num_controls
        except KeyError:
            # 如果在元数据中找不到，则跳过此文件
            # 在多进程中，我们返回一个状态以便主进程知道
            return f"警告: 在 Excel 文件中找不到 Phenocode '{phenocode}'，跳过文件 {filename}"

        # 读取 .gz 文件，同时处理DtypeWarning
        gwas_df = pd.read_csv(
            gz_file_path,
            compression='gzip',
            sep='\t',
            dtype={'#chrom': str, 'rsids': str, 'pval': str}
        )

        # 1. 新增 'N' 列
        gwas_df['N'] = n_value

        # 2. 更改列名
        gwas_df.rename(columns=column_rename_map, inplace=True)
        
        # 3. 筛选出需要保留的列
        existing_columns_to_keep = [col for col in final_columns if col in gwas_df.columns]
        gwas_df_filtered = gwas_df[existing_columns_to_keep]
        
        # 4. 构造输出文件名并保存
        output_filename = f"{phenocode}.txt"
        gwas_df_filtered.to_csv(output_filename, sep='\t', index=False, na_rep='NA')
        
        return f"成功处理: {filename}"
    except Exception as e:
        # 捕获任何其他可能的错误
        return f"错误: 处理文件 {gz_file_path} 时失败: {e}"

# --- 主函数：负责管理和调度 ---
def main():
    """
    主函数，负责：
    1. 加载共享资源 (Excel元数据)。
    2. 计算要使用的CPU核心数。
    3. 创建一个进程池。
    4. 使用tqdm显示进度条，并将任务分配给工作进程。
    """
    print("--- 脚本启动 ---")
    
    # --- 1. 准备共享资源 ---
    excel_file_path = 'finnGen_R12.xlsx'
    print(f"正在加载元数据: {excel_file_path}...")
    try:
        metadata_df = pd.read_excel(excel_file_path)
        metadata_df.set_index('phenocode', inplace=True)
    except Exception as e:
        print(f"❌ 严重错误: 无法加载元数据文件 '{excel_file_path}'。错误信息: {e}")
        return

    # 定义列名映射和最终列
    column_rename_map = {
        '#chrom': 'CHR', 'pos': 'BP', 'ref': 'A2', 'alt': 'A1', 'rsids': 'SNP',
        'pval': 'P', 'beta': 'BETA', 'sebeta': 'SE', 'af_alt': 'FRQ'
    }
    final_columns = ['CHR', 'BP', 'A1', 'A2', 'SNP', 'P', 'BETA', 'SE', 'FRQ', 'N']

    # 查找所有需要处理的文件
    gz_files = glob.glob('finngen_R12_*.gz')
    if not gz_files:
        print("⚠️ 警告: 在当前文件夹中未找到任何 'finngen_R12_*.gz' 文件。")
        return
    
    # --- 2. 设置并行处理 ---
    # 计算使用核心数：最大核心数的一半，但至少为1
    total_cores = os.cpu_count()
    num_processes = max(1, total_cores // 2)
    print(f"系统总核心数: {total_cores}。将使用 {num_processes} 个核心进行处理。")
    print(f"共找到 {len(gz_files)} 个文件待处理。")

    # --- 3. 创建并运行进程池 ---
    # `partial` 用于固定工作者函数的参数，这样我们只需向进程池传递会变化的文件路径即可
    worker_func_with_args = partial(
        process_single_file,
        metadata_df=metadata_df,
        column_rename_map=column_rename_map,
        final_columns=final_columns
    )

    print("\n--- 开始并行处理，请稍候 ---")
    with multiprocessing.Pool(processes=num_processes) as pool:
        # 使用tqdm来包装进程池的迭代器，以显示进度条
        # `imap_unordered` 可以提高效率，因为它不关心任务完成的顺序
        results = list(tqdm(pool.imap_unordered(worker_func_with_args, gz_files), total=len(gz_files), desc="处理文件"))

    # (可选) 打印处理结果的摘要
    success_count = sum(1 for r in results if r.startswith("成功"))
    warning_count = sum(1 for r in results if r.startswith("警告"))
    error_count = sum(1 for r in results if r.startswith("错误"))
    
    print("\n--- 所有任务处理完毕 ---")
    print(f"✅ 成功: {success_count} 个文件")
    if warning_count > 0:
        print(f"⚠️ 警告 (跳过): {warning_count} 个文件")
    if error_count > 0:
        print(f"❌ 错误: {error_count} 个文件")
        # 如果有错误，可以打印出来方便排查
        # for r in results:
        #     if r.startswith("错误"):
        #         print(f"  - {r}")


if __name__ == '__main__':
    # `if __name__ == '__main__':` 这行对于多进程代码至关重要，必须保留
    main()