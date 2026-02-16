---
name: ooxml
description: Pack and unpack Office documents (.docx, .pptx, .xlsx) for XML-level editing
allowed-tools: [Bash, Read, Write, Edit]
---

# OOXML Pack/Unpack

## When to Use
- Editing Office document XML directly (modifying slides, spreadsheet cells, document structure)
- Debugging corrupt Office files
- Programmatically generating or modifying .docx, .pptx, or .xlsx files
- When the `docx`, `pptx`, or `xlsx` skills need low-level XML access

## Scripts

### Unpack (extract and pretty-print XML)

```bash
python skills/ooxml/scripts/unpack.py <office_file> <output_directory>
```

Extracts the Office file (which is a ZIP archive) and pretty-prints all XML/rels files for readability.

### Pack (re-assemble from directory)

```bash
python skills/ooxml/scripts/pack.py <input_directory> <output_file> [--force]
```

Re-packs a directory into an Office file, condensing pretty-printed XML back to single-line format. Validates with LibreOffice (`soffice`) if available.

- `--force`: Skip validation (use when soffice is not installed)

## Dependencies

- Python 3.10+
- `defusedxml` (safe XML parsing)
- Optional: LibreOffice (`soffice`) for validation

## Workflow

1. **Unpack** the Office file to a directory
2. **Read/Edit** the XML files (e.g., `word/document.xml`, `ppt/slides/slide1.xml`)
3. **Pack** the directory back into an Office file
4. Open and verify the result

## Notes

- The pack script strips pretty-printing whitespace before re-zipping (Office apps expect condensed XML)
- For `.docx` files, the unpack script suggests an RSID for tracked changes
- `w:t` elements (text runs) are preserved as-is during condensing to avoid whitespace corruption
