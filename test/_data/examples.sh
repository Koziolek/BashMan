#!/bin/bash

# Przykładowy plik z funkcjami bash i dokumentacją

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
backup_file() {
    local file="$1"

    if [[ -z "$file" ]]; then
        echo "Błąd: Nie podano pliku do kopii zapasowej" >&2
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        echo "Błąd: Plik '$file' nie istnieje" >&2
        return 1
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local backup_name="${file}.backup.${timestamp}"

    if cp "$file" "$backup_name"; then
        echo "Utworzono kopię zapasową: $backup_name"
        return 0
    else
        echo "Błąd: Nie można utworzyć kopii zapasowej" >&2
        return 1
    fi
}

#;
# # find_large_files
#
# Znajduje pliki większe niż podany rozmiar w określonym katalogu.
#
# ## Opis
#
# Funkcja przeszukuje katalog (rekursywnie) w poszukiwaniu plików
# większych niż określony rozmiar. Wyniki są sortowane według rozmiaru
# (od największych).
#
# ## Parametry
#
# - `$1`: Ścieżka do katalogu do przeszukania
# - `$2`: Minimalny rozmiar pliku (z jednostką, np. "100M", "1G")
#
# ## Wartość zwracana
#
# - `0` - operacja zakończona pomyślnie
# - `1` - błąd (nieprawidłowe parametry lub katalog nie istnieje)
#
# ## Przykłady użycia
#
# ```bash
# find_large_files "/home/user" "100M"  # Pliki większe niż 100MB
# find_large_files "/var/log" "1G"      # Pliki większe niż 1GB
# ```
#
# ## Uwagi
#
# Funkcja używa polecenia `find` z opcją `-size`, które akceptuje
# jednostki takie jak: c (bajty), k (kilobajty), M (megabajty), G (gigabajty).
#;
find_large_files() {
    local directory="$1"
    local min_size="$2"

    if [[ -z "$directory" || -z "$min_size" ]]; then
        echo "Użycie: find_large_files <katalog> <rozmiar>" >&2
        echo "Przykład: find_large_files /home 100M" >&2
        return 1
    fi

    if [[ ! -d "$directory" ]]; then
        echo "Błąd: Katalog '$directory' nie istnieje" >&2
        return 1
    fi

    echo "Szukanie plików większych niż $min_size w katalogu: $directory"
    echo "----------------------------------------"

    find "$directory" -type f -size "+${min_size}" -exec ls -lh {} \; 2>/dev/null | \
        sort -k5 -hr | \
        awk '{print $5 "\t" $9}'

    return 0
}

#;
# # create_project_structure
#
# Tworzy standardową strukturę katalogów dla nowego projektu.
#
# ## Opis
#
# Funkcja tworzy hierarchię katalogów typową dla projektów programistycznych,
# zawierającą foldery na kod źródłowy, testy, dokumentację i konfigurację.
# Dodatkowo tworzy podstawowe pliki README i .gitignore.
#
# ## Parametry
#
# - `$1`: Nazwa projektu (będzie to nazwa głównego katalogu)
# - `$2`: Typ projektu (opcjonalny): "web", "python", "bash" (domyślnie: "generic")
#
# ## Wartość zwracana
#
# - `0` - struktura została utworzona pomyślnie
# - `1` - błąd (projekt już istnieje lub problem z tworzeniem katalogów)
#
# ## Przykłady użycia
#
# ```bash
# create_project_structure "my-app"
# create_project_structure "web-project" "web"
# create_project_structure "python-tool" "python"
# ```
#
# ## Tworzona struktura
#
# ```
# project-name/
# ├── src/
# ├── tests/
# ├── docs/
# ├── config/
# ├── scripts/
# ├── README.md
# └── .gitignore
# ```
#;
create_project_structure() {
    local project_name="$1"
    local project_type="${2:-generic}"

    if [[ -z "$project_name" ]]; then
        echo "Błąd: Nie podano nazwy projektu" >&2
        echo "Użycie: create_project_structure <nazwa_projektu> [typ]" >&2
        return 1
    fi

    if [[ -d "$project_name" ]]; then
        echo "Błąd: Katalog '$project_name' już istnieje" >&2
        return 1
    fi

    echo "Tworzenie struktury projektu: $project_name (typ: $project_type)"

    # Tworzenie głównego katalogu
    mkdir -p "$project_name" || return 1

    # Tworzenie podkatalogów
    local dirs=("src" "tests" "docs" "config" "scripts")

    for dir in "${dirs[@]}"; do
        mkdir -p "$project_name/$dir"
        echo "Utworzono: $project_name/$dir/"
    done

    # Tworzenie README.md
    cat > "$project_name/README.md" << EOF
# $project_name

Opis projektu typu $project_type.

## Instalacja

Instrukcje instalacji...

## Użycie

Przykłady użycia...

## Struktura projektu

- \`src/\` - kod źródłowy
- \`tests/\` - testy
- \`docs/\` - dokumentacja
- \`config/\` - pliki konfiguracyjne
- \`scripts/\` - skrypty pomocnicze

## Licencja

MIT
EOF

    # Tworzenie .gitignore w zależności od typu projektu
    case "$project_type" in
        "python")
            cat > "$project_name/.gitignore" << EOF
__pycache__/
*.py[cod]
*$py.class
*.so
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
.env
venv/
env/
EOF
            ;;
        "web")
            cat > "$project_name/.gitignore" << EOF
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
dist/
build/
.DS_Store
*.log
EOF
            ;;
        "bash")
            cat > "$project_name/.gitignore" << EOF
*.log
*.tmp
.env
.cache/
logs/
temp/
EOF
            ;;
        *)
            cat > "$project_name/.gitignore" << EOF
# Logs
logs
*.log
npm-debug.log*

# Runtime data
pids
*.pid
*.seed

# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov

# Coverage directory used by tools like istanbul
coverage

# Grunt intermediate storage (http://gruntjs.com/creating-plugins#storing-task-files)
.grunt

# node-waf configuration
.lock-wscript

# Compiled binary addons (http://nodejs.org/api/addons.html)
build/Release

# Dependency directories
node_modules
jspm_packages

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

# Temporary files
*.tmp
temp/
.cache/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
            ;;
    esac

    echo "Utworzono README.md i .gitignore"
    echo "Struktura projektu '$project_name' została utworzona pomyślnie!"
    echo ""
    echo "Aby rozpocząć pracę:"
    echo "  cd $project_name"
    echo "  git init"
    echo "  git add ."
    echo "  git commit -m 'Initial commit'"

    return 0
}
#