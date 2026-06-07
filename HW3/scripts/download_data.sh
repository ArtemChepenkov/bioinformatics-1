#!/usr/bin/env bash
# =============================================================================
#  download_data.sh
#  Скачивание входных данных пайплайна:
#    * референсный геном E. coli K-12 MG1655 (GCF_000005845.2 / ASM584v2)
#    * paired-end Illumina-риды ERR15404843 из NCBI SRA (зеркало ENA)
#
#  Запуск из корня проекта:
#    bash scripts/download_data.sh
# =============================================================================
set -euo pipefail

ACC="ERR15404843"     # E. coli K-12, Illumina MiSeq, paired-end
REF_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/GCF_000005845.2_ASM584v2_genomic.fna.gz"

mkdir -p ref reads

echo "=== Референс E. coli (GCF_000005845.2) ==="
if [ ! -f ref/ecoli.fa ]; then
    wget -q "$REF_URL" -O ref/ecoli.fna.gz
    gunzip -f ref/ecoli.fna.gz
    mv ref/ecoli.fna ref/ecoli.fa
fi
ls -lh ref/ecoli.fa

echo "=== Риды $ACC (paired-end) из ENA ==="
# ENA-зеркало SRA: прямые FASTQ по ftp (sra-toolkit не требуется)
P="${ACC:0:6}/043/${ACC}"   # путь ENA: <первые 6>/<последние 2-3 цифры с ведущими нулями>/<acc>
B="ftp.sra.ebi.ac.uk/vol1/fastq/${ACC:0:6}/043/${ACC}"
if [ ! -f reads/sample_1.fastq.gz ]; then
    wget -q "ftp://${B}/${ACC}_1.fastq.gz" -O reads/sample_1.fastq.gz
    wget -q "ftp://${B}/${ACC}_2.fastq.gz" -O reads/sample_2.fastq.gz
fi
ls -lh reads/

echo "Готово."

# Примечание: альтернативно через sra-toolkit:
#   prefetch "$ACC"
#   fasterq-dump --split-files -O reads "$ACC"
#   gzip reads/${ACC}_1.fastq reads/${ACC}_2.fastq
