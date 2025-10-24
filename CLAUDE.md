# Shelly NVIM

## Overview

This is a Neovim plugin written in Lua. It runs selected text through a shell command, and displays the results in a scratch buffer.

## Architecture

### Utility Functions

Utility functions are located in `./lua/shelly/utils.lua`.

- `parse_selection()` returns:
  - A list of `lines`, in order of priority as follows:
    1. The visually selected text (characterwise, linewise, or blockwise)
    2. The lines within a Markdown code block surrounding the current line
    3. The entire buffer
  - The `filetype`, determined by:
    1. If within a Markdown code block, use the language identifier
    2. Otherwise, use the `filetype` of the buffer

- `parse_context()` runs through each line of the current buffer:
  1. Map over the line to remove common code comment prefixes (line or block).
  2. Returns lines within Markdown code blocks that have a `context` or `ctx` language identifier, up until the current Markdown code block if within one.

- `evaluate(lines)` runs through each line in the `lines` list and:
  1. Remove common line or block code comment prefixes.
  2. If the line starts with a single word prefixed with `@@`, store the word in a `shelly_args` table, with a value of:
     a. If the following non-space character is an `=`, set the value to the right operand.
     b. If the word starts with `no`, set the value to `false`
     c. Otherwise, set the value to `true`
  3. If the line contains an `=` with operands on each side (ignoring spaces), store it in a `variables` table. For every subsequent lines replace all instances of the left operand with the right operand.
  4. If the line contains a `:` with operands on each side (ignoring spaces), store it in a `dictionary` table.
  5. If the line contains only a command line argument, either short or long form, store it in a `command_args` list.
  6. If the line contains only a URL, store it in a `urls` list.

  Finally, return a table containing each variable in the list above.

- `execute_shell(command)` asynchronously executes the `command`, which is a list of string arguments, and returns a table that consists of `stdout` lines and `stderr` lines.

### Filetype Runners

Shell runners for supported filetypes are located in `./lua/shelly/filetypes/<filetype>.lua`. They each file exports an `execute()` function that: 1. Runs `parse_selection()`, storing results into `selection`. And runs `parse_context()`, storing results into `context`. 2. Runs through each line of `selection.lines`, skipping empty lines (ignore spaces)

### Entry Point

The main entry point for this plugin is an exported function called `execute()` inside `./lua/shelly/init.lua`. It uses helper functions to:

## Implementation

- Optimize the code for performance
- Make the code concise, but use descriptive variable and function names
- Document the code using LuaCATS annotations
- Show error messages using `vim.notify()`
