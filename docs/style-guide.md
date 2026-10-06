# Style Guide

To maintain consistency across all scripts, follow these guidelines:

## Variable Naming
- Use UPPERCASE for constants and global variables
- Use lowercase for local/parameter variables  
- Use snake_case for all variable names
- Always quote variables to prevent word splitting

## Functions
- Use descriptive function names in snake_case
- Always declare local variables with `local` keyword
- Use consistent parameter naming and structure

## Error Handling
- All error messages should be printed to stderr with prefix "ERROR:"
- Use appropriate exit codes (0 = success, 1/2 = errors)
- Implement a centralized `error()` function for consistent messaging
- Check privileges and dependencies at the start of script execution
- Error messages should be clear and descriptive

## Configuration
- All scripts should source configuration from `$SCRIPT_DIR/config.sh`
- Validate required configuration parameters
- Use consistent naming for variable declarations (UPPERCASE for config vars)
- Declare all required variables in a validation list or array
- Load configuration early in script execution before any operations

## Logging
- Implement centralized `log()` function for timestamped output
- Log messages should follow format `[YYYY-MM-DD HH:MM:SS] message`
- Write to dedicated log file in standard location

## Options Parsing
- Use GNU-style long options (--help, --setup, etc.)
- Follow consistent usage message formatting
- Check that required arguments are provided before proceeding

## Code Style
- Use 4-space indentation consistently
- Add single blank lines between logical code blocks
- Ensure all shell commands are compatible with bash (set -euo pipefail)

# Script Template
A standardized template is available at [docs/templates/script-template.sh](templates/script-template.sh) to demonstrate the proper structure and style for new scripts or when refactoring existing ones.
