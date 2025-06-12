clean_gwas \
自用自用自用 \
创建环境 \
git clone https://github.com/Locco2011/clean_gwas.git \
cd clean_gwas \
conda env create -f environment.yml \
conda activate clean \
Python 3.10 \
Linux Ubuntu 20.04.6 LTS \
标准列名为'CHR', 'BP', 'SNP', 'A1', 'A2', 'P', 'BETA', 'SE', 'FRQ', 'N' \
=============================更新===================================== \
cd clean_gwas
git pull
=============================用法===================================== \
sudo chmod +x *.sh \
清洗芬兰R12(确保当前目录下只有芬兰数据)(下载之后放入当前目录，./finn_clean.sh)，标准列名+补充样本(根据目录下的finnGen_R12.xlsx中num_cases+num_controls=N) \
清洗芬兰R12(确保当前目录下只有芬兰数据)(过滤P值，移除那些不在 (0, 1] 区间内的无效P值；过滤等位基因，只保留那些非链模糊（strand-unambiguous）的SNP；确保等位基因的一致性，放入当前目录，./finn_clean_plus.sh) \
清洗其他（仅列名重置），请修改format_sumstats.sh(如果N列原gwas中有对应行，则为行名；否则可以直接在*.sh中增加样本) \
查看数据结构，请修改format_sumstats_preview.sh \
h38转为h37：./38to37.sh *.txt（此txt已根据上述清洗处理，仅列名重置） \
h37转为h38：./37to38.sh *.txt（此txt已根据上述清洗处理，仅列名重置） \
批量h37转为h38：./37to38cycle.sh /xx/xx/xx(后缀为.txt的标准列名gwas所在文件夹) \
批量h38转为h37：./38to37cycle.sh /xx/xx/xx(后缀为.txt的标准列名gwas所在文件夹) 

