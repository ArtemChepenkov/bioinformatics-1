#!/usr/bin/env bash
# =============================================================================
#  mapping_quality.sh
#  "Алгоритм оценки качества картирования" на чистом bash — реализация
#  блок-схемы из задания со всеми элементами и выводом "OK / not OK".
#
#  Блок-схема (Алгоритм получения генетических вариантов):
#
#     FASTQ ─> FastQC ─> (rename & save QC-report)
#       │
#     bwa index (ref)
#       │
#     bwa mem ─> samtools view ─> samtools flagstat ─> parse %mapped
#       │
#     %mapped > 90% ? ── no ──> Write "not OK"  (стоп)
#       │ yes
#     Write "OK" ─> samtools sort ─> freebayes ─> VCF ─> Write "Finished"
#
#  Использование:
#    mapping_quality.sh -r REF.fa -1 R1.fastq.gz -2 R2.fastq.gz \
#                       [-o OUTDIR] [-s SAMPLE] [-t THREADS] [-m MIN_MAPPED]
#
#  По умолчанию: -o results  -s sample  -t 4  -m 90
# =============================================================================
set -euo pipefail

# ----------------------------- параметры -------------------------------------
REF=""
R1=""
R2=""
OUTDIR="results"
SAMPLE="sample"
THREADS=4
MIN_MAPPED=90

usage() {
    grep '^#' "$0" | sed 's/^#//'
    exit "${1:-0}"
}

while getopts ":r:1:2:o:s:t:m:h" opt; do
    case "$opt" in
        r) REF="$OPTARG" ;;
        1) R1="$OPTARG" ;;
        2) R2="$OPTARG" ;;
        o) OUTDIR="$OPTARG" ;;
        s) SAMPLE="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        m) MIN_MAPPED="$OPTARG" ;;
        h) usage 0 ;;
        \?) echo "Неизвестная опция: -$OPTARG" >&2; usage 1 ;;
        :)  echo "Опция -$OPTARG требует аргумент" >&2; usage 1 ;;
    esac
done

# каталог скрипта (чтобы найти parse_flagstat.sh рядом)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------- проверки --------------------------------------
for v in REF R1 R2; do
    if [ -z "${!v}" ]; then
        echo "ERROR: не задан обязательный параметр -$([ "$v" = REF ] && echo r || echo "${v#R}") ($v)" >&2
        usage 1
    fi
done
for f in "$REF" "$R1" "$R2"; do
    [ -f "$f" ] || { echo "ERROR: файл не найден: $f" >&2; exit 1; }
done
for tool in fastqc bwa samtools freebayes; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: не найден инструмент: $tool" >&2; exit 1; }
done

mkdir -p "$OUTDIR" "$OUTDIR/fastqc"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

SAM="$OUTDIR/$SAMPLE.sam"
BAM="$OUTDIR/$SAMPLE.bam"
FLAGSTAT="$OUTDIR/$SAMPLE.flagstat.txt"
SORTED="$OUTDIR/$SAMPLE.sorted.bam"
VCF="$OUTDIR/$SAMPLE.vcf"
STATUS="$OUTDIR/$SAMPLE.qc_status.txt"

# ----------------------------- 1. FastQC -------------------------------------
log "Шаг 1/8: FastQC — контроль качества ридов"
fastqc -t "$THREADS" -o "$OUTDIR/fastqc" "$R1" "$R2"
log "  QC-отчёты сохранены в $OUTDIR/fastqc/"

# ----------------------------- 2. bwa index ----------------------------------
if [ ! -f "$REF.bwt" ]; then
    log "Шаг 2/8: bwa index — индексирование референса"
    bwa index "$REF"
else
    log "Шаг 2/8: индекс bwa уже существует — пропуск"
fi
[ -f "$REF.fai" ] || samtools faidx "$REF"

# ----------------------------- 3. bwa mem ------------------------------------
log "Шаг 3/8: bwa mem — картирование ридов на референс"
RG="@RG\tID:$SAMPLE\tSM:$SAMPLE\tPL:ILLUMINA\tLB:$SAMPLE"
bwa mem -t "$THREADS" -R "$RG" "$REF" "$R1" "$R2" > "$SAM"

# ----------------------------- 4. samtools view ------------------------------
log "Шаг 4/8: samtools view — SAM -> BAM"
samtools view -@ "$THREADS" -bS "$SAM" > "$BAM"

# ----------------------------- 5. samtools flagstat --------------------------
log "Шаг 5/8: samtools flagstat — статистика картирования"
samtools flagstat "$BAM" > "$FLAGSTAT"
cat "$FLAGSTAT"

# ----------------------------- 6. parse %mapped ------------------------------
log "Шаг 6/8: разбор flagstat — извлечение % картированных ридов"
PCT="$("$SCRIPT_DIR/parse_flagstat.sh" "$FLAGSTAT")"
log "  Картировано: ${PCT}%"

# ----------------------------- 7. решение OK / not OK ------------------------
# Сравнение дробных чисел через awk (bash целочисленный)
IS_OK="$(awk -v p="$PCT" -v t="$MIN_MAPPED" 'BEGIN { print (p >= t) ? 1 : 0 }')"

if [ "$IS_OK" -ne 1 ]; then
    echo "not OK (${PCT}% mapped < ${MIN_MAPPED}%)" | tee "$STATUS"
    log "Качество картирования НИЖЕ порога — пайплайн остановлен (варианты не вызываются)."
    exit 2
fi
echo "OK (${PCT}% mapped >= ${MIN_MAPPED}%)" | tee "$STATUS"

# ----------------------------- 8. sort + freebayes --------------------------
log "Шаг 7/8: samtools sort — координатная сортировка BAM"
samtools sort -@ "$THREADS" -o "$SORTED" "$BAM"
samtools index "$SORTED"

log "Шаг 8/8: freebayes — коллинг генетических вариантов"
freebayes -f "$REF" "$SORTED" > "$VCF"

VARIANTS="$(grep -vc '^#' "$VCF" || true)"
log "Finished. Найдено вариантов: $VARIANTS. VCF: $VCF"
echo "Finished"
