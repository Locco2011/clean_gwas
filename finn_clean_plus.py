# -*- coding: utf-8 -*-
#过滤P值，移除那些不在 (0, 1] 区间内的无效P值#
#过滤等位基因，只保留那些非链模糊（strand-unambiguous）的SNP#
#确保等位基因的一致性#
import os
import glob
import pandas as pd
import multiprocessing
from tqdm import tqdm
from functools import partial
import numpy as np

# --- 1. 请在这里配置您的路径 ---
MERGE_ALLELES_FILE_PATH = './w_hm3.snplist'

# --- 工作者函数：处理单个文件的所有逻辑 ---
def process_single_file(gz_file_path, metadata_df, column_rename_map, final_columns, merge_alleles_df):
    """这个函数包含了处理单个.gz文件的所有步骤，并新增了多个过滤逻辑。"""
    try:
        filename = os.path.basename(gz_file_path)
        
        # --- 步骤 A: 读取和初步准备 ---
        phenocode = filename.replace('finngen_R12_', '').replace('.gz', '')
        try:
            row = metadata_df.loc[phenocode]
            n_value = row['num_cases'] + row['num_controls']
        except KeyError:
            return f"警告: 在 Excel 文件中找不到 Phenocode '{phenocode}'，跳过文件 {filename}"

        gwas_df = pd.read_csv(
            gz_file_path, compression='gzip', sep='\t',
            dtype={'#chrom': str, 'rsids': str, 'pval': str}
        )
        initial_rows = len(gwas_df)

        # --- 步骤 B: 列重命名与类型转换 ---
        gwas_df.rename(columns=column_rename_map, inplace=True)
        gwas_df['P'] = pd.to_numeric(gwas_df['P'], errors='coerce')
        gwas_df.dropna(subset=['P'], inplace=True)

        # --- 步骤 C: P值有效性过滤 (filter_pvals) ---
        p_filter_mask = (gwas_df['P'] > 0) & (gwas_df['P'] <= 1)
        gwas_df = gwas_df[p_filter_mask].copy()

        # --- 步骤 D: (可选) 等位基因合并与校验 (allele_merge) ---
        if merge_alleles_df is not None:
            merged_df = pd.merge(gwas_df, merge_alleles_df, on='SNP', how='inner', suffixes=('', '_ref'))
            allele_match_mask = merged_df.apply(
                lambda row: {row['A1'], row['A2']} == {row['A1_ref'], row['A2_ref']},
                axis=1
            )
            gwas_df = merged_df[allele_match_mask].copy()
            gwas_df.drop(columns=['A1_ref', 'A2_ref'], inplace=True)

        # --- 步骤 E: 链模糊SNP过滤 (filter_alleles) ---
        ambiguous_sets = [{'A', 'T'}, {'C', 'G'}]
        allele_sets = gwas_df.apply(lambda row: {str(row['A1']).upper(), str(row['A2']).upper()}, axis=1)
        non_ambiguous_mask = allele_sets.apply(lambda s: s not in ambiguous_sets)
        gwas_df = gwas_df[non_ambiguous_mask].copy()
        
        # ✨ FIX: Corrected typo from ggwas_df to gwas_df
        rows_after_all_filters = len(gwas_df)
        
        # --- 步骤 F: 添加N列并筛选最终列 ---
        gwas_df['N'] = n_value
        existing_columns_to_keep = [col for col in final_columns if col in gwas_df.columns]
        gwas_df_filtered = gwas_df[existing_columns_to_keep]

        # --- 步骤 G: 保存文件 ---
        if gwas_df_filtered.empty:
            return f"警告: 经过滤后，文件 {filename} 无剩余数据，已跳过。"
            
        output_filename = f"{phenocode}.txt"
        gwas_df_filtered.to_csv(output_filename, sep='\t', index=False, na_rep='NA')
        
        return f"成功处理: {filename} ({rows_after_all_filters}/{initial_rows} 个SNP保留)"
    except Exception as e:
        return f"错误: 处理文件 {gz_file_path} 时失败: {e}"

# --- 主函数：负责管理和调度 ---
def main():
    """主函数，负责管理所有任务"""
    print("--- 脚本启动 ---")
    
    excel_file_path = 'finnGen_R12.xlsx'
    merge_alleles_df = None
    
    print(f"正在加载元数据: {excel_file_path}...")
    try:
        metadata_df = pd.read_excel(excel_file_path, engine='openpyxl')
        metadata_df.set_index('phenocode', inplace=True)
    except Exception as e:
        print(f"❌ 严重错误: 无法加载元数据文件 '{excel_file_path}'。错误信息: {e}")
        return

    if MERGE_ALLELES_FILE_PATH:
        print(f"正在加载等位基因参考文件: {MERGE_ALLELES_FILE_PATH}...")
        try:
            merge_alleles_df = pd.read_csv(MERGE_ALLELES_FILE_PATH, sep=r'\s+', usecols=['SNP', 'A1', 'A2'], engine='python')
            print(f"✅ 成功加载 {len(merge_alleles_df)} 个参考SNP。")
        except Exception as e:
            print(f"❌ 严重错误: 无法加载等位基因参考文件。错误信息: {e}")
            return
            
    column_rename_map = {
        '#chrom': 'CHR', 'pos': 'BP', 'ref': 'A2', 'alt': 'A1', 'rsids': 'SNP',
        'pval': 'P', 'beta': 'BETA', 'sebeta': 'SE', 'af_alt': 'FRQ'
    }
    final_columns = ['CHR', 'BP', 'A1', 'A2', 'SNP', 'P', 'BETA', 'SE', 'FRQ', 'N']

    gz_files = glob.glob('finngen_R12_*.gz')
    if not gz_files:
        print("⚠️ 警告: 在当前文件夹中未找到任何 'finngen_R12_*.gz' 文件。")
        return
    
    total_cores = os.cpu_count()
    num_processes = max(1, total_cores // 2)
    print(f"系统总核心数: {total_cores}。将使用 {num_processes} 个核心进行处理。")
    print(f"共找到 {len(gz_files)} 个文件待处理。")

    worker_func_with_args = partial(
        process_single_file,
        metadata_df=metadata_df,
        column_rename_map=column_rename_map,
        final_columns=final_columns,
        merge_alleles_df=merge_alleles_df
    )

    print("\n--- 开始并行处理，请稍候 ---")
    with multiprocessing.Pool(processes=num_processes) as pool:
        results = list(tqdm(pool.imap_unordered(worker_func_with_args, gz_files), total=len(gz_files), desc="处理文件"))

    # ✨ NEW: Improved summary logging to show details
    print("\n--- 所有任务处理完毕 ---")
    successes = [r for r in results if r.startswith("成功")]
    warnings = [r for r in results if r.startswith("警告")]
    errors = [r for r in results if r.startswith("错误")]

    print(f"✅ 成功: {len(successes)} 个文件")
    if warnings:
        print(f"⚠️ 警告 (已跳过): {len(warnings)} 个文件")
        for w in warnings:
            print(f"  - {w}") # Print detailed warning
    if errors:
        print(f"❌ 错误 (处理失败): {len(errors)} 个文件")
        for e in errors:
            print(f"  - {e}") # Print detailed error

if __name__ == '__main__':
    main()