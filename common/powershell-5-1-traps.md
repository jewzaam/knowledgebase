# PowerShell 5.1 Traps

Observed while building scripts on Windows PowerShell 5.1.

- `ConvertFrom-Json` returns a JSON array as a single object, so
  `x | ConvertFrom-Json | Sort-Object` sees one item. Parenthesize first:
  `(x | ConvertFrom-Json) | Sort-Object`.
- Variable names are case-insensitive: a local `$b` overwrites a parameter
  `$B`.
- Source files without a BOM are read as ANSI, so non-ASCII characters in a
  script are misread. Keep scripts ASCII.
- `Set-Content -Encoding utf8` writes a BOM. This breaks a data file whose
  first field is later used as a path.
