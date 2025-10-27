# Shelly NVIM

## Overview

This is a Neovim plugin written in Lua. It runs selected text through a shell command, and displays the results in a scratch buffer.

## Architecture

### Files

- `./lua/shelly/init.lua` is the main entry point for this plugin. The exported functions are meant to be used by the end-user to construct their own key mappings or user-defined commands.
- `./lua/shelly/utils.lua` contains shared utility functions used across this codebase.
- `./lua/shelly/types.lua` contains shared LuaCATS annotations used across this codebase.
- `./lua/shelly/filetypes/<filetype>.lua` are Filetype Runners that each export an `execute()` function, which is responsible for (optionally) parsing additional custom command arguments, constructing the full shell command, and executing it.

## Coding Guidelines

- Optimize the code for runtime performance. Prefer using Neovim's built-in Lua utility functions.
- Make the code concise, but use descriptive function and variable names. Don't use single-character names, except when tracking an index.
- Make sure all functions are documented and have accurate LuaCATS annotations for arguments and returns.
