# find_large_files
Znajduje pliki większe niż podany rozmiar w określonym katalogu.
## Opis
Funkcja przeszukuje katalog (rekursywnie) w poszukiwaniu plików
większych niż określony rozmiar. Wyniki są sortowane według rozmiaru
(od największych).
## Parametry
- `$1`: Ścieżka do katalogu do przeszukania
- `$2`: Minimalny rozmiar pliku (z jednostką, np. "100M", "1G")
## Wartość zwracana
- `0` - operacja zakończona pomyślnie
- `1` - błąd (nieprawidłowe parametry lub katalog nie istnieje)
## Przykłady użycia
```bash
find_large_files "/home/user" "100M"  # Pliki większe niż 100MB
find_large_files "/var/log" "1G"      # Pliki większe niż 1GB
```
## Uwagi
Funkcja używa polecenia `find` z opcją `-size`, które akceptuje
jednostki takie jak: c (bajty), k (kilobajty), M (megabajty), G (gigabajty).
