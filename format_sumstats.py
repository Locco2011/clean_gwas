#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
一个用于格式化遗传学摘要统计数据文件的脚本 (v8, 详细注释版)。

功能:
1.  [修复] 采用最稳健的循环方式分块处理大文件，彻底解决 "StopIteration" 错误。
2.  [修复] 添加了`dtype`规范，以主动防止`DtypeWarning`并确保列类型稳定。
3.  通过分块处理高效处理大文件，防止内存溢出。
4.  提供 --preview 模式以安全地检查文件内容。
5.  智能处理样本量 'N' 列（可来自文件或固定值）。
6.  优化读取速度，可为 .tsv 或 .csv 文件指定快速的 'c' 引擎。
7.  输出严格只包含10个标准化的列。
"""

# 导入必要的库
import argparse  # 用于解析命令行参数
import sys       # 用于与系统交互，例如退出脚本
import pandas as pd  # 用于数据处理的核心库

def preview_data(filepath: str):
    """
    读取并打印文件的列名和前3行数据，用于预览。
    这个函数旨在快速查看文件结构，因此不进行复杂的优化。
    """
    print(f"[*] 正在预览文件 '{filepath}' 的前3行数据...")
    try:
        # 使用灵活但较慢的python引擎读取，因为预览时灵活性比速度更重要。
        # sep=r'\s+' 可以匹配任何空白字符（空格、制表符等）。
        # nrows=3 只读取文件的前3行数据，效率很高。
        df_preview = pd.read_csv(filepath, sep=r'\s+', engine='python', nrows=3)
        
        print("\n--- 数据预览 ---")
        # 使用 to_string() 可以确保即使列很多，也能完整显示不被截断。
        print(df_preview.to_string())
        print("------------------\n")
        
    except Exception as e:
        # 捕获预览过程中可能出现的任何错误，例如文件不存在。
        print(f"[!] 预览文件时发生错误: {e}", file=sys.stderr)
        sys.exit(1) # 出错后退出脚本

def parse_arguments() -> argparse.Namespace:
    """
    使用argparse库解析所有命令行参数。
    返回一个包含所有参数值的命名空间对象。
    """
    # 创建一个参数解析器对象，并提供脚本的描述信息
    parser = argparse.ArgumentParser(
        description="格式化摘要统计数据文件，支持分块处理大文件。",
        formatter_class=argparse.RawTextHelpFormatter # 保持帮助信息中的换行格式
    )
    
    # --- 定义核心参数 ---
    parser.add_argument('--sumstats', required=True, help="输入的摘要统计数据文件路径。")
    # action='store_true' 表示这是一个开关参数，如果提供了--preview，则其值为True，否则为False
    parser.add_argument('--preview', action='store_true', help="预览文件前3行并退出。")
    parser.add_argument('--out', help="输出的 .txt 文件名。")
    # 增加 --sep 参数，让用户可以明确指定分隔符，以获得最佳性能
    parser.add_argument('--sep', default=r'\s+', help="文件分隔符。推荐用法: 为制表符文件指定 '\\t'，为逗号文件指定 ','。默认为 '\\s+' (任意空白，较慢)。")

    # --- 定义一个参数组，用于存放所有列名映射参数 ---
    mapping_group = parser.add_argument_group('列名映射参数 (在非预览模式下为必需)')
    mapping_group.add_argument('--CHR', help="文件中代表'染色体'的原始列名。")
    mapping_group.add_argument('--BP', help="文件中代表'物理位置'的原始列名。")
    mapping_group.add_argument('--SNP', help="文件中代表'SNP标识符'的原始列名。")
    mapping_group.add_argument('--A1', help="文件中代表'效应等位基因'的原始列名。")
    mapping_group.add_argument('--A2', help="文件中代表'非效应等位基因'的原始列名。")
    mapping_group.add_argument('--P', help="文件中代表'P值'的原始列名。")
    mapping_group.add_argument('--BETA', help="文件中代表'效应大小'的原始列名。")
    mapping_group.add_argument('--SE', help="文件中代表'标准误'的原始列名。")
    mapping_group.add_argument('--FRQ', help="文件中代表'效应等位基因频率'的原始列名。")
    mapping_group.add_argument('--N', help="文件中代表'样本量'的原始列名, 或一个固定的数值。")

    return parser.parse_args()

def main():
    """
    脚本的主逻辑函数，采用稳健的 'while True' 循环进行分块处理。
    """
    # 首先，解析命令行传入的所有参数
    args = parse_arguments()

    # 如果用户只想预览文件，则调用预览函数并立即退出脚本
    if args.preview:
        preview_data(args.sumstats)
        sys.exit(0)

    # --- 参数验证 ---
    # 在非预览模式下，这些参数都是必需的
    required_args = ['out', 'CHR', 'BP', 'SNP', 'A1', 'A2', 'P', 'BETA', 'SE', 'FRQ', 'N']
    # 循环检查每个必需参数是否已提供
    for arg in required_args:
        if getattr(args, arg) is None:
            print(f"[!] 错误: 在非预览模式下, 参数 --{arg} 是必需的。", file=sys.stderr)
            sys.exit(1)

    print(f"[*] 开始处理文件: {args.sumstats}")

    # --- 智能处理N列 ---
    # 判断用户为--N提供的值是否为纯数字
    is_n_a_fixed_value = args.N.isdigit()
    
    # --- 构建列名映射字典 ---
    # 这个字典的格式是 {原始列名: 标准列名}
    column_mapping = {
        args.CHR: 'CHR', args.BP: 'BP', args.SNP: 'SNP', args.A1: 'A1', args.A2: 'A2',
        args.P: 'P', args.BETA: 'BETA', args.SE: 'SE', args.FRQ: 'FRQ'
    }
    # 如果N不是一个固定值，那么它就是一个列名，需要加入到映射中
    if not is_n_a_fixed_value:
        column_mapping[args.N] = 'N'
    
    # 获取所有需要从原始文件中保留的列名
    original_columns_to_keep = list(column_mapping.keys())
    
    # --- 预防 DtypeWarning ---
    # 主动设置CHR和SNP列的数据类型为字符串(str)，因为它们最容易出现混合类型
    # 这是处理这类警告的最佳实践
    dtype_spec = {args.CHR: str, args.SNP: str}

    # --- 分块处理设置 ---
    chunk_size = 500000  # 每次处理50万行，可以根据内存大小调整此值
    is_first_chunk = True # 标记是否为第一个数据块，用于决定是否写入文件头
    # 处理转义字符，例如用户输入 '\\t' 应该被理解为制表符 '\t'
    sep = args.sep.encode().decode('unicode_escape')
    # 如果分隔符不是复杂的空白符，就使用速度更快的'c'引擎
    engine = 'c' if sep != r'\s+' else 'python'

    print(f"[*] 启动分块处理模式 (每块 {chunk_size} 行, 分隔符: '{sep}', 引擎: '{engine}')...")

    try:
        # 创建一个文件读取的迭代器，准备分块读取
        reader = pd.read_csv(
            args.sumstats,
            sep=sep,
            engine=engine,
            iterator=True,
            dtype=dtype_spec # 应用我们之前定义的dtype规范
        )
        
        loop_count = 0
        # --- 使用稳健的 while True 循环结构来处理数据块 ---
        while True:
            try:
                loop_count += 1
                # 从迭代器中获取一个数据块
                chunk = reader.get_chunk(chunk_size)
                print(f"[*] 正在处理第 {loop_count} 块...")

                # --- 对每个数据块执行相同的处理逻辑 ---
                
                # 只在处理第一个块时检查列名是否存在，避免重复检查
                if is_first_chunk:
                    missing_cols = [col for col in original_columns_to_keep if col not in chunk.columns]
                    if missing_cols:
                        print(f"[!] 错误: 输入文件中缺少以下指定的列: {', '.join(missing_cols)}", file=sys.stderr)
                        sys.exit(1)

                # 1. 选择需要的列
                df_subset = chunk[original_columns_to_keep]
                # 2. 重命名列
                df_renamed = df_subset.rename(columns=column_mapping)
                # 3. 如果N是固定值，则添加N列
                if is_n_a_fixed_value:
                    df_renamed['N'] = pd.to_numeric(args.N)
                
                # 4. 保证输出列的顺序是标准的
                final_columns_order = ['CHR', 'BP', 'SNP', 'A1', 'A2', 'P', 'BETA', 'SE', 'FRQ', 'N']
                df_final = df_renamed[final_columns_order]

                # --- 将处理好的块写入文件 ---
                if is_first_chunk:
                    # 第一个块：使用 'w' (write) 模式覆盖旧文件，并写入文件头 (header=True)
                    df_final.to_csv(args.out, sep='\t', index=False, mode='w', header=True, na_rep='NA')
                    is_first_chunk = False # 取消标记，后续的块不再是第一个
                else:
                    # 后续的块：使用 'a' (append) 模式追加写入，并且不写文件头 (header=False)
                    df_final.to_csv(args.out, sep='\t', index=False, mode='a', header=False, na_rep='NA')
            
            except StopIteration:
                # 当`get_chunk`读取到文件末尾时，会发出StopIteration信号。
                # 这是文件处理完成的正常标志，我们捕获它并跳出while循环。
                print("[*] 所有数据块处理完毕。")
                break
        
        # 修正了之前的拼写错误 (eout -> out)
        print(f"✨ 处理完成！结果已保存至 {args.out}")

    except Exception as e:
        # 捕获其他所有在处理过程中可能发生的意外错误
        print(f"[!] 处理文件时发生意外错误: {e}", file=sys.stderr)
        sys.exit(1)

# 这是Python脚本的标准入口点。
# 只有当这个文件被直接执行时，`if`内的代码才会运行。
# 如果它被其他脚本作为模块导入，则不会运行。
if __name__ == '__main__':
    main()