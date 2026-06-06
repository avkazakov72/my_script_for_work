#!/usr/bin/env bash

# Скрипт для создания нового Python проекта с виртуальным окружением
# Использование: python_newproject.sh ~/PythonProject/NewProjectName

set -e  # Прерывать выполнение при ошибке

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Проверка наличия аргумента
if [ $# -eq 0 ]; then
    print_error "Не указан путь к проекту"
    echo "Использование: $0 <путь_к_проекту>"
    echo "Пример: $0 ~/PythonProject/NewProjectName"
    exit 1
fi

PROJECT_PATH="$1"
PROJECT_NAME=$(basename "$PROJECT_PATH")

print_info "Создание проекта Python \"$PROJECT_NAME\" в $PROJECT_PATH"

# Проверка, не существует ли уже каталог
if [ -d "$PROJECT_PATH" ]; then
    print_error "Каталог $PROJECT_PATH уже существует"
    exit 1
fi

# Создание структуры каталогов
print_info "Создание структуры каталогов..."
mkdir -p "$PROJECT_PATH"/{src,tests,docs,scripts,data}

# Создание виртуального окружения
print_info "Создание виртуального окружения..."
python3 -m venv "$PROJECT_PATH/venv"

if [ $? -ne 0 ]; then
    print_error "Ошибка при создании виртуального окружения. Убедитесь, что Python 3 установлен."
    exit 1
fi

print_success "Виртуальное окружение создано"

# Активация виртуального окружения и установка базовых пакетов
print_info "Активация виртуального окружения и установка базовых пакетов..."

source "$PROJECT_PATH/venv/bin/activate"

# Обновление pip
pip install --upgrade pip > /dev/null 2>&1

# Создание requirements.txt с базовыми пакетами
cat > "$PROJECT_PATH/requirements.txt" << EOF
# Основные зависимости проекта
# Добавьте сюда необходимые пакеты, например:
# numpy
# pandas
# requests
EOF

# Установка общих пакетов для разработки
pip install pytest black flake8 mypy > /dev/null 2>&1

print_success "Базовые пакеты установлены"

# Создание файла .gitignore
print_info "Создание .gitignore..."
cat > "$PROJECT_PATH/.gitignore" << EOF
# Виртуальное окружение
venv/
env/
ENV/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Логи и БД
*.log
*.sql
*.sqlite

# OS
.DS_Store
Thumbs.db
EOF

# Создание основного модуля
print_info "Создание основного модуля..."
cat > "$PROJECT_PATH/src/main.py" << EOF
#!/usr/bin/env python3
\"\"\"
Главный модуль проекта $PROJECT_NAME
\"\"\"

def main():
    print("Проект $PROJECT_NAME успешно запущен!")
    print("Виртуальное окружение активно и готово к работе.")

if __name__ == "__main__":
    main()
EOF

# Создание тестового файла
cat > "$PROJECT_PATH/tests/test_main.py" << EOF
#!/usr/bin/env python3
\"\"\"
Тесты для главного модуля
\"\"\"

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

import main

def test_main():
    assert main.main() is None
EOF

# Создание README.md
cat > "$PROJECT_PATH/README.md" << EOF
# $PROJECT_NAME

## Описание
Краткое описание проекта

## Установка и запуск

### Активация виртуального окружения
\`\`\`bash
source venv/bin/activate
\`\`\`

### Установка зависимостей
\`\`\`bash
pip install -r requirements.txt
\`\`\`

### Запуск проекта
\`\`\`bash
python src/main.py
\`\`\`

### Запуск тестов
\`\`\`bash
pytest tests/
\`\`\`

### Деактивация виртуального окружения
\`\`\`bash
deactivate
\`\`\`

## Структура проекта
\`\`\`
$PROJECT_NAME/
├── src/           # Исходный код
├── tests/         # Тесты
├── docs/          # Документация
├── scripts/       # Скрипты утилиты
├── data/          # Данные
├── venv/          # Виртуальное окружение
├── requirements.txt
├── .gitignore
└── README.md
\`\`\`
EOF

# Создание скрипта для активации окружения
cat > "$PROJECT_PATH/activate.sh" << EOF
#!/bin/bash
# Скрипт для быстрой активации виртуального окружения
source "\$(dirname "\$0")/venv/bin/activate"
echo "Виртуальное окружение проекта $PROJECT_NAME активировано"
EOF

chmod +x "$PROJECT_PATH/activate.sh"

# Создание скрипта для деактивации
cat > "$PROJECT_PATH/deactivate.sh" << EOF
#!/bin/bash
# Скрипт для деактивации виртуального окружения
deactivate
echo "Виртуальное окружение деактивировано"
EOF

chmod +x "$PROJECT_PATH/deactivate.sh"

# Установка прав на выполнение для main.py
chmod +x "$PROJECT_PATH/src/main.py"

# Деактивация виртуального окружения
deactivate 2>/dev/null

print_success "Проект $PROJECT_NAME успешно создан!"
echo ""
print_info "Структура проекта:"
tree "$PROJECT_PATH" 2>/dev/null || ls -la "$PROJECT_PATH"
echo ""
print_info "Для активации виртуального окружения выполните:"
echo "  source $PROJECT_PATH/venv/bin/activate"
echo "  # или"
echo "  cd $PROJECT_PATH && ./activate.sh"
echo ""
print_info "Для запуска тестов (после активации):"
echo "  pytest tests/"
echo ""
print_info "Установите дополнительные пакеты (после активации):"
echo "  pip install <пакет>"
echo "  pip freeze > requirements.txt  # для сохранения зависимостей"