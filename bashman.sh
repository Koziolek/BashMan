#!/bin/bash

# BashDoc Generator - generuje dokumentację w stylu JavaDoc dla funkcji bash
# Autor: System
# Wersja: 1.0

set -euo pipefail

# Domyślne wartości
DEFAULT_TARGET_DIR="docs"
DEFAULT_SOURCE_DIR="."
INSTALL_MODE=false
TARGET_DIR=""
SOURCE_DIR=""

# Kolory do wyświetlania
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_NC='\033[0m' # No Color

# Funkcja wyświetlania pomocy
show_help() {
    cat << EOF
BashDoc Generator - generator dokumentacji dla funkcji bash

Użycie: $0 [OPCJE] [KATALOG_ŹRÓDŁOWY]

OPCJE:
    -t, --target DIR    Katalog docelowy dla dokumentacji (domyślnie: docs)
    -i, --install       Zainstaluj dokumentację w /usr/share/man/man1
    -h, --help          Wyświetl tę pomoc

ARGUMENTY:
    KATALOG_ŹRÓDŁOWY    Katalog ze skryptami bash (domyślnie: .)

PRZYKŁADY:
    $0                          # Generuj docs z bieżącego katalogu do ./docs
    $0 -t /tmp/docs ./scripts   # Generuj docs z ./scripts do /tmp/docs
    $0 -i ./scripts             # Generuj i zainstaluj w systemie

FORMAT KOMENTARZY:
    Komentarze dokumentacji muszą być umieszczone bezpośrednio nad funkcją:
    
    #;
    # # Nazwa funkcji
    # 
    # Opis funkcji w formacie markdown
    # 
    # ## Parametry
    # - \$1: pierwszy parametr
    # - \$2: drugi parametr
    # 
    # ## Przykład
    # \`\`\`bash
    # moja_funkcja "test" "123"
    # \`\`\`
    #;
    moja_funkcja() {
        # kod funkcji
    }

EOF
}

# Funkcja logowania
log() {
    local level="$1"
    shift
    case "$level" in
        "INFO")  echo -e "${C_GREEN}[INFO]${C_NC} $*" >&2 ;;
        "WARN")  echo -e "${C_YELLOW}[WARN]${C_NC} $*" >&2 ;;
        "ERROR") echo -e "${C_RED}[ERROR]${C_NC} $*" >&2 ;;
    esac
}

# Parsowanie argumentów
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--target)
                TARGET_DIR="$2"
                shift 2
                ;;
            -i|--install)
                INSTALL_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log "ERROR" "Nieznana opcja: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$SOURCE_DIR" ]]; then
                    SOURCE_DIR="$1"
                else
                    log "ERROR" "Zbyt wiele argumentów"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Ustawienie domyślnych wartości
    SOURCE_DIR="${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
    TARGET_DIR="${TARGET_DIR:-$DEFAULT_TARGET_DIR}"
}

# Sprawdzenie zależności
check_dependencies() {
    local missing_deps=()
    
    if ! command -v pandoc &> /dev/null; then
        missing_deps+=("pandoc")
    fi
    
    if ! command -v gzip &> /dev/null; then
        missing_deps+=("gzip")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Brakujące zależności: ${missing_deps[*]}"
        log "INFO" "Zainstaluj je za pomocą: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Sprawdzenie czy katalog istnieje
check_source_directory() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log "ERROR" "Katalog źródłowy nie istnieje: $SOURCE_DIR"
        exit 1
    fi
}

# Tworzenie katalogu docelowego
create_target_directory() {
    if [[ ! -d "$TARGET_DIR" ]]; then
        mkdir -p "$TARGET_DIR"
        log "INFO" "Utworzono katalog: $TARGET_DIR"
    fi
}

# Wyciąganie komentarzy dokumentacji z pliku
extract_doc_comments() {
    local file="$1"
    local temp_file
    temp_file=$(mktemp)
    
    awk '
    BEGIN { in_doc = 0; doc_content = ""; line_count = 0 }
    
    /^#;$/ {
        if (in_doc == 0) {
            in_doc = 1
            doc_content = ""
            start_line = NR + 1
        } else {
            in_doc = 0
            print start_line "|" doc_content
            doc_content = ""
        }
        next
    }
    
    in_doc && /^#/ {
        line = $0
        gsub(/^# ?/, "", line)
        if (doc_content == "") {
            doc_content = line
        } else {
            doc_content = doc_content "\n" line
        }
        next
    }
    
    in_doc && !/^#/ {
        in_doc = 0
        print start_line "|" doc_content
        doc_content = ""
    }
    ' "$file" > "$temp_file"
    
    echo "$temp_file"
}

# Znajdowanie funkcji po numerze linii
find_function_after_line() {
    local file="$1"
    local line_num="$2"
    
    awk -v start="$line_num" '
    NR > start && /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*\{/ {
        match($0, /^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\(/, arr)
        if (arr[1]) {
            print arr[1]
            exit
        }
    }
    ' "$file"
}

# Generowanie dokumentacji dla pojedynczego pliku
process_file() {
    local file="$1"
    local basename
    local doc_comments_file
    local processed_count=0
    
    basename=$(basename "$file" .sh)
    log "INFO" "Przetwarzanie pliku: $file"
    
    doc_comments_file=$(extract_doc_comments "$file")
    
    while IFS='|' read -r line_num doc_content; do
        [[ -z "$line_num" ]] && continue
        
        local func_name
        func_name=$(find_function_after_line "$file" "$line_num")
        
        if [[ -n "$func_name" ]]; then
            generate_man_page "$basename" "$func_name" "$doc_content"
            ((processed_count++))
        else
            log "WARN" "Nie znaleziono funkcji po linii $line_num w pliku $file"
        fi
    done < "$doc_comments_file"
    
    rm -f "$doc_comments_file"
    
    if [[ $processed_count -gt 0 ]]; then
        log "INFO" "Wygenerowano dokumentację dla $processed_count funkcji z pliku $file"
    fi
}

# Generowanie strony man
generate_man_page() {
    local basename="$1"
    local func_name="$2"
    local doc_content="$3"
    local output_dir="$TARGET_DIR/$basename"
    local md_file="$output_dir/${func_name}.md"
    local man_file="$output_dir/${func_name}.1"
    local gz_file="$output_dir/${func_name}.1.gz"
    
    # Tworzenie katalogu
    mkdir -p "$output_dir"
    
    # Przygotowanie zawartości markdown
    {
        echo "% ${func_name}(1) | Funkcje Bash"
        echo "% "
        echo "% $(date +'%B %Y')"
        echo ""
        echo "$doc_content"
    } > "$md_file"
    
    # Konwersja do man
    if pandoc -s -t man "$md_file" -o "$man_file" 2>/dev/null; then
        # Kompresja
        gzip -f "$man_file"
        rm -f "$md_file"
        log "INFO" "Wygenerowano: $gz_file"
    else
        log "ERROR" "Błąd konwersji pandoc dla funkcji: $func_name"
        rm -f "$md_file" "$man_file"
    fi
}

# Znajdowanie plików bash
find_bash_files() {
    find "$SOURCE_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -o \( -executable -type f -exec grep -l "^#!/bin/bash\|^#!/usr/bin/env bash" {} \; \)
}

# Instalacja w systemie
install_system_docs() {
    local installed_count=0
    
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Instalacja wymaga uprawnień root. Użyj sudo."
        exit 1
    fi
    
    log "INFO" "Instalowanie dokumentacji w /usr/share/man/man1/"
    
    find "$TARGET_DIR" -name "*.1.gz" | while read -r gz_file; do
        local filename
        filename=$(basename "$gz_file")
        cp "$gz_file" "/usr/share/man/man1/$filename"
        ((installed_count++))
        log "INFO" "Zainstalowano: $filename"
    done
    
    # Aktualizacja bazy man
    if command -v mandb &> /dev/null; then
        log "INFO" "Aktualizowanie bazy danych man..."
        mandb -q
    fi
    
    log "INFO" "Instalacja zakończona. Zainstalowano $installed_count plików."
}

# Główna funkcja
bashman() {
    log "INFO" "BashDoc Generator - start"
    
    parse_arguments "$@"
    check_dependencies
    check_source_directory
    create_target_directory
    
    local total_files=0
    
    # Przetwarzanie plików
    while IFS= read -r -d '' file; do
        process_file "$file"
        ((total_files++))
    done < <(find_bash_files | sort -u | tr '\n' '\0')
    
    if [[ $total_files -eq 0 ]]; then
        log "WARN" "Nie znaleziono plików bash w katalogu: $SOURCE_DIR"
        exit 0
    fi
    
    log "INFO" "Przetworzono $total_files plików"
    
    # Instalacja jeśli wymagana
    if [[ "$INSTALL_MODE" == true ]]; then
        install_system_docs
    fi
    
    log "INFO" "Generowanie dokumentacji zakończone pomyślnie"
    log "INFO" "Dokumentacja dostępna w: $TARGET_DIR"
    
    if [[ "$INSTALL_MODE" == false ]]; then
        echo ""
        echo "Aby zainstalować dokumentację w systemie, użyj:"
        echo "  sudo $0 -i $SOURCE_DIR"
    fi
}

# Uruchomienie głównej funkcji
export -f bashman
