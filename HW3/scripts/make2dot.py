#!/usr/bin/env python3
# =============================================================================
#  make2dot.py
#  Автоматическая визуализация DAG пайплайна, построенного на GNU make.
#
#  GNU make не имеет встроенного рендерера графа, но умеет печатать свою
#  внутреннюю базу зависимостей в режиме отладки трассировки:
#      make -Bnd all
#  (-B: считать все цели устаревшими, -n: ничего не выполнять (dry-run),
#   -d: отладочный вывод с разбором дерева зависимостей).
#
#  Этот скрипт разбирает такой вывод (строки вида
#      "Considering target file 'X'."
#      "Finished prerequisites of target file 'X'.")
#  и строит граф Graphviz (DOT): ребро prereq -> target, т.е. поток данных
#  идёт от входов к выходам — как в блок-схеме алгоритма.
#  Алгоритм — стек, как в утилите makefile2graph.
#
#  Использование:
#      make -Bnd -f pipeline/Makefile all 2>/dev/null | python3 make2dot.py > dag.dot
#      dot -Tsvg dag.dot -o dag.svg
# =============================================================================
import sys
import re

CONSIDER = re.compile(r"Considering target file '(.+?)'\.")
FINISHED = re.compile(r"Finished prerequisites of target file '(.+?)'\.")
PRUNING  = re.compile(r"Pruning file '(.+?)'\.")

# каталоги/файлы, которые в граф не выносим (внутренние артефакты make)
SKIP = ("Makefile", "makefile")

PHONY = ("all", "fastqc", "dag", "clean", "help")


def is_phony_like(name: str) -> bool:
    return name in PHONY


def is_noise(name: str) -> bool:
    # order-only каталог-цель (напр. "results") без расширения и пути — шум
    return ("/" not in name) and ("." not in name) and not is_phony_like(name)


def main() -> None:
    stack = []
    nodes = set()
    edges = set()

    for line in sys.stdin:
        m = CONSIDER.search(line)
        if m:
            target = m.group(1)
            if not target.endswith(SKIP):
                nodes.add(target)
                if stack:
                    edges.add((stack[-1], target))  # (parent target, prereq)
            stack.append(target)
            continue
        # "Pruning file 'X'." — X уже рассматривался ранее: вложенного
        # Considering->Finished не будет, но это всё равно зависимость
        # текущей цели на вершине стека. Восстанавливаем ребро.
        m = PRUNING.search(line)
        if m:
            target = m.group(1)
            if not target.endswith(SKIP):
                nodes.add(target)
                if stack:
                    edges.add((stack[-1], target))
            continue
        m = FINISHED.search(line)
        if m:
            if stack:
                stack.pop()

    print("digraph pipeline {")
    print("  rankdir=TB;")
    print('  graph [fontname="Helvetica", labelloc="t", '
          'label="Пайплайн HW3 (GNU make) — DAG зависимостей"];')
    print('  node  [fontname="Helvetica", fontsize=10];')
    print('  edge  [color="#555555"];')

    for n in sorted(nodes):
        if is_noise(n):
            continue
        if is_phony_like(n):
            shape, fill = "ellipse", "#d7ecd9"      # .PHONY-цели
        elif n.endswith((".fastq.gz", ".fq.gz", ".fa", ".fasta")):
            shape, fill = "box", "#fdf3d0"          # входные данные
        elif n.endswith((".vcf", ".FINISHED")):
            shape, fill = "box", "#f6d6d6"          # финальные выходы
        else:
            shape, fill = "box", "#e8eef7"          # промежуточные файлы
        print(f'  "{n}" [shape={shape}, style="rounded,filled", fillcolor="{fill}"];')

    for parent, prereq in sorted(edges):
        if parent.endswith(SKIP) or prereq.endswith(SKIP):
            continue
        if is_noise(parent) or is_noise(prereq):
            continue
        # ребро prereq -> target: данные текут от входа к выходу
        print(f'  "{prereq}" -> "{parent}";')

    print("}")


if __name__ == "__main__":
    main()
