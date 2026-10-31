#!/usr/bin/env python3
"""Diagnostic logging for eden-nx2 on the PS5 (lines tagged NX2DIAG in stderr.log).

Run on the eden-nx2 source tree that is about to be built:  diag-nx2.py <eden-dir>
Idempotent; an anchor that is not found is reported and skipped (never fatal).
Remove by running the build with DIAG=0 (the swap re-syncs a clean tree).
"""
import sys
from pathlib import Path

root = Path(sys.argv[1])


def edit(rel, anchor, new, include=None):
    path = root / rel
    text = path.read_text()
    if "NX2DIAG" in text:
        print(f"diag: {rel} already instrumented")
        return
    if text.count(anchor) != 1:
        print(f"diag: AVISO anchor not found (or not unique) in {rel}: {anchor.strip()[:60]!r}")
        return
    text = text.replace(anchor, new + anchor)
    if include and include not in text:
        first = text.index("#include")
        text = text[:first] + include + "\n" + text[first:]
    path.write_text(text)
    print(f"diag: instrumented {rel}")


# Which loader runs, and why: the stack of the crash showed AppLoader_NSO::Load for a loose ExeFS.
edit(
    "src/core/loader/loader.cpp",
    "    // Special case: 00 is either a NCA or NAX.\n",
    '''    std::fprintf(stderr,
                 "[NX2DIAG] GetLoader file=%s type=%s filename_type=%s containing_dir=%d "
                 "deconstructed_ok=%d\\n",
                 file->GetName().c_str(), GetFileTypeString(type).c_str(),
                 GetFileTypeString(filename_type).c_str(), file->GetContainingDirectory() != nullptr,
                 IdentifyFileLoader<AppLoader_DeconstructedRomDirectory>(file).has_value());
''',
    include="#include <cstdio>",
)

# The crash: a null access inside WalkBlock, called from ZeroBlock while an NSO is loaded.
edit(
    "src/core/memory.cpp",
    "        if (!AddressSpaceContains(*current_page_table, addr, size)) {\n            on_unmapped(offset, size, addr);\n",
    '''        {
            static std::atomic<int> diag_calls{0};
            const bool diag_null = current_page_table == nullptr ||
                                   current_page_table->entries.data() == nullptr;
            if (diag_null || diag_calls.fetch_add(1) < 12) {
                std::fprintf(stderr,
                             "[NX2DIAG] WalkBlock addr=%#llx size=%zu table=%p entries=%p "
                             "entries_size=%zu%s\\n",
                             static_cast<unsigned long long>(GetInteger(addr)), size,
                             static_cast<const void*>(current_page_table),
                             current_page_table ? static_cast<const void*>(current_page_table->entries.data()) : nullptr,
                             current_page_table ? static_cast<size_t>(current_page_table->entries.size()) : size_t{0},
                             diag_null ? "  <-- NULL, returning false instead of crashing" : "");
                std::fflush(stderr);
            }
            if (diag_null) {
                return false;
            }
        }
''',
    include="#include <cstdio>",
)
