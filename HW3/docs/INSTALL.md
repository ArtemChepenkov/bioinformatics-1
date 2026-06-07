# Установка и развёртывание фреймворка пайплайнов (GNU make)

В качестве фреймворка создания пайплайнов используется **GNU make** —
классический декларативный движок сборки. Пайплайн описывается как набор
*целей* (targets) с *зависимостями* (prerequisites); make сам строит граф
зависимостей (DAG), определяет порядок выполнения и пересобирает только
устаревшие шаги.

## Почему GNU make

* Установлен почти везде, не требует отдельной среды исполнения.
* Декларативная модель «цель ← зависимости ← рецепт» естественно описывает
  биоинформатический пайплайн (файл VCF зависит от sorted.bam, тот — от bam и т.д.).
* Автоматически распараллеливается (`make -j N`).
* Пересборка только изменённого (инкрементальность по времени модификации файлов).

## Установка фреймворка

### Linux (Ubuntu/Debian) или WSL

```bash
sudo apt update
sudo apt install -y make
make --version        # GNU Make 4.x
```

GNU make входит и в метапакет `build-essential`:

```bash
sudo apt install -y build-essential
```

### macOS

```bash
xcode-select --install      # ставит make вместе с инструментами разработчика
# либо: brew install make    (свежая версия как gmake)
```

### Без прав root (через conda)

```bash
conda install -c conda-forge make
```

## Установка биоинформатических инструментов пайплайна

Пайплайн вызывает внешние программы; их тоже нужно установить.

### Через apt (Ubuntu 22.04 / WSL) — использовалось в этой работе

```bash
sudo apt update
sudo apt install -y bwa samtools fastqc freebayes sra-toolkit graphviz make gcc
```

### Без root — через conda/bioconda

```bash
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O miniforge.sh
bash miniforge.sh -b -p ~/miniforge3
~/miniforge3/bin/mamba create -y -n hw3 -c bioconda -c conda-forge \
    bwa samtools fastqc freebayes sra-tools graphviz make
conda activate hw3
```

### Проверка

```bash
for t in make bwa samtools fastqc freebayes dot; do
  command -v "$t" >/dev/null && echo "OK   $t" || echo "MISS $t"
done
```

| Инструмент | Версия (в этой работе) | Роль в пайплайне |
|---|---|---|
| GNU make  | 4.3     | движок пайплайна |
| bwa       | 0.7.17  | индексирование + картирование (`bwa index`, `bwa mem`) |
| samtools  | 1.13    | `view` / `sort` / `flagstat` / `index` / `faidx` |
| fastqc    | 0.11.9  | контроль качества ридов |
| freebayes | 1.3.6   | коллинг генетических вариантов (VCF) |
| graphviz  | 2.43    | `dot` — рендеринг DAG пайплайна |

## Запуск «Hello world» (проверка фреймворка)

```bash
cd hello
make            # соберёт hello.txt -> выведет "Hello, world!"
make clean
```

## Запуск основного пайплайна

Из корня проекта:

```bash
# весь пайплайн (FastQC + bwa mem + QC-gate + freebayes -> VCF)
make -f pipeline/Makefile all

# визуализация DAG (results/dag.svg, results/dag.png)
make -f pipeline/Makefile dag

# параллельно в 8 потоков, порог картирования 95 %
make -f pipeline/Makefile all -j 8 THREADS=8 MIN_MAPPED=95
```
