#!/bin/bash

# Директория с шпаргалками
CHEAT_DIR="$HOME/Документы/Шпаргалки"
TEMP_DIR="/tmp/cheat_sheets"

# Создаем временную директорию
mkdir -p "$TEMP_DIR"

# Функция для извлечения текста из PDF
extract_pdf_text() {
    local pdf_file="$1"
    local txt_file="$2"
    
    if command -v pdftotext &> /dev/null; then
        pdftotext "$pdf_file" "$txt_file" 2>/dev/null
    elif command -v pdf2txt &> /dev/null; then
        pdf2txt "$pdf_file" > "$txt_file" 2>/dev/null
    else
        echo "⚠ Для извлечения текста установите poppler-utils:"
        echo "  sudo apt install poppler-utils"
        return 1
    fi
}

# Функция для отображения текста с less
show_text() {
    local txt_file="$1"
    if [ -s "$txt_file" ]; then
        echo "═══════════════════════════════════════"
        echo "📄 Содержимое (первые 1000 строк):"
        echo "═══════════════════════════════════════"
        head -1000 "$txt_file" | less
    else
        echo "❌ Не удалось извлечь текст из PDF"
    fi
}

# Основной цикл
while true; do
    clear
    echo "📚 МЕНЕДЖЕР ШПАРГАЛОК"
    echo "═══════════════════════════════════════"
    
    # Получаем список PDF файлов
    mapfile -t files < <(find "$CHEAT_DIR" -name "*.pdf" -type f | sort)
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "📭 Нет PDF файлов в директории."
        echo "Папка: $CHEAT_DIR"
        read -p "Нажмите Enter для выхода..."
        exit 1
    fi
    
    # Выводим список файлов
    echo "📋 Доступные шпаргалки (${#files[@]} шт.):"
    echo "═══════════════════════════════════════"
    for i in "${!files[@]}"; do
        filename=$(basename "${files[$i]}")
        filesize=$(du -h "${files[$i]}" | cut -f1)
        printf "%2d) %-40s (%s)\n" $((i+1)) "$filename" "$filesize"
    done
    echo "═══════════════════════════════════════"
    echo "  o) Открыть PDF в просмотрщике"
    echo "  t) Показать текст из PDF"
    echo "  l) Показать только список"
    echo "  q) Выход"
    echo "═══════════════════════════════════════"
    
    read -p "Выберите действие [1-${#files[@]}/o/t/l/q]: " choice
    
    case "$choice" in
        [0-9]*)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#files[@]}" ]; then
                selected_file="${files[$((choice-1))]}"
                echo "📖 Выбрано: $(basename "$selected_file")"
                
                # Подменю для выбранного файла
                while true; do
                    echo ""
                    echo "═══════════════════════════════════════"
                    echo "  1) Открыть в просмотрщике PDF"
                    echo "  2) Показать извлеченный текст"
                    echo "  3) Скопировать путь к файлу"
                    echo "  4) Назад к списку"
                    echo "═══════════════════════════════════════"
                    read -p "Выберите действие: " action
                    
                    case "$action" in
                        1)
                            if command -v xdg-open &> /dev/null; then
                                xdg-open "$selected_file" &
                                echo "✅ PDF открыт в просмотрщике"
                            else
                                echo "❌ Не найден xdg-open"
                            fi
                            ;;
                        2)
                            txt_file="$TEMP_DIR/$(basename "$selected_file" .pdf).txt"
                            if extract_pdf_text "$selected_file" "$txt_file"; then
                                show_text "$txt_file"
                            fi
                            ;;
                        3)
                            echo "$selected_file" | xclip -selection clipboard
                            echo "✅ Путь скопирован в буфер обмена"
                            ;;
                        4)
                            break
                            ;;
                        *)
                            echo "❌ Неверный выбор"
                            ;;
                    esac
                    read -p "Нажмите Enter для продолжения..."
                done
            else
                echo "❌ Неверный номер"
                read -p "Нажмите Enter для продолжения..."
            fi
            ;;
        o|O)
            # Открыть все PDF в файловом менеджере
            if command -v xdg-open &> /dev/null; then
                xdg-open "$CHEAT_DIR"
            else
                echo "❌ Не найден xdg-open"
            fi
            ;;
        t|T)
            # Показать текст из всех PDF
            echo "Извлечение текста из всех PDF..."
            for pdf in "${files[@]}"; do
                txt_file="$TEMP_DIR/$(basename "$pdf" .pdf).txt"
                if extract_pdf_text "$pdf" "$txt_file"; then
                    echo "═══════════════════════════════════════"
                    echo "📄 $(basename "$pdf"):"
                    echo "═══════════════════════════════════════"
                    head -50 "$txt_file"
                    echo "..."
                fi
            done
            read -p "Нажмите Enter для продолжения..."
            ;;
        l|L)
            # Просто показать список
            echo "═══════════════════════════════════════"
            echo "📋 Полный список файлов:"
            find "$CHEAT_DIR" -name "*.pdf" -type f -exec ls -lh {} \;
            read -p "Нажмите Enter для продолжения..."
            ;;
        q|Q)
            echo "👋 Выход."
            # Очистка временных файлов
            rm -rf "$TEMP_DIR"
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор"
            read -p "Нажмите Enter для продолжения..."
            ;;
    esac
done
UUID MY DISK SDA1 UUID""
UUID MY DISK SDA1 UUID""
UUID MY DISK SDA1 UUID""
UUID MY DISK SDA1 UUID"48ab0853-44e1-4a6f-8a52-a164a0954edc"
