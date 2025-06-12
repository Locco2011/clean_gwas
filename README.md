#clean_gwas \
#自用 \
#创建环境 \
#wget https://github.com/Locco2011/clean_gwas \
#cd clean_gwas \
#conda env create -f environment.yml \
#conda activate clean 
==================================================================================
#清洗芬兰R12(下载之后放入当前目录，./finn_clean.sh)，标准列名+补充样本(根据目录下的finnGen_R12.xlsx中num_cases+num_controls=N) \
#清洗芬兰R12(首先用R包munge_sumstats把38转为37；过滤P值，移除那些不在 (0, 1] 区间内的无效P值；过滤等位基因，只保留那些非链模糊（strand-unambiguous）的SNP；确保等位基因的一致性，放入当前目录，./finn_clean_plus.sh) \
#sudo chmod +x *.sh \
#清洗其他，请修改format_sumstats.sh \
#查看数据，请修改format_sumstats.sh \
#Python 3.10 \
#Linux Ubuntu20.04.6 LTS \
#标准列名为'CHR', 'BP', 'SNP', 'A1', 'A2', 'P', 'BETA', 'SE', 'FRQ', 'N' 
===================================================================================
#SE = sqrt(((BETA)^2)/qchisq(P,1,lower.tail=F)) \
#SE = abs(log(OR)/qnorm(P/2)) \
#Z = -qnorm(P/2) \
#BETA = log(OR) \
#OR = exp(BETA) \
#upper bound of OR = OR + se(OR) x 1.96 \
#lower bound of OR = OR - se(OR) x 1.96 \
#Log(upper bound of OR) = upper bound of BETA \
#Log(lower bound of OR) = lower bound of BETA \
#upper bound of BETA = BETA + SE*(BETA) x 1.96 \
#lower bound of BETA = BETA - SE*(BETA) x 1.96 
