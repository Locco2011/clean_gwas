# -*- coding: utf-8 -*-
import os
import glob
import pandas as pd
from tqdm import tqdm

# --- 工作者函数：以分片方式处理单个文件 ---
def process_file_in_chunks(gz_file_path, metadata_df, column_rename_map, final_columns, chunk_size=500000):
    """
    这个函数以内存高效的方式，分片处理单个.gz文件。
    
    参数:
    - gz_file_path (str): 输入的.gz文件路径。
    - metadata_df (pd.DataFrame): 包含样本量信息的元数据。
    - column_rename_map (dict): 列名映射字典。
    - final_columns (list): 最终需要保留的列名列表。
    - chunk_size (int): 每次读入内存的行数。
    """
    try:
        filename = os.path.basename(gz_file_path)
        
        # 1. 从文件名中提取 phenocode
        phenocode = filename.replace('finngen_R12_', '').replace('.gz', '')

        # 2. 根据 phenocode 查找对应的 num_cases 和 num_controls
        try:
            row = metadata_df.loc[phenocode]
            num_cases = row['num_cases']
            num_controls = row['num_controls']
            n_value = num_cases + num_controls
        except KeyError:
            # 如果在元数据中找不到，则跳过此文件并返回警告
            return f"警告: 在 Excel 文件中找不到 Phenocode '{phenocode}'，跳过文件 {filename}"

        # 3. 准备输出文件和处理标志
        output_filename = f"{phenocode}.txt"
        is_first_chunk = True  #  这个标志用于判断是否是第一个片段，第一个片段需要写入列名

        print(f"\n  -> 开始处理 {filename}, 输出至 {output_filename}, 每片 {chunk_size} 行...")
        
        # 4. 使用 chunksize 参数创建文件阅读器，进行分片读取
        #    使用 with 语句确保文件阅读器被正确关闭
        with pd.read_csv(
            gz_file_path,
            compression='gzip',
            sep='\t',
            dtype={'#chrom': str, 'rsids': str, 'pval': str},
            chunksize=chunk_size
        ) as reader:
            # 遍历文件中的每一个数据片段 (chunk)
            for chunk_df in reader:
                # --- 对当前片段进行数据转换 ---
                # a. 新增 'N' 列
                chunk_df['N'] = n_value

                # b. 更改列名
                chunk_df.rename(columns=column_rename_map, inplace=True)
                
                # c. 筛选出需要保留的列
                #    确保即使原始文件缺少某些列，代码也不会报错
                existing_columns_to_keep = [col for col in final_columns if col in chunk_df.columns]
                chunk_filtered = chunk_df[existing_columns_to_keep]
                
                # --- 将处理好的片段写入文件 ---
                if is_first_chunk:
                    # 如果是第一个片段，使用 'w' (write) 模式创建新文件，并写入列名 (header=True)
                    chunk_filtered.to_csv(
                        output_filename, 
                        sep='\t', 
                        index=False, 
                        na_rep='NA', 
                        mode='w', 
                        header=True
                    )
                    is_first_chunk = False  # 取消标志，后续片段不再写入列名
                else:
                    # 如果不是第一个片段，使用 'a' (append) 模式追加到已有文件，且不写入列名 (header=False)
                    chunk_filtered.to_csv(
                        output_filename, 
                        sep='\t', 
                        index=False, 
                        na_rep='NA', 
                        mode='a', 
                        header=False
                    )

        return f"成功处理: {filename}"

    except Exception as e:
        # 捕获处理该文件时发生的任何其他错误
        return f"错误: 处理文件 {gz_file_path} 时失败: {e}"

# --- 主函数：负责管理和调度 ---
def main():
    """
    主函数，负责：
    1. 加载共享资源 (Excel元数据)。
    2. 依次循环处理每个文件。
    3. 使用tqdm显示总体进度。
    """
    print("--- 脚本启动 (序列处理 & 分片模式) ---")
    
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
    
    print(f"共找到 {len(gz_files)} 个文件待处理。")

    # --- 2. 开始序列处理 ---
    results = []
    print("\n--- 开始序列处理，请稍候 ---")
    
    # 使用 tqdm 创建一个总体进度条
    for gz_file_path in tqdm(gz_files, desc="总体进度", unit="个文件"):
        status = process_file_in_chunks(
            gz_file_path,
            metadata_df=metadata_df,
            column_rename_map=column_rename_map,
            final_columns=final_columns,
            chunk_size=500000  # 可在此处调整每个片段的大小
        )
        results.append(status)
        # (可选) 实时打印每个文件的处理结果
        # print(f"  - 状态: {status}")

    # --- 3. 打印处理结果的摘要 ---
    success_count = sum(1 for r in results if r.startswith("成功"))
    warning_count = sum(1 for r in results if r.startswith("警告"))
    error_count = sum(1 for r in results if r.startswith("错误"))
    
    print("\n--- 所有任务处理完毕 ---")
    print(f"✅ 成功: {success_count} 个文件")
    if warning_count > 0:
        print(f"⚠️ 警告 (跳过): {warning_count} 个文件")
        # 打印具体的警告信息
        for r in results:
            if r.startswith("警告"):
                print(f"   - {r}")
    if error_count > 0:
        print(f"❌ 错误: {error_count} 个文件")
        # 打印具体的错误信息
        for r in results:
            if r.startswith("错误"):
                print(f"   - {r}")

if __name__ == '__main__':
    main()