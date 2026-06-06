# Проверить количество файлов в исходном и целевом каталогах
find /mnt/DATAINFO/RESCUE_DATA -name "*.jpg" | wc -l
find /mnt/DATAINFO/RESCUE_DATA/PICTURE -name "*.jpg" | wc -l