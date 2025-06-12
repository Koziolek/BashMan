#!/usr/bin/env bash

#;
# # backup_file
#
# Tworzy kopię zapasową podanego pliku z znacznikiem czasowym.
#
# ## Opis
#
# Funkcja tworzy kopię zapasową pliku dodając do nazwy znacznik czasowy
# w formacie YYYY-MM-DD_HH-MM-SS. Jeśli plik nie istnieje, wyświetlany
# jest komunikat o błędzie.
#
# ## Parametry
#
# - `$1`: Ścieżka do pliku, który ma zostać skopiowany
#
# ## Wartość zwracana
#
# - `0` - kopia zapasowa została utworzona pomyślnie
# - `1` - błąd (plik nie istnieje lub problem z kopiowaniem)
#
# ## Przykłady użycia
#
# ```bash
# backup_file "/etc/hosts"
# backup_file "config.txt"
# ```
#
# ## Zobacz także
#
# - `cp(1)` - kopiowanie plików
# - `date(1)` - wyświetlanie i ustawianie daty
#;
with_markdown(){
  echo "OK"
}

#;
# No end!!
#