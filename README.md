
# clean_gwas



一套用于清洗、格式化和转换全基因组关联分析（GWAS）摘要统计数据的个人脚本集。

---

## 📋 目录

- [运行环境](#-运行环境)
- [安装与配置](#-安装与配置)
- [更新仓库](#-更新仓库)
- [标准列名解释](#-标准列名解释)
- [用法指南](#-用法指南)
  - [1. 清洗FinnGen R12数据](#1-清洗finngen-r12数据)
  - [2. 通用格式化与数据预览](#2-通用格式化与数据预览)
  - [3. 基因组坐标系转换](#3-基因组坐标系转换)
  - [4. IEU VCF格式转为常规GWAS格式](#4-ieu-vcf格式转为常规gwas格式)

---

## 🖥️ 运行环境

- **操作系统**: Linux Ubuntu 20.04.6 LTS
- **Python版本**: Python 3.10

---

## 🛠️ 安装与配置

请按照以下步骤克隆仓库并设置Conda环境。

---

```bash
# 1. 克隆仓库到本地
git clone https://github.com/Locco2011/clean_gwas.git
```

---
```bash
# 2. 进入项目目录
cd clean_gwas
```
---
```bash
# 3. 根据 environment.yml 文件创建并激活 Conda 环境
conda env create -f environment.yml
conda activate clean
```

---

## 🔄 更新仓库

如果项目有更新，可以进入项目目录并执行以下命令来与远程仓库同步。

```bash
cd clean_gwas
git pull
```

---

## 📖 标准列名解释

本项目处理的所有GWAS数据都将统一为以下标准列名格式。

| 列名  | 解释 (Description)                               |
| :---- | :----------------------------------------------- |
| `CHR`   | **染色体 (Chromosome)**：SNP所在的染色体编号。       |
| `BP`    | **物理位置 (Base Pair Position)**：SNP在染色体上的物理位置坐标。 |
| `SNP`   | **SNP标识符 (SNP Identifier)**：通常是rsID，例如 `rs123456`。   |
| `A1`    | **等位基因1 (Allele 1)**：通常是效应等位基因（Effect Allele）。 |
| `A2`    | **等位基因2 (Allele 2)**：通常是参考等位基因（Reference Allele）。 |
| `P`     | **P值 (P-value)**：衡量SNP与性状关联显著性的统计指标，值越小关联性越强。 |
| `BETA`  | **效应值 (Effect Size)**：表示等位基因`A1`每增加一个拷贝时，对性状的平均影响大小和方向。 |
| `SE`    | **标准误 (Standard Error)**：`BETA`值的标准误差，反映了效应值估计的精度。 |
| `FRQ`   | **频率 (Frequency)**：效应等位基因（`A1`）在研究人群中的频率。 |
| `N`     | **样本量 (Sample Size)**：用于该SNP关联分析的总样本数量。 |

---

## 🚀 用法指南

**重要提示：** 在运行任何脚本之前，请先为所有 `.sh` 脚本文件添加可执行权限。

```bash
sudo chmod +x *.sh
```

### 1. 清洗FinnGen R12数据

> **注意：** 执行前请确保当前工作目录下只有需要处理的FinnGen数据文件。

#### 方案A：标准清洗 + 补充样本量

此脚本会将FinnGen数据清洗为标准列名，并根据目录下的 `finnGen_R12.xlsx` 文件通过 `num_cases` + `num_controls` 来计算并填充 `N` 列。

```bash
# 将下载的芬兰数据和 finnGen_R12.xlsx 放入当前目录
./finn_clean.sh
```

#### 方案B：增强清洗 (推荐)

此脚本在方案A的基础上，增加了更严格的质控步骤，以提高数据质量：
- **过滤P值**：移除不在 `(0, 1]` 区间内的无效P值。
- **过滤等位基因**：只保留非链模糊（strand-unambiguous）的SNP（即排除`A/T`和`G/C`这类易混淆的SNP）。
- **确保等位基因一致性**。

```bash
# 将下载的芬兰数据放入当前目录
./finn_clean_plus.sh
```

---

### 2. 通用格式化与数据预览

#### 清洗其他GWAS数据（仅重置列名）

此脚本用于将任意来源的GWAS数据格式化为本项目的标准列名。

> **警告：** 使用前，您必须**手动修改 `format_sumstats.sh` 脚本**，使其内部的列名映射关系与您的原始文件相匹配。如果原始数据中没有样本量（`N`）列，您也可以在脚本中直接为所有行硬编码一个固定的样本量。

```bash
# 示例：处理名为 my_gwas.txt 的文件
./format_sumstats.sh my_gwas.txt
```

#### 查看数据结构

使用此脚本可以快速预览任何数据文件的前几行，方便您了解其列结构，以便正确修改格式化脚本。

```bash
# 示例：查看 my_gwas.txt 的文件头
./format_sumstats_preview.sh my_gwas.txt
```

---

### 3. 基因组坐标系转换

> **前提：** 用于转换的 `*.txt` 文件必须是已经过上述清洗、具有标准列名的GWAS数据。

#### 单文件转换

- **`hg38` 转 `hg37`**
  ```bash
  ./38to37.sh your_standard_gwas_file.txt
  ```

- **`hg37` 转 `hg38`**
  ```bash
  ./37to38.sh your_standard_gwas_file.txt
  ```

#### 批量文件转换

- **批量 `hg38` 转 `hg37`**
  ```bash
  # /path/to/your/folder 是存放所有 .txt 格式标准GWAS文件的文件夹路径
  ./38to37cycle.sh /path/to/your/folder
  ```
  
- **批量 `hg37` 转 `hg38`**
  ```bash
  # /path/to/your/folder 是存放所有 .txt 格式标准GWAS文件的文件夹路径
  ./37to38cycle.sh /path/to/your/folder
  ```

---

### 4. IEU VCF格式转为常规GWAS格式

此 `R` 脚本 (`vcf2gwas.R`) 用于将从 IEU OpenGWAS 等来源下载的 VCF 格式的摘要统计数据，转换为本项目所定义的标准GWAS格式。

> **说明：** 脚本会从VCF文件的`INFO`和`FORMAT`字段中提取必要的GWAS信息（如BETA, SE, P, AF等），并整理成标准的表格形式。

```bash
# 运行R脚本进行格式转换
# 使用前请确保您的Conda环境中已包含R及相关依赖包
# 示例:
# --vcf: 输入的VCF文件路径 (可以是 .vcf 或 .vcf.gz)
# --out: 输出的标准GWAS文件名

Rscript vcf2gwas.R --vcf ieu-a-2.vcf.gz --out ieu-a-2_gwas.txt
```
```
