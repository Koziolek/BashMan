#!/bin/bash

# BashMan - documentation generator for bash
# Author: Koziołek
# Version: 1.0

# DEFAULTS
DEFAULT_TARGET_DIR="docs"
DEFAULT_SOURCE_DIR="."
GZIP_MODE=true
INSTALL_MODE=false
TARGET_DIR=""
SOURCE_DIR=""

# INTERNALS
_SEGMENT_SEPARATOR=${_SEGMENT_SEPARATOR:-'#####################'}

show_help() {
  cat <<EOF
BashMan — a documentation generator for bash functions. Prepare man pages based on coments in your code.

Usage:

  bashman [OPTIONS] [SOURCE_DIRECTORY]

  OPTIONS:
      -t, --target – DIR Target directory for documentation (default: docs)
      -i, --install – Install documentation in /usr/share/man/man1
      -h, --help – Display this help

  ARGUMENTS:
      SOURCE_DIRECTORY Directory with bash scripts (default: .)

  EXAMPLES:

      $ bashman # Generate docs from current directory to ./docs
      $ bashman -t /tmp/docs ./scripts # Generate docs from ./scripts to /tmp/docs
      $ bashman -i ./scripts # Generate and install in system

Comment format:

Documentation comments must be placed directly above the function:

    #;
    # # Function name
    #
    # Function description in markdown format
    #
    # ## Parameters
    # - \$1: first parameter
    # - \$2: second parameter
    #
    # ## Example
    # \`\`\`bash
    # my_function "test" "123"
    # \`\`\`
    #;
    my_function() {
        # function code
    }

Licence:

MIT Licence
EOF
}

log() {
  local level="$1"
  shift
  case "$level" in
  "DEBUG") echo -e "${C_BLUE}[INFO]${C_NC} $*" >&2 ;;
  "INFO") echo -e "${C_GREEN}[INFO]${C_NC} $*" >&2 ;;
  "WARN") echo -e "${C_YELLOW}[WARN]${C_NC} $*" >&2 ;;
  "ERROR") echo -e "${C_RED}[ERROR]${C_NC} $*" >&2 ;;
  esac
}

# Parsowanie argumentów
parse_arguments() {
  local OPTIND opt

  while getopts ":t:ihg" opt; do
    case $opt in
    t)
      TARGET_DIR="$OPTARG"
      ;;
    i)
      INSTALL_MODE=true
      ;;
    h)
      show_help
      return 0
      ;;
    g)
        log "INFO" "Will not gzip"
        GZIP_MODE=false
        ;;
    \?)
      log "ERROR" "Nieznana opcja: -$OPTARG"
      show_help
      return 1
      ;;
    :)
      log "ERROR" "Opcja -$OPTARG wymaga argumentu"
      show_help
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  # Ostatni parametr to katalog źródłowy
  if [[ $# -gt 1 ]]; then
    log "ERROR" "Zbyt wiele argumentów"
    show_help
    return 1
  elif [[ $# -eq 1 ]]; then
    SOURCE_DIR="$1"
  fi

  local OPTIND=1 # reset param pointer
  SOURCE_DIR="${SOURCE_DIR:-${DEFAULT_SOURCE_DIR:-$(pwd)}}"
  SOURCE_DIR=$(realpath "${SOURCE_DIR}")
  TARGET_DIR="${TARGET_DIR:-$DEFAULT_TARGET_DIR}"
}

check_dependencies() {
  local missing_deps=()

  if ! command -v pandoc &>/dev/null; then
    missing_deps+=("pandoc")
  fi

  if [[ "$GZIP_MODE" == true ]] && ! command -v gzip &>/dev/null; then
    missing_deps+=("gzip")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log "ERROR" "Brakujące zależności: ${missing_deps[*]}"
    log "INFO" "Zainstaluj je za pomocą: sudo apt-get install ${missing_deps[*]}"
    return 1
  fi
}
check_source_directory() {
  if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ERROR" "Katalog źródłowy nie istnieje: $SOURCE_DIR"
    return 1
  fi
}
check_target_directory() {
  if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
  fi
}

# Wyciąganie komentarzy dokumentacji
extract_doc_comments() {
  local file="$1"
  local temp_file
  temp_file=$(mktemp)

  awk -v separator="$_SEGMENT_SEPARATOR" '
      BEGIN {
          in_comment = 0;
          block = "";
          next_line_is_func = 0
      }
      /^#;/ {
          if (in_comment == 0) {
              in_comment = 1;
              block = "";
              next_line_is_func = 0;
          } else {
              in_comment = 0;
              next_line_is_func = 1;
          }
          next;
      }
      {
          if (in_comment) {
              line = $0;
              sub(/^# ?/, "", line);
              block = block line "\n";
          } else if (next_line_is_func) {
              if ($0 ~ /^(function |[a-zA-Z_])[a-zA-Z0-9_]* ?\(\)/) {
                  split($0, parts, "(");
                  func_name = parts[1];
                  gsub(/^function /, "", func_name);
                  gsub(/ /, "", func_name);
                  print "function_name: " func_name;
                  printf "comment: %s\n", (block == "" ? "# Brak dokumentacji\n" : block);
                  print "";
                  print separator;
              }
              next_line_is_func = 0;
          }
      }
      ' "$file" >"$temp_file"

  echo "$temp_file"
}

process_file() {
  local file="$1"
  local basename
  local doc_comments_file
  local processed_count=0

  basename=$(basename "$file" .sh)
  log "INFO" "Przetwarzanie pliku: $file"

  doc_comments_file=$(extract_doc_comments "$file")

  local segments
  readarray -d "$_SEGMENT_SEPARATOR" -t segments < "$doc_comments_file"

  for segment in "${segments[@]}"; do
    # Pomijamy puste segmenty
    [[ -z "$(echo "$segment" | tr -d '[:space:]')" ]] && continue

    local func_name
    func_name=$(echo "$segment" | grep "^function_name:" | sed 's/^function_name: *//')

    local comment
    comment=$(echo "$segment" | sed -n '/^comment: */,$p' | sed '1s/^comment: *//')

    comment=$(echo "$comment" | sed '/^[[:space:]]*$/d')

    if [[ -n "$func_name" && -n "$comment" ]]; then
      generate_man_page "$basename" "$func_name" "$comment"
      ((processed_count++))
    else
      log "WARN" "Niepełne dane w segmencie - func_name='$func_name', comment='$comment'"
    fi
  done

  rm -f "$doc_comments_file"

  if [[ $processed_count -gt 0 ]]; then
    log "INFO" "Wygenerowano dokumentację dla $processed_count funkcji z pliku $file"
  else
    log "WARN" "Nie znaleziono żadnych funkcji z dokumentacją w pliku $file"
  fi
}

generate_man_page() {
  local basename="$1"
  local func_name="$2"
  local doc_content="$3"

  local target_dir="${TARGET_DIR:-$DEFAULT_TARGET_DIR}"
  local output_dir="$target_dir/$basename"
  local md_file="$output_dir/${func_name}.md"
  local man_file="$output_dir/${func_name}.1"
  local gz_file="$output_dir/${func_name}.1.gz"

  if [[ -z "$target_dir" ]]; then
    log "ERROR" "Katalog docelowy nie został ustawiony (TARGET_DIR ani DEFAULT_TARGET_DIR)"
    return 1
  fi

  if ! mkdir -p "$output_dir"; then
    log "ERROR" "Nie można utworzyć katalogu: $output_dir"
    return 1
  fi

  # Przygotowanie zawartości markdown
  {
    echo "% ${func_name}(1) | Funkcje Bash"
    echo "% "
    echo "% $(date +'%B %Y')"
    echo ""
    echo "$doc_content"
  } >"$md_file"

  if [[ ! -f "$md_file" ]]; then
    log "ERROR" "Nie można utworzyć pliku markdown: $md_file"
    return 1
  fi

  if command -v pandoc >/dev/null 2>&1; then
    if pandoc -s -t man "$md_file" -o "$man_file" 2>/dev/null; then
      # Kompresja
      gzip -f "$man_file"
      rm -f "$md_file"
    else
      log "ERROR" "Błąd konwersji pandoc dla funkcji: $func_name"
      rm -f "$md_file" "$man_file"
      return 1
    fi
  else
    log "WARN" "Pandoc nie jest zainstalowany - pozostawiam plik markdown: $md_file"
  fi

}

# Znajdowanie plików bash
find_bash_files() {
  {
    # Pliki z rozszerzeniem .sh i .bash
    find "$SOURCE_DIR" -type f \( -name "*.sh" -o -name "*.bash" \)

    # Pliki wykonywalne z shebangiem bash
    find "$SOURCE_DIR" -type f -executable -exec grep -l "^#!/bin/bash\|^#!/usr/bin/env bash" {} \;
  } | sort -u
}

# Instalacja w systemie
install_system_docs() {
  local installed_count=0

  if [[ $EUID -ne 0 ]]; then
    log "ERROR" "Instalacja wymaga uprawnień root. Użyj sudo."
    return 1
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
  if command -v mandb &>/dev/null; then
    log "INFO" "Aktualizowanie bazy danych man..."
    mandb -q
  fi

  log "INFO" "Instalacja zakończona. Zainstalowano $installed_count plików."
}

# Główna funkcja
function bashman() {
  log "INFO" "BashMan Generator - start"

  parse_arguments "$@"
  check_dependencies
  check_source_directory
  check_target_directory

  local total_files=0

  # Przetwarzanie plików
  while IFS= read -r -d '' file; do
    process_file "$file"
    ((total_files++))
  done < <(find_bash_files | sort -u | tr '\n' '\0')

  if [[ $total_files -eq 0 ]]; then
    log "WARN" "Nie znaleziono plików bash w katalogu: $SOURCE_DIR"
    return 0
  fi

  log "INFO" "Przetworzono $total_files plików"

  if [[ "$INSTALL_MODE" == true ]]; then
    install_system_docs
  fi

  if [[ "$INSTALL_MODE" == false ]]; then
    echo ""
    echo "Aby zainstalować dokumentację w systemie, użyj:"
    echo "  sudo $0 -i $SOURCE_DIR"
  fi
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f bashman
else
  echo "Running"
  # bashman "$@"
fi