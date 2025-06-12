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
_SEGMENT_SEPARATOR=${_SEGMENT_SEPARATOR:-'=============================================================================='}
_HELP=0

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
      _HELP=1
      show_help
      return 0
      ;;
    g)
      log "INFO" "Will not gzip"
      GZIP_MODE=false
      ;;
    \?)
      log "ERROR" "Unknown option: -$OPTARG"
      show_help
      return 1
      ;;
    :)
      log "ERROR" "Option -$OPTARG requires an argument"
      show_help
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  if [[ $# -gt 1 ]]; then
    log "ERROR" "Too many arguments"
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
    log "ERROR" "Missing dependencies: ${missing_deps[*]}"
    log "INFO" "Install them using: sudo apt-get install ${missing_deps[*]}"
    return 1
  fi
}
check_source_directory() {
  if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ERROR" "Source directory does not exist: $SOURCE_DIR"
    return 1
  fi
}
check_target_directory() {
  if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
  fi
}

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
              if (line == "#") {
                  line = "";
              } else {
                  # Usuń "# " lub "#" z początku
                  sub(/^# ?/, "", line);
              }

              if (block == "") {
                  block = line;
              } else {
                  block = block "\n" line;
              }

          } else if (next_line_is_func) {
              if ($0 ~ /^(function |[a-zA-Z_])[a-zA-Z0-9_]* ?\(\)/) {
                  split($0, parts, "(");
                  func_name = parts[1];
                  gsub(/^function /, "", func_name);
                  gsub(/ /, "", func_name);
                  print "function_name: " func_name;
                  printf "comment: %s\n", (block == "" ? "# Brak dokumentacji" : block);
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
  log "INFO" "Processing file: $file"

  doc_comments_file=$(extract_doc_comments "$file")

  local segments_content
  segments_content=$(cat "$doc_comments_file")

  IFS="$_SEGMENT_SEPARATOR" read -ra segments <<<"$segments_content"

  local current_segment=""
  local func_name=""
  local comment=""

  while IFS= read -r line; do
    if [[ "$line" == "$_SEGMENT_SEPARATOR" ]]; then
      # End of segment - process it
      if [[ -n "$current_segment" ]]; then

        func_name=$(echo "$current_segment" | grep "^function_name:" | sed 's/^function_name: *//')
        comment=$(echo "$current_segment" | sed -n '/^comment: */,$p' | sed '1s/^comment: *//')
        comment=$(echo "$comment" | sed '/^[[:space:]]*$/d')

        if [[ -n "$func_name" && -n "$comment" ]]; then
          generate_man_page "$basename" "$func_name" "$comment"
          ((processed_count++))
        else
          log "WARN" "Incomplete data in segment - func_name='$func_name', comment='$comment'"
        fi
      fi
      current_segment=""
    else
      # Dodaj linię do bieżącego segmentu
      if [[ -n "$current_segment" ]]; then
        current_segment="$current_segment"$'\n'"$line"
      else
        current_segment="$line"
      fi
    fi
  done <"$doc_comments_file"

  if [[ -n "$current_segment" ]]; then
    func_name=$(echo "$current_segment" | grep "^function_name:" | sed 's/^function_name: *//')
    comment=$(echo "$current_segment" | sed -n '/^comment: */,$p' | sed '1s/^comment: *//')
    comment=$(echo "$comment" | sed '/^[[:space:]]*$/d')

    if [[ -n "$func_name" && -n "$comment" ]]; then
      generate_man_page "$basename" "$func_name" "$comment"
      ((processed_count++))
    fi
  fi

  rm -f "$doc_comments_file"

  if [[ $processed_count -gt 0 ]]; then
    log "INFO" "Generated documentation for $processed_count functions from file $file"
  else
    log "WARN" "No functions with documentation found in file $file"
  fi
}

convert_markdown_to_man() {
  local md_file="$1"
  local man_file="$2"

  if command -v pandoc >/dev/null 2>&1; then
    pandoc "$md_file" -s -t man -o "$man_file" 2>/dev/null
    return $?
  else
    log "WARN" "Pandoc is not installed - keeping markdown file: $md_file"
    return 1
  fi
}

compress_man_page() {
  local man_file="$1"

  if [[ -f "$man_file" ]]; then
    gzip -f "$man_file"
    return $?
  else
    log "ERROR" "File to compress does not exist: $man_file"
    return 1
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

  if [[ -z "$target_dir" ]]; then
    log "ERROR" "Target directory not set (neither TARGET_DIR nor DEFAULT_TARGET_DIR)"
    return 1
  fi

  if ! mkdir -p "$output_dir"; then
    log "ERROR" "Cannot create directory: $output_dir"
    return 1
  fi

  echo "$doc_content" >"$md_file"

  echo "----"
  echo $doc_content
  cat $md_file
  echo "----"

  if [[ ! -f "$md_file" ]]; then
    log "ERROR" "Cannot create markdown file: $md_file"
    return 1
  fi

  if ! convert_markdown_to_man "$md_file" "$man_file"; then
    log "ERROR" "Conversion error for function: $func_name"
    rm -f "$md_file" "$man_file"
    return 1
  fi

  echo "----"
  cat $man_file
  echo "----"


  if [[ $GZIP_MODE == true ]]; then
    compress_man_page "$man_file"
    rm -f "$md_file"
  fi
}

find_bash_files() {
  {
    find "$SOURCE_DIR" -type f \( -name "*.sh" -o -name "*.bash" \)

    # Pliki wykonywalne z shebangiem bash
    find "$SOURCE_DIR" -type f -executable -exec grep -l "^#!/bin/bash\|^#!/usr/bin/env bash" {} \;
  } | sort -u
}

install_system_docs() {
  local installed_count=0

  if [[ $EUID -ne 0 ]]; then
    log "ERROR" "Instalacja wymaga uprawnień root. Użyj sudo."
    return 1
  fi

  log "INFO" "Installing documentation in /usr/share/man/man1/"

  find "$TARGET_DIR" -name "*.1.gz" | while read -r gz_file; do
    local filename
    filename=$(basename "$gz_file")
    cp "$gz_file" "/usr/share/man/man1/$filename"
    ((installed_count++))
    log "INFO" "Installed: $filename"
  done

  if command -v mandb &>/dev/null; then
    log "INFO" "Updating man database..."
    mandb -q
  fi

  log "INFO" "Installation complete. Installed $installed_count files."
}

#;
# # BashMan — a documentation generator for bash functions. Prepare man pages based on coments in your code.
#
# ## Usage:
#
#   bashman [OPTIONS] [SOURCE_DIRECTORY]
#
# ### OPTIONS:
#       -t, --target – DIR Target directory for documentation (default: docs)
#       -i, --install – Install documentation in /usr/share/man/man1
#       -h, --help – Display this help
#
# ### ARGUMENTS:
#       SOURCE_DIRECTORY Directory with bash scripts (default: .)
#
# ### EXAMPLES:
#   ```bash
#       $ bashman # Generate docs from current directory to ./docs
#       $ bashman -t /tmp/docs ./scripts # Generate docs from ./scripts to /tmp/docs
#       $ bashman -i ./scripts # Generate and install in system
#   ```
# ## Comment format:
#
# Documentation comments must be placed directly above the function:
#
# ```
#     #;
#     # # Function name
#     #
#     # Function description in markdown format
#     #
#     # ## Parameters
#     # - \$1: first parameter
#     # - \$2: second parameter
#     #
#     # ## Example
#     # \`\`\`bash
#     # my_function "test" "123"
#     # \`\`\`
#     #;
#     my_function() {
#         # function code
#     }
# ```
# ## Licence:
#
# MIT Licence
#;
function bashman() {
  log "INFO" "BashMan Generator - start"

  parse_arguments "$@"

  if [[ $_HELP -eq 1 ]]; then
    return 0
  fi

  check_dependencies
  check_source_directory
  check_target_directory

  local total_files=0

  while IFS= read -r -d '' file; do
    process_file "$file"
    ((total_files++))
  done < <(find_bash_files | sort -u | tr '\n' '\0')

  if [[ $total_files -eq 0 ]]; then
    log "WARN" "No bash files found in directory: $SOURCE_DIR"
    return 0
  fi

  log "INFO" "Przetworzono $total_files plików"

  if [[ "$INSTALL_MODE" == true ]]; then
    install_system_docs
  fi

  if [[ "$INSTALL_MODE" == false ]]; then
    echo ""
    echo "To install documentation in the system, use:"
    echo "  sudo $0 -i $SOURCE_DIR"
  fi
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f bashman
else
  bashman "$@"
fi
