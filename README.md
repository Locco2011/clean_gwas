#clean_gwas
#自用
#创建环境
#conda env create -f environment.yml
#清洗芬兰R12(下载之后放入当前目录，./finn_clean.sh)，标准列名+补充样本
#清洗芬兰R12(首先用R包munge_sumstats把38转为37；过滤P值，移除那些不在 (0, 1] 区间内的无效P值；过滤等位基因，只保留那些非链模糊（strand-unambiguous）的SNP；确保等位基因的一致性，放入当前目录，./finn_clean_plus.sh)
#sudo chmod +x *.sh
#清洗其他，请修改format_sumstats.sh
#查看数据，请修改format_sumstats.sh
#python 3.10
#Linux Ubuntu20.04.6 LTS
#标准列名为'CHR', 'BP', 'SNP', 'A1', 'A2', 'P', 'BETA', 'SE', 'FRQ', 'N'
