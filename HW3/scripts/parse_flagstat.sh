#!/usr/bin/env bash
# =============================================================================
#  parse_flagstat.sh
#  Разбор результата `samtools flagstat` и вывод процента картированных ридов.
#
#  Соответствует пункту задания:
#    "Написать скрипт (bash/Python) разбора результатов samtools flagstat
#     для получения % картированных ридов".
#
#  Использование:
#    parse_flagstat.sh <flagstat.txt>       # из файла
#    samtools flagstat in.bam | parse_flagstat.sh -   # из stdin
#
#  Вывод: одна строка — процент картированных ридов с двумя знаками (напр. 99.83)
#
#  % считается самостоятельно как mapped / total * 100 (а не берётся из
#  готовой подписи "(99.83% : N/A)") — так разбор устойчив к версии samtools.
# =============================================================================
set -euo pipefail

infile="${1:--}"

if [ "$infile" = "-" ]; then
    data="$(cat)"
else
    if [ ! -f "$infile" ]; then
        echo "ERROR: файл не найден: $infile" >&2
        exit 1
    fi
    data="$(cat "$infile")"
fi

# Строка вида: "1099585 + 0 in total (QC-passed reads + QC-failed reads)"
total="$(printf '%s\n' "$data" | awk '/ in total/ {print $1; exit}')"

# Строка вида: "1097662 + 0 mapped (99.83% : N/A)".
# Берём первое вхождение " mapped (" — это суммарный mapped
# (в samtools >=1.13 ниже идёт ещё "primary mapped", его пропускаем).
mapped="$(printf '%s\n' "$data" | awk '/ mapped \(/ {print $1; exit}')"

if [ -z "$total" ] || [ -z "$mapped" ]; then
    echo "ERROR: не удалось разобрать flagstat (total='$total' mapped='$mapped')" >&2
    exit 1
fi

if [ "$total" -eq 0 ]; then
    echo "ERROR: всего ридов = 0, деление на ноль" >&2
    exit 1
fi

awk -v m="$mapped" -v t="$total" 'BEGIN { printf "%.2f\n", (m / t) * 100 }'
