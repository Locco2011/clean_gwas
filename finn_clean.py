import os
import glob
import pandas as pd
from tqdm import tqdm

def process_file_in_chunks(gz_file_path, metadata_df, column_rename_map, final_columns, chunk_size=500000):
    try:
        filename = os.path.basename(gz_file_path)
        phenocode = filename.replace('finngen_R12_', '').replace('.gz', '')

        try:
            row = metadata_df.loc[phenocode]
            num_cases = row['num_cases']
            num_controls = row['num_controls']
            n_value = num_cases + num_controls
        except KeyError:
            return f"警告: 在 Excel 文件中找不到 Phenocode '{phenocode}'，跳过文件 {filename}"

        output_filename = f"{phenocode}.txt"
        processed_rows = 0
        write_mode = 'w'
        write_header = True

        if os.path.exists(output_filename):
            try:
                with open(output_filename, 'r', encoding='utf-8') as f:
                    lines_written = sum(1 for _ in f)
                if lines_written > 1:
                    processed_rows = lines_written - 1
                    write_mode = 'a'
                    write_header = False
                    print(f"\n  -> 检测到部分完成的文件 {output_filename}, 从第 {processed_rows + 1} 行继续...")
                else:
                    processed_rows = 0
            except Exception:
                processed_rows = 0

        if processed_rows == 0:
             print(f"\n  -> 开始处理 {filename}, 输出至 {output_filename}, 每片 {chunk_size} 行...")
       
        total_rows_iterated = 0

        with pd.read_csv(
            gz_file_path,
            compression='gzip',
            sep='\t',
            dtype={'#chrom': str, 'rsids': str, 'pval': str},
            chunksize=chunk_size
        ) as reader:
            for chunk_df in reader:
                current_chunk_size = len(chunk_df)

                if total_rows_iterated + current_chunk_size <= processed_rows:
                    total_rows_iterated += current_chunk_size
                    continue

                rows_to_drop = processed_rows - total_rows_iterated
                if rows_to_drop > 0:
                    chunk_df = chunk_df.iloc[rows_to_drop:].copy()
                
                total_rows_iterated += current_chunk_size
                processed_rows = 0

                if chunk_df.empty:
                    continue

                chunk_df['N'] = n_value
                chunk_df.rename(columns=column_rename_map, inplace=True)
                
                existing_columns_to_keep = [col for col in final_columns if col in chunk_df.columns]
                chunk_filtered = chunk_df[existing_columns_to_keep]
                
                chunk_filtered.to_csv(
                    output_filename, 
                    sep='\t', 
                    index=False, 
                    na_rep='NA', 
                    mode=write_mode, 
                    header=write_header
                )
                
                write_mode = 'a'
                write_header = False

        return f"成功处理: {filename}"

    except Exception as e:
        return f"错误: 处理文件 {gz_file_path} 时失败: {e}"

def main():
    print("--- 脚本启动 (支持断点续传) ---")
    
    excel_file_path = 'finnGen_R12.xlsx'
    print(f"正在加载元数据: {excel_file_path}...")
    try:
        metadata_df = pd.read_excel(excel_file_path)
        metadata_df.set_index('phenocode', inplace=True)
    except Exception as e:
        print(f"❌ 严重错误: 无法加载元数据文件 '{excel_file_path}'。错误信息: {e}")
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

    results = []
    completed_files = []
    print("\n--- 开始检查并处理文件，请稍候 ---")
    
    for gz_file_path in tqdm(gz_files, desc="总体进度", unit="个文件"):
        phenocode = os.path.basename(gz_file_path).replace('finngen_R12_', '').replace('.gz', '')
        done_file = f"{phenocode}.done"

        if os.path.exists(done_file):
            completed_files.append(gz_file_path)
            continue
        
        status = process_file_in_chunks(
            gz_file_path,
            metadata_df=metadata_df,
            column_rename_map=column_rename_map,
            final_columns=final_columns,
            chunk_size=500000
        )
        results.append(status)

        if status.startswith("成功"):
            with open(done_file, 'w') as f:
                pass

    success_count = sum(1 for r in results if r.startswith("成功"))
    warning_count = sum(1 for r in results if r.startswith("警告"))
    error_count = sum(1 for r in results if r.startswith("错误"))
    
    print("\n--- 所有任务处理完毕 ---")
    if completed_files:
        print(f"⏭️ 已完成 (跳过): {len(completed_files)} 个文件")
    print(f"✅ 本次成功: {success_count} 个文件")
    if warning_count > 0:
        print(f"⚠️ 警告 (跳过): {warning_count} 个文件")
        for r in results:
            if r.startswith("警告"):
                print(f"   - {r}")
    if error_count > 0:
        print(f"❌ 错误: {error_count} 个文件")
        for r in results:
            if r.startswith("错误"):
                print(f"   - {r}")

if __name__ == '__main__':
    main()
