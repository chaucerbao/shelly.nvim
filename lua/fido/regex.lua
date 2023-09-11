return {
  -- General
  empty_line = '^%s*$',

  -- Fido
  comment = '^%s*#',
  flag = '^%s*-',

  header_separator = '^%s*=+%s*$',
  body_separator = '^%s*-+%s*$',

  -- Key-Values
  key_colon_value = '^%s*(%S+)%s*:%s*(%S.*)%s*$',
  key_equals_value = '^%s*(%S+)%s*=%s*(%S.*)%s*$',

  -- HTTP
  method_url = '^%s*(%S+)%s+(%S+://%S+)%s*$',
  url = '^%s*(%S+://%S+)%s*$',
  method_path = '^%s*(%S+)%s+(/%S*)%s*$',
  path = '^%s*(/%S*)%s*$',

  url_schema = '^%s*(%S+)://(%S+)%s*$',
}
