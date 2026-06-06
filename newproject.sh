#!/bin/bash

# Создание проекта одним скриптом
project_name="my_awesome_project"

mkdir -p $project_name
cd $project_name

# Структура
mkdir -p src tests docs data scripts

# Файлы
cat > src/main.py << 'EOF'
#!/usr/bin/env python3

def greet(name="World"):
    return f"Hello, {name}!"

def main():
    print(greet())

if __name__ == "__main__":
    main()
EOF

cat > tests/test_main.py << 'EOF'
import unittest
from src.main import greet

class TestGreet(unittest.TestCase):
    def test_greet_default(self):
        self.assertEqual(greet(), "Hello, World!")
    
    def test_greet_name(self):
        self.assertEqual(greet("Alice"), "Hello, Alice!")

if __name__ == "__main__":
    unittest.main()
EOF

# Виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Установка в режиме разработки
pip install -e .

echo "Project $project_name created successfully!"