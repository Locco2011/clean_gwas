# -*- coding: utf-8 -*-
# 这是一个顺序处理 + 片段化处理的版本。
# 它会一个接一个地处理文件，并且对每个文件内部进行分块读取，以节省内存。

import os
import glob
import pandas as pd
from tqdm import tqdm
import numpy as np

# --- 1. 请在这里配置您的路径和参数 ---
# (可选) 等位基因参考文件路径，如果不需要则设为 None
MERGE_ALLELES_FILE_PATH = './w_hm3.snplist'
# 设置每个片段的大小（行数）。可根据您的内存大小调整。
CHUNK_SIZE = 500000 

# --- 工作者函数：处理单个文件的所有逻辑 (已修改为片段化处理) ---
def process_single_file(gz_file_path, metadata_df, column_rename_map, final_columns, merge_alleles_df):
    """这个函数现在使用片段化处理来高效处理单个大文件。"""
    try:
        filename = os.path.basename(gz_file_path)
        
        # --- 步骤 A: 准备工作 ---
        phenocode = filename.replace('finngen_R12_', '').replace('.gz', '')
        try:
            row = metadata_df.loc[phenocode]
            n_value = row['num_cases'] + row['num_controls']
        except KeyError:
            return f"警告: 在 Excel 文件中找不到 Phenocode '{phenocode}'，跳过文件 {filename}"

        processed_chunks = []
        initial_rows = 0

        # --- 步骤 B: 创建迭代器并分块处理 ---
        reader = pd.read_csv(
            gz_file_path, compression='gzip', sep='\t',
            dtype={'#chrom': str, 'rsids': str, 'pval': str},
            chunksize=CHUNK_SIZE
        )

        for gwas_chunk in reader:
            initial_rows += len(gwas_chunk)
            
            # --- 对每个块应用所有过滤逻辑 ---

            # 1. 列重命名与类型转换
            gwas_chunk.rename(columns=column_rename_map, inplace=True)
            gwas_chunk['P'] = pd.to_numeric(gwas_chunk['P'], errors='coerce')
            gwas_chunk.dropna(subset=['P'], inplace=True)

            # 2. P值有效性过滤
            p_filter_mask = (gwas_chunk['P'] > 0) & (gwas_chunk['P'] <= 1)
            gwas_chunk = gwas_chunk[p_filter_mask].copy()

            # 3. (可选) 等位基因合并与校验
            if merge_alleles_df is not None:
                merged_chunk = pd.merge(gwas_chunk, merge_alleles_df, on='SNP', how='inner', suffixes=('', '_ref'))
                if not merged_chunk.empty:
                    allele_match_mask = merged_chunk.apply(
                        lambda r: {r['A1'], r['A2']} == {r['A1_ref'], r['A2_ref']},
                        axis=1
                    )
                    gwas_chunk = merged_chunk[allele_match_mask].copy()
                    gwas_chunk.drop(columns=['A1_ref', 'A2_ref'], inplace=True)
                else:
                    gwas_chunk = pd.DataFrame(columns=gwas_chunk.columns) #
            
            # 4. 链模糊SNP过滤
            if not gwas_chunk.empty:
                ambiguous_sets = [{'A', 'T'}, {'C', 'G'}]
                allele_sets = gwas_chunk.apply(lambda r: {str(r['A1']).upper(), str(r['A2']).upper()}, axis=1)
                non_ambiguous_mask = allele_sets.apply(lambda s: s not in ambiguous_sets)
                gwas_chunk = gwas_chunk[non_ambiguous_mask].copy()

            # 如果块经过滤后仍有数据，则添加到列表中
            if not gwas_chunk.empty:
                processed_chunks.append(gwas_chunk)

        # --- 步骤 C: 合并所有处理过的片段 ---
        if not processed_chunks:
            return f"警告: 经过滤后，文件 {filename} 无剩余数据，已跳过。"
        
        gwas_df = pd.concat(processed_chunks, ignore_index=True)
        rows_after_all_filters = len(gwas_df)

        # --- 步骤 D: 添加N列并筛选最终列 ---
        gwas_df['N'] = n_value
        existing_columns_to_keep = [col for col in final_columns if col in gwas_df.columns]
        gwas_df_filtered = gwas_df[existing_columns_to_keep]

        # --- 步骤 E: 保存文件 ---
        output_filename = f"{phenocode}.txt"
        gwas_df_filtered.to_csv(output_filename, sep='\t', index=False, na_rep='NA')
        
        return f"成功处理: {filename} ({rows_after_all_filters}/{initial_rows} 个SNP保留)"
    except Exception as e:
        return f"错误: 处理文件 {gz_file_path} 时失败: {e}"

# --- 主函数：负责管理和调度 (此函数无需修改) ---
def main():
    """主函数，负责管理所有任务"""
    print("--- 脚本启动 (顺序处理 + 片段化读取模式) ---")
    print(f"每个文件将被分成 {CHUNK_SIZE} 行的片段进行处理。")
    
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
    
    print(f"共找到 {len(gz_files)} 个文件待处理。")

    print("\n--- 开始顺序处理，请稍候 ---")
    results = []
    for gz_file in tqdm(gz_files, desc="处理文件"):
        result = process_single_file(
            gz_file,
            metadata_df=metadata_df,
            column_rename_map=column_rename_map,
            final_columns=final_columns,
            merge_alleles_df=merge_alleles_df
        )
        results.append(result)

    print("\n--- 所有任务处理完毕 ---")
    successes = [r for r in results if r.startswith("成功")]
    warnings = [r for r in results if r.startswith("警告")]
    errors = [r for r in results if r.startswith("错误")]

    print(f"✅ 成功: {len(successes)} 个文件")
    if warnings:
        print(f"⚠️ 警告 (已跳过): {len(warnings)} 个文件")
        for w in warnings:
            print(f"   - {w}")
    if errors:
        print(f"❌ 错误 (处理失败): {len(errors)} 个文件")
        for e in errors:
            print(f"   - {e}")

if __name__ == '__main__':
    main()