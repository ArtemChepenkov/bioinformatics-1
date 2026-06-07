# =============================================================================
#  "Hello world" на GNU make — знакомство с базовыми возможностями фреймворка.
#
#  Демонстрирует:
#    * цели (targets) и зависимости (prerequisites)
#    * автоматическую переменную $@ (имя текущей цели)
#    * маленький DAG: greeting.txt + name.txt -> hello.txt -> all
#    * .PHONY-цели (all, clean), которые не создают одноимённых файлов
#
#  Запуск:
#    make            # или: make all
#    make clean
#    make -Bnd all   # посмотреть базу зависимостей (для визуализации DAG)
# =============================================================================

.PHONY: all clean

all: hello.txt
	@echo "=== Результат ==="
	@cat hello.txt

# Два независимых "входных" файла — их можно собрать параллельно (make -j)
greeting.txt:
	@echo "Hello" > $@
	@echo "Создан $@"

name.txt:
	@echo "world" > $@
	@echo "Создан $@"

# Цель зависит от двух предыдущих — make сам построит их раньше
hello.txt: greeting.txt name.txt
	@echo "$$(cat greeting.txt), $$(cat name.txt)!" > $@
	@echo "Создан $@"

clean:
	rm -f greeting.txt name.txt hello.txt
	@echo "Очищено"
