# ============================================
# НАСТРОЙКИ
# ============================================
VENV_DIR = venv
PYTHON = python3
PORT = 5005
APP = app.py
PID_FILE = flask.pid
LOG_FILE = flask.log
REQUIREMENTS = requirements.txt

# Цвета для вывода
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# ============================================
# ОСНОВНЫЕ КОМАНДЫ
# ============================================
.PHONY: help start stop restart status logs clean setup venv install test

# Основная цель
help:
	@echo "$(BLUE)=== Flask Web Server Management ===$(NC)"
	@echo ""
	@echo "$(YELLOW)Основные команды:$(NC)"
	@echo "  $(GREEN)make setup$(NC)     - установить зависимости и настроить проект"
	@echo "  $(GREEN)make start$(NC)     - запустить Flask сервер"
	@echo "  $(GREEN)make stop$(NC)      - остановить Flask сервер"
	@echo "  $(GREEN)make restart$(NC)   - перезапустить Flask сервер"
	@echo "  $(GREEN)make status$(NC)    - показать статус сервера"
	@echo "  $(GREEN)make logs$(NC)      - показать логи в реальном времени"
	@echo "  $(GREEN)make clean$(NC)     - остановить сервер и очистить временные файлы"
	@echo ""
	@echo "$(YELLOW)Разработка:$(NC)"
	@echo "  $(GREEN)make venv$(NC)      - создать виртуальное окружение"
	@echo "  $(GREEN)make install$(NC)   - установить зависимости из requirements.txt"
	@echo "  $(GREEN)make test$(NC)      - запустить тесты (если есть)"
	@echo ""
	@echo "$(YELLOW)Информация:$(NC)"
	@echo "  - Порт: $(PORT)"
	@echo "  - Приложение: $(APP)"
	@echo "  - Виртуальное окружение: $(VENV_DIR)"
	@echo ""

# Установка и настройка проекта
setup: venv install
	@echo "$(GREEN)✅ Проект настроен!$(NC)"
	@echo "$(BLUE)Для запуска сервера выполните:$(NC)"
	@echo "  make start"

# Создание виртуального окружения
venv:
	@if [ -d "$(VENV_DIR)" ]; then \
		echo "$(YELLOW)⚠️  Виртуальное окружение уже существует$(NC)"; \
	else \
		echo "$(BLUE)Создаю виртуальное окружение...$(NC)"; \
		$(PYTHON) -m venv $(VENV_DIR); \
		echo "$(GREEN)✅ Виртуальное окружение создано$(NC)"; \
	fi

# Активация venv (внутренняя функция)
_activate:
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "$(RED)❌ Виртуальное окружение не найдено!$(NC)"; \
		echo "$(BLUE)Выполните:$(NC) make setup"; \
		exit 1; \
	fi
	@. $(VENV_DIR)/bin/activate

# Установка зависимостей
install: _activate
	@echo "$(BLUE)Устанавливаю зависимости...$(NC)"
	@if [ -f "$(REQUIREMENTS)" ]; then \
		$(VENV_DIR)/bin/pip install -r $(REQUIREMENTS); \
	else \
		echo "$(YELLOW)⚠️  Файл requirements.txt не найден, устанавливаю Flask$(NC)"; \
		$(VENV_DIR)/bin/pip install flask; \
		echo "$(BLUE)Создаю requirements.txt...$(NC)"; \
		$(VENV_DIR)/bin/pip freeze > $(REQUIREMENTS) 2>/dev/null || echo "# Flask dependencies" > $(REQUIREMENTS); \
	fi
	@echo "$(GREEN)✅ Зависимости установлены$(NC)"

# Запуск сервера
start: _activate
	@if [ -f "$(PID_FILE)" ]; then \
		PID=$$(cat $(PID_FILE)); \
		if ps -p $$PID > /dev/null 2>&1; then \
			echo "$(YELLOW)⚠️  Сервер уже запущен (PID: $$PID)$(NC)"; \
			exit 1; \
		else \
			echo "$(YELLOW)⚠️  Обнаружен старый PID файл, удаляю...$(NC)"; \
			rm -f $(PID_FILE); \
		fi \
	fi
	
	@if [ ! -f "$(APP)" ]; then \
		echo "$(RED)❌ Файл $(APP) не найден!$(NC)"; \
		echo "$(BLUE)Создаю минимальное Flask приложение...$(NC)"; \
		echo 'from flask import Flask\n\napp = Flask(__name__)\n\n@app.route("/")\ndef hello():\n    return "🚀 Flask сервер работает!"\n\n@app.route("/health")\ndef health():\n    return {"status": "ok", "message": "Server is running"}\n\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=5000, debug=True)' > $(APP); \
		echo "$(GREEN)✅ Файл $(APP) создан$(NC)"; \
	fi
	
	@echo "$(BLUE)Запускаю Flask сервер...$(NC)"
	@echo "$(YELLOW)Порт:$(NC) $(PORT)"
	@echo "$(YELLOW)Приложение:$(NC) $(APP)"
	@echo "$(YELLOW)Режим:$(NC) development"
	
	@export FLASK_APP=$(APP); \
	export FLASK_ENV=development; \
	nohup $(VENV_DIR)/bin/python -m flask run --host=0.0.0.0 --port=$(PORT) > $(LOG_FILE) 2>&1 & \
	echo $$! > $(PID_FILE)
	
	@echo "$(GREEN)✅ Сервер запущен!$(NC)"
	@echo "$(BLUE)URL:$(NC) http://localhost:$(PORT)"
	@echo "$(BLUE)PID:$(NC) $$(cat $(PID_FILE))"
	@echo "$(BLUE)Логи:$(NC) $(LOG_FILE)"
	@echo ""
	@echo "$(YELLOW)Для остановки:$(NC) make stop"
	@echo "$(YELLOW)Для просмотра логов:$(NC) make logs"

# Остановка сервера
stop:
	@if [ ! -f "$(PID_FILE)" ]; then \
		echo "$(YELLOW)⚠️  Сервер не запущен$(NC)"; \
		exit 0; \
	fi
	
	@PID=$$(cat $(PID_FILE)); \
	echo "$(BLUE)Останавливаю сервер (PID: $$PID)...$(NC)"; \
	kill $$PID 2>/dev/null || true; \
	sleep 1; \
	\
	if ps -p $$PID > /dev/null 2>&1; then \
		echo "$(YELLOW)Принудительная остановка...$(NC)"; \
		kill -9 $$PID 2>/dev/null || true; \
	fi; \
	\
	rm -f $(PID_FILE); \
	echo "$(GREEN)✅ Сервер остановлен$(NC)"

# Перезапуск сервера
restart: stop
	@sleep 2
	@make start

# Статус сервера
status:
	@echo "$(BLUE)=== Статус Flask сервера ===$(NC)"
	@echo ""
	
	@# Проверка виртуального окружения
	@if [ -d "$(VENV_DIR)" ]; then \
		echo "$(GREEN)✅ Виртуальное окружение:$(NC) $(VENV_DIR)"; \
	else \
		echo "$(RED)❌ Виртуальное окружение:$(NC) не найдено"; \
	fi
	
	@# Проверка файла приложения
	@if [ -f "$(APP)" ]; then \
		echo "$(GREEN)✅ Приложение:$(NC) $(APP)"; \
	else \
		echo "$(RED)❌ Приложение:$(NC) не найдено"; \
	fi
	
	@# Проверка запущенного сервера
	@if [ -f "$(PID_FILE)" ]; then \
		PID=$$(cat $(PID_FILE)); \
		if ps -p $$PID > /dev/null 2>&1; then \
			echo "$(GREEN)✅ Сервер:$(NC) запущен (PID: $$PID)"; \
			echo "$(GREEN)✅ Порт:$(NC) $(PORT)"; \
			echo "$(GREEN)✅ Доступен по:$(NC) http://localhost:$(PORT)"; \
		else \
			echo "$(RED)❌ Сервер:$(NC) PID файл есть, но процесс не запущен"; \
			rm -f $(PID_FILE); \
		fi \
	else \
		echo "$(YELLOW)⚠️  Сервер:$(NC) не запущен"; \
	fi
	
	@echo ""
	@echo "$(BLUE)Команды:$(NC)"
	@echo "  make start    - запустить сервер"
	@echo "  make stop     - остановить сервер"
	@echo "  make restart  - перезапустить сервер"
	@echo "  make logs     - показать логи"

# Просмотр логов
logs:
	@if [ -f "$(LOG_FILE)" ]; then \
		echo "$(BLUE)=== Логи Flask сервера ===$(NC)"; \
		echo "$(YELLOW)Для выхода: Ctrl+C$(NC)"; \
		echo ""; \
		tail -f $(LOG_FILE); \
	else \
		echo "$(YELLOW)⚠️  Файл логов не найден$(NC)"; \
		echo "Сервер, возможно, еще не запускался"; \
	fi

# Просмотр последних логов (без следования)
log:
	@if [ -f "$(LOG_FILE)" ]; then \
		echo "$(BLUE)=== Последние логи (50 строк) ===$(NC)"; \
		tail -n 50 $(LOG_FILE); \
	else \
		echo "$(YELLOW)Файл логов не найден$(NC)"; \
	fi

# Очистка
clean: stop
	@echo "$(BLUE)Очищаю временные файлы...$(NC)"
	@rm -f $(LOG_FILE)
	@echo "$(GREEN)✅ Временные файлы удалены$(NC)"

# Полная очистка (включая venv)
clean-all: clean
	@echo "$(BLUE)Удаляю виртуальное окружение...$(NC)"
	@rm -rf $(VENV_DIR) __pycache__ *.pyc
	@echo "$(GREEN)✅ Полная очистка завершена$(NC)"

# Тесты (если есть)
test: _activate
	@if [ -d "tests" ] || [ -f "test_*.py" ]; then \
		echo "$(BLUE)Запускаю тесты...$(NC)"; \
		$(VENV_DIR)/bin/python -m pytest -v || $(VENV_DIR)/bin/python -m unittest discover; \
	else \
		echo "$(YELLOW)⚠️  Тесты не найдены$(NC)"; \
	fi

# Обновление зависимостей
update:
	@echo "$(BLUE)Обновляю зависимости...$(NC)"
	@make _activate
	@$(VENV_DIR)/bin/pip install --upgrade pip
	@if [ -f "$(REQUIREMENTS)" ]; then \
		$(VENV_DIR)/bin/pip install --upgrade -r $(REQUIREMENTS); \
	else \
		$(VENV_DIR)/bin/pip install --upgrade flask; \
	fi
	@echo "$(GREEN)✅ Зависимости обновлены$(NC)"

# Создать requirements.txt из установленных пакетов
freeze: _activate
	@echo "$(BLUE)Создаю requirements.txt...$(NC)"
	@$(VENV_DIR)/bin/pip freeze > $(REQUIREMENTS)
	@echo "$(GREEN)✅ requirements.txt обновлен$(NC)"
