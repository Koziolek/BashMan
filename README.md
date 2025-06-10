#BashMan

BashMan — a documentation generator for bash functions. Prepare man pages based on coments in your code. 

## Usage:

```
    bashman [OPTIONS] [SOURCE_DIRECTORY]
```
### OPTIONS:
    `-t`, `--target` – DIR Target directory for documentation (default: docs)
    `-i`, `--install` – Install documentation in /usr/share/man/man1
    `-h`, `--help` – Display this help

### ARGUMENTS:
    `SOURCE_DIRECTORY` Directory with bash scripts (default: `.`)

## EXAMPLES:

```bash 
    $ bashman # Generate docs from current directory to ./docs
    $ bashman -t /tmp/docs ./scripts # Generate docs from ./scripts to /tmp/docs
    $ bashman -i ./scripts # Generate and install in system
```

## COMMENT FORMAT:

Documentation comments must be placed directly above the function:

```bash
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
```

## Licence 

[MIT Licence](LICENSE) 