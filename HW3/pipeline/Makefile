# =============================================================================
#  Makefile — пайплайн "оценки качества картирования" и коллинга вариантов.
#  Фреймворк создания пайплайнов: GNU make.
#  HW3, ФИТ НГУ, весенний семестр 2026.
#
#  Запуск из КОРНЯ проекта:
#      make -f pipeline/Makefile all          # весь пайплайн
#      make -f pipeline/Makefile fastqc       # только FastQC
#      make -f pipeline/Makefile dag          # визуализация DAG (dag.svg/png)
#      make -f pipeline/Makefile clean        # удалить результаты
#      make -f pipeline/Makefile help         # справка
#
#  Параметры можно переопределить из командной строки, например:
#      make -f pipeline/Makefile all R1=reads/x_1.fq.gz R2=reads/x_2.fq.gz MIN_MAPPED=95
#
#  DAG (поток данных вход -> выход):
#      reads ─┬─> FastQC ───────────────────────────> QC-отчёты
#             └─> bwa mem ─> view ─> flagstat ─> parse %mapped ─> QC-gate
#      ref ─> bwa index ──┘                                          │ (>= MIN_MAPPED)
#                                              sort ─> freebayes ─> VCF ─> FINISHED
# =============================================================================

# ----------------------------- параметры -------------------------------------
SAMPLE      ?= sample
REF         ?= ref/ecoli.fa
R1          ?= reads/sample_1.fastq.gz
R2          ?= reads/sample_2.fastq.gz
THREADS     ?= 4
MIN_MAPPED  ?= 90
OUT         ?= results
SCRIPTS     := scripts

# Read group для bwa mem
RG          := @RG\tID:$(SAMPLE)\tSM:$(SAMPLE)\tPL:ILLUMINA\tLB:$(SAMPLE)

# ----------------------------- производные имена ------------------------------
IDX        := $(REF).bwt
FAI        := $(REF).fai
FQC_DONE   := $(OUT)/fastqc/.done
SAM        := $(OUT)/$(SAMPLE).sam
BAM        := $(OUT)/$(SAMPLE).bam
FLAGSTAT   := $(OUT)/$(SAMPLE).flagstat.txt
MAPPED_PCT := $(OUT)/$(SAMPLE).mapped_pct.txt
QC_STATUS  := $(OUT)/$(SAMPLE).qc_status.txt
SORTED     := $(OUT)/$(SAMPLE).sorted.bam
VCF        := $(OUT)/$(SAMPLE).vcf
DONE       := $(OUT)/$(SAMPLE).FINISHED

.PHONY: all fastqc dag clean help
.DELETE_ON_ERROR:          # при ошибке рецепта удалять недоделанный файл-цель

all: $(DONE)

# --- 1. Индексирование референса (bwa index) ---------------------------------
$(IDX): $(REF)
	@echo ">> [index] bwa index $(REF)"
	bwa index $(REF)

$(FAI): $(REF)
	samtools faidx $(REF)

# --- 2. FastQC (контроль качества сырых ридов) -------------------------------
fastqc: $(FQC_DONE)
$(FQC_DONE): $(R1) $(R2) | $(OUT)
	@echo ">> [fastqc] контроль качества ридов"
	mkdir -p $(OUT)/fastqc
	fastqc -t $(THREADS) -o $(OUT)/fastqc $(R1) $(R2)
	@touch $@

# --- 3. Картирование: bwa mem -> SAM -----------------------------------------
$(SAM): $(IDX) $(R1) $(R2) | $(OUT)
	@echo ">> [map] bwa mem -> SAM"
	bwa mem -t $(THREADS) -R '$(RG)' $(REF) $(R1) $(R2) > $(SAM)

# --- 4. samtools view: SAM -> BAM --------------------------------------------
$(BAM): $(SAM)
	@echo ">> [view] SAM -> BAM"
	samtools view -@ $(THREADS) -bS $(SAM) > $(BAM)

# --- 5. samtools flagstat: статистика картирования ---------------------------
$(FLAGSTAT): $(BAM)
	@echo ">> [flagstat] статистика выравнивания"
	samtools flagstat $(BAM) > $(FLAGSTAT)

# --- 6. Разбор flagstat -> % картированных -----------------------------------
$(MAPPED_PCT): $(FLAGSTAT)
	@echo ">> [parse] извлечение %mapped"
	$(SCRIPTS)/parse_flagstat.sh $(FLAGSTAT) > $(MAPPED_PCT)
	@echo "   %mapped = $$(cat $(MAPPED_PCT))"

# --- 7. QC-gate: решение OK / not OK -----------------------------------------
#  Если %mapped < MIN_MAPPED — пишем "not OK" и останавливаем пайплайн (exit 1).
$(QC_STATUS): $(MAPPED_PCT)
	@pct=$$(cat $(MAPPED_PCT)); \
	ok=$$(awk -v p=$$pct -v t=$(MIN_MAPPED) 'BEGIN{print (p>=t)?1:0}'); \
	if [ "$$ok" -eq 1 ]; then \
	    echo "OK ($$pct% mapped >= $(MIN_MAPPED)%)" | tee $(QC_STATUS); \
	else \
	    echo "not OK ($$pct% mapped < $(MIN_MAPPED)%)" | tee $(QC_STATUS); \
	    echo "QC-gate: процент картирования ниже порога — пайплайн остановлен." >&2; \
	    exit 1; \
	fi

# --- 8. Сортировка BAM (только если QC прошёл) -------------------------------
$(SORTED): $(BAM) $(QC_STATUS)
	@echo ">> [sort] координатная сортировка BAM"
	samtools sort -@ $(THREADS) -o $(SORTED) $(BAM)
	samtools index $(SORTED)

# --- 9. Коллинг вариантов: freebayes -> VCF ----------------------------------
$(VCF): $(SORTED) $(FAI)
	@echo ">> [call] freebayes -> VCF"
	freebayes -f $(REF) $(SORTED) > $(VCF)

# --- 10. Маркер завершения ---------------------------------------------------
$(DONE): $(VCF) $(FQC_DONE)
	@echo "Finished: $$(date)" > $(DONE)
	@echo ">> [done] пайплайн завершён. VCF: $(VCF)"

$(OUT):
	mkdir -p $(OUT)

# --- Визуализация DAG автоматическим инструментом ----------------------------
#  make -Bnd выводит внутреннюю базу зависимостей make; make2dot.py превращает
#  её в граф Graphviz, dot рендерит SVG и PNG.
dag: $(OUT)/dag.svg
$(OUT)/dag.svg: pipeline/Makefile $(SCRIPTS)/make2dot.py | $(OUT)
	@echo ">> [dag] генерация графа пайплайна из базы зависимостей make"
	$(MAKE) -Bnd -f pipeline/Makefile all 2>/dev/null | \
	    python3 $(SCRIPTS)/make2dot.py > $(OUT)/dag.dot
	dot -Tsvg $(OUT)/dag.dot -o $(OUT)/dag.svg
	dot -Tpng $(OUT)/dag.dot -o $(OUT)/dag.png
	@echo "   создано: $(OUT)/dag.dot, $(OUT)/dag.svg, $(OUT)/dag.png"

clean:
	rm -rf $(OUT)
	rm -f $(REF).amb $(REF).ann $(REF).bwt $(REF).pac $(REF).sa $(REF).fai

help:
	@echo "Цели:"
	@echo "  all     — весь пайплайн (FastQC + картирование + QC-gate + VCF)"
	@echo "  fastqc  — только контроль качества ридов"
	@echo "  dag     — визуализация DAG пайплайна (results/dag.svg, dag.png)"
	@echo "  clean   — удалить результаты и индексы"
	@echo "Параметры: REF, R1, R2, SAMPLE, THREADS, MIN_MAPPED, OUT"
