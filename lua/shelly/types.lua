---@alias Evaluated {
---  shelly_args: table<string, boolean|string>,
---  shelly_substitutions: table<string, string>,
---  dictionary: table<string, string>,
---  command_args: string[],
---  urls: string[],
---  processed_lines: string[]
---}

---@alias FiletypeRunnerResult { stdout: string[], stderr: string[], filetype?: string | nil }

---@alias FiletypeRunner fun(
---  evaluated: Evaluated,
---  callback: fun(result: FiletypeRunnerResult)
---)
