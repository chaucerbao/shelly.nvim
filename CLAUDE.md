# Shelly NVIM

## Overview

This is a Neovim plugin written in Lua. It runs selected text through a shell command, and displays the results in a scratch buffer.

## Architecture

### Files

- The main entry point for this plugin is an exported function called `execute()`, inside `./lua/shelly/init.lua`, that determines which filetype runner to use, executes it, and displays the results in a scratch buffer.
- Utility functions for shared logic are in `./lua/shelly/utils.lua`.
- Filetype runners for supported filetypes are located in `./lua/shelly/filetypes/<filetype>.lua`. They each export an `execute()` function that parses and passes selected code to a shell command.

## Implementation

- Optimize the code for performance
- Make the code concise, but use descriptive variable and function names
- Document the code using LuaCATS annotations
- Show error messages using `vim.notify()`
