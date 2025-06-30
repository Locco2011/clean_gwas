Clean GWAS
clean_gwas 是一套用于清洗和格式化全基因组关联研究（GWAS）摘要统计数据的脚本集合。主要功能包括标准化列名、数据过滤、坐标系转换等，以方便下游分析。

目录
Clean GWAS

目录

依赖环境

安装与更新

首次安装

更新项目

数据格式

使用说明

授权脚本

清洗芬兰 (FinnGen) R12 版本数据

通用 GWAS 数据清洗

基因组坐标系转换 (hg38 <=> hg37)

数据结构预览

依赖环境
操作系统: Ubuntu 20.04.6 LTS

Python: 3.10

Conda: 用于环境管理

所有依赖项均已在 environment.yml 文件中列出。

安装与更新
首次安装

请按照以下步骤克隆项目并创建 Conda 环境：

Bash
# 克隆项目仓库
git clone https://github.com/Locco2011/clean_gwas.git

# 进入项目目录
cd clean_gwas

# 使用 environment.yml 文件创建并激活 Conda 环境
conda env create -f environment.yml
conda activate clean
更新项目

如果您想获取最新的脚本和功能，请在项目根目录下执行 git pull 命令：

Bash
cd clean_gwas
git pull
数据格式
为了使脚本能正确运行，您的 GWAS 数据文件需要包含以下标准列名：

列名

描述

CHR

染色体 (Chromosome)

BP

碱基对位置 (Base Pair Position)

SNP

SNP 标识符 (e.g., rsID)

A1

效应等位基因 (Effect Allele)

A2

非效应等位基因 (Non-effect Allele)

P

P 值 (P-value)

BETA

效应值 (Effect Size)

SE

标准误 (Standard Error)

FRQ

效应等位基因频率 (Effect Allele Frequency)

N

样本量 (Sample Size)

使用说明
授权脚本

在首次使用前，请为所有 shell 脚本授予可执行权限：

Bash
sudo chmod +x *.sh
清洗芬兰 (FinnGen) R12 版本数据

注意： 执行这些脚本时，请确保当前工作目录下只包含需要处理的 FinnGen 数据文件。

基础清洗 (finn_clean.sh)
此脚本将 FinnGen R12 版本的摘要统计数据进行标准化处理，并将列名统一为标准格式。同时，它会根据 finnGen_R12.xlsx 文件中的病例数（num_cases）和对照数（num_controls）计算并补充样本量 N 列。

前置操作: 将下载好的 FinnGen 数据和 finnGen_R12.xlsx 文件放入当前目录。

执行命令:

Bash
./finn_clean.sh
进阶清洗 (finn_clean_plus.sh)
此脚本在基础清洗之上，增加了更严格的过滤规则：

P 值过滤: 移除 P 值不在 (0, 1] 区间内的无效行。

等位基因过滤: 移除链模糊 (strand-unambiguous) 的 SNP（如 A/T, G/C）。

等位基因一致性: 确保等位基因符合标准。

前置操作: 将下载好的 FinnGen 数据放入当前目录。

执行命令:

Bash
./finn_clean_plus.sh
通用 GWAS 数据清洗

对于非 FinnGen 的其他 GWAS 数据，可以使用 format_sumstats.sh 脚本进行基础的列名重置。

自定义修改:

打开 format_sumstats.sh 文件进行编辑。

如果原始 GWAS 文件中已有样本量（N）列，请确保脚本能正确识别并映射该列。

如果原始数据中没有样本量，您可以在脚本中直接指定一个固定的样本量值。

执行命令:

Bash
./format_sumstats.sh your_gwas_file.txt
基因组坐标系转换 (hg38 <=> hg37)

前提: 待转换的文件必须是已经过上述清洗流程处理、并采用标准列名的 .txt 文件。

单个文件转换 (hg38 -> hg37):

Bash
./38to37.sh your_file_hg38.txt
单个文件转换 (hg37 -> hg38):

Bash
./37to38.sh your_file_hg37.txt
批量转换 (指定文件夹内所有 .txt 文件):

批量 hg37 -> hg38:

Bash
# /path/to/your/folder 是存放标准 GWAS 文件的文件夹路径
./37to38cycle.sh /path/to/your/folder
批量 hg38 -> hg37:

Bash
# /path/to/your/folder 是存放标准 GWAS 文件的文件夹路径
./38to37cycle.sh /path/to/your/folder
数据结构预览

如果您想快速查看数据文件的结构（如前几行、列名等），可以修改并运行 format_sumstats_preview.sh 脚本。

自定义修改: 打开 format_sumstats_preview.sh 并指定您想预览的文件名。

执行命令:

Bash
./format_sumstats_preview.sh
