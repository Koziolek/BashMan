# create_project_structure
Tworzy standardową strukturę katalogów dla nowego projektu.
## Opis
Funkcja tworzy hierarchię katalogów typową dla projektów programistycznych,
zawierającą foldery na kod źródłowy, testy, dokumentację i konfigurację.
Dodatkowo tworzy podstawowe pliki README i .gitignore.
## Parametry
- `$1`: Nazwa projektu (będzie to nazwa głównego katalogu)
- `$2`: Typ projektu (opcjonalny): "web", "python", "bash" (domyślnie: "generic")
## Wartość zwracana
- `0` - struktura została utworzona pomyślnie
- `1` - błąd (projekt już istnieje lub problem z tworzeniem katalogów)
## Przykłady użycia
```bash
create_project_structure "my-app"
create_project_structure "web-project" "web"
create_project_structure "python-tool" "python"
```
## Tworzona struktura
```
project-name/
├── src/
├── tests/
├── docs/
├── config/
├── scripts/
├── README.md
└── .gitignore
```
