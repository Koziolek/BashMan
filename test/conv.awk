BEGIN {
    in_comment = 0;
    block = "";
    next_line_is_func = 0;
    first_entry = 1;
    print "[";
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

            # Dodaj przecinek przed kolejnymi elementami
            if (!first_entry) {
                print ",";
            } else {
                first_entry = 0;
            }

            # Utworz obiekt JSON
            printf "  {\n";
            printf "    \"function_name\": \"%s\",\n", func_name;
            printf "    \"comment\": \"%s\"\n", escape_json(block == "" ? "# Brak dokumentacji" : block);
            printf "  }";
        }
        next_line_is_func = 0;
    }
}
END {
    print "";
    print "]";
}

function escape_json(str) {
    # Escape special characters for JSON
    gsub(/\\/, "\\\\", str);
    gsub(/"/, "\\\"", str);
    gsub(/\n/, "\\n", str);
    gsub(/\r/, "\\r", str);
    gsub(/\t/, "\\t", str);
    return str;
}