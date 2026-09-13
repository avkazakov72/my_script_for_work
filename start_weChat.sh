#!/bin/bash
export WINEPREFIX="$HOME/WeChatPrefix"
export WINEARCH=win64

# Отключаем crashpad через переменные окружения
export WINE_DISABLE_CRASH_DIALOG=1
export WINEDEBUG=-all

# Переходим в папку WeChat
cd "$HOME/WeChatPrefix/drive_c/Program Files/Tencent/Weixin/4.1.12.26/"

# Создаем заглушку для crashpad_handler если её нет
if [ -f "crashpad_handler.exe" ] && [ ! -f "crashpad_handler.exe.bak" ]; then
    mv crashpad_handler.exe crashpad_handler.exe.bak
    touch crashpad_handler.exe
    chmod +x crashpad_handler.exe
fi

# Запускаем WeChat
wine WeixinExt.exe
