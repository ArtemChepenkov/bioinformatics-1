# Домашнее задание 3 — Построение пайплайна получения генетических вариантов

**Чепеньков Артём Игоревич, ФИТ НГУ, 23213**
Пайплайн: контроль качества → картирование → оценка качества картирования →
коллинг генетических вариантов.

## Выбранный стек

| Что | Выбор |
|---|---|
| Данные секвенирования | Illumina MiSeq, **paired-end** (E. coli K-12 MG1655) |
| Картирование | **bwa mem** (<https://github.com/lh3/bwa>) |
| Фреймворк пайплайнов | **GNU make** (<https://www.gnu.org/software/make/>) |
| Контроль качества | FastQC |
| Работа с SAM/BAM | samtools |
| Коллинг вариантов | freebayes |
| Визуализация DAG | graphviz (`dot`) |

## Данные

* **Риды (NCBI SRA / ENA):** `ERR15404843` — E. coli K-12, Illumina MiSeq, paired-end,
  278 922 пары ридов (~250 bp), покрытие ~30×.
  * ENA: <https://www.ebi.ac.uk/ena/browser/view/ERR15404843>
  * NCBI SRA: <https://www.ncbi.nlm.nih.gov/sra/?term=ERR15404843>
  * Прямые FASTQ:
    `ftp.sra.ebi.ac.uk/vol1/fastq/ERR154/043/ERR15404843/ERR15404843_{1,2}.fastq.gz`
* **Референсный геном:** E. coli K-12 MG1655, сборка **GCF_000005845.2 (ASM584v2)**,
  4 641 652 bp. <https://www.ncbi.nlm.nih.gov/assembly/GCF_000005845.2/>

Сами FASTQ/референс в репозиторий не кладутся (большой размер, см. `.gitignore`) —
их можно скачать скриптом `scripts/download_data.sh`.

## Структура репозитория

```
HW3/
├── README.md                  # этот файл
├── Assignment 3.pdf           # условие задания
├── docs/
│   ├── INSTALL.md             # установка фреймворка и инструментов (п. 10)
│   └── visualization.md       # описание визуализации DAG vs блок-схема (п. 14)
├── scripts/
│   ├── download_data.sh       # скачивание ридов (SRA/ENA) и референса
│   ├── parse_flagstat.sh      # разбор samtools flagstat -> %mapped (п. 7)
│   ├── mapping_quality.sh     # алгоритм оценки качества на чистом bash (п. 8)
│   └── make2dot.py            # авто-визуализация DAG из базы зависимостей make
├── hello/
│   └── Makefile               # тест "Hello world" на фреймворке (п. 11)
├── pipeline/
│   └── Makefile               # пайплайн оценки качества + коллинга (п. 12)
└── results/                   # результаты прогона на реальных данных
    ├── sample.flagstat.txt    # вывод samtools flagstat (п. 3)
    ├── sample.mapped_pct.txt  # извлечённый %mapped
    ├── sample.qc_status.txt   # OK / not OK
    ├── sample.vcf             # найденные варианты
    ├── pipeline_results.txt   # сводка результатов (п. 11)
    ├── dag.dot / dag.svg / dag.png   # визуализация пайплайна (п. 13)
    └── fastqc/                # HTML-отчёты FastQC
└── logs/
    ├── hello_world.log        # лог теста Hello world
    └── pipeline.log           # лог прогона пайплайна (п. 8, 12)
```

## Быстрый старт

```bash
# 0. Установить фреймворк и инструменты — см. docs/INSTALL.md
# 1. Скачать данные
bash scripts/download_data.sh

# 2. Тест фреймворка
cd hello && make && cd ..

# 3. Весь пайплайн на реальных данных
make -f pipeline/Makefile all THREADS=8

# 4. Визуализация DAG
make -f pipeline/Makefile dag
```

Альтернатива — тот же алгоритм одним bash-скриптом (без make):

```bash
scripts/mapping_quality.sh -r ref/ecoli.fa \
    -1 reads/sample_1.fastq.gz -2 reads/sample_2.fastq.gz \
    -o results -t 8 -m 90
```

## Алгоритм (блок-схема из задания)

```
FASTQ ─> FastQC ─> (сохранить QC-отчёт)
  │
bwa index (референс)
  │
bwa mem ─> samtools view ─> samtools flagstat ─> разбор %mapped
  │
%mapped > 90 % ? ── нет ──> "not OK"  (стоп)
  │ да
"OK" ─> samtools sort ─> freebayes ─> VCF ─> "Finished"
```

## Соответствие пунктам задания

| № | Что требуется | Где |
|---|---|---|
| 1 | Ссылка на риды из SRA | этот README (раздел «Данные») |
| 2 | bash-скрипт с алгоритмом | `scripts/mapping_quality.sh` |
| 3 | Результат `samtools flagstat` | `results/sample.flagstat.txt` |
| 4 | Скрипт разбора flagstat | `scripts/parse_flagstat.sh` |
| 6 | Инструкция по установке фреймворка | `docs/INSTALL.md` |
| 7 | Код «Hello world» на фреймворке | `hello/Makefile` |
| 8 | Результаты и логи прогона | `logs/`, `results/` |
| 10 | Код пайплайна на фреймворке | `pipeline/Makefile` |
| 11 | Выведенные результаты прогона | `results/pipeline_results.txt` |
| 12 | Лог-файлы прогона | `logs/pipeline.log` |
| 13 | Визуализация пайплайна (граф. файл) | `results/dag.svg`, `results/dag.png` |
| 14 | Описание визуализации vs блок-схема | `docs/visualization.md` |
