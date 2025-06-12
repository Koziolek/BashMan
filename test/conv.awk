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
