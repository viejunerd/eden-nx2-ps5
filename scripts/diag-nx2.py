#!/usr/bin/env python3
"""Diagnostic logging for eden-nx2 on the PS5 (lines tagged NX2DIAG in stderr.log).

Run on the eden-nx2 source tree that is about to be built:  diag-nx2.py <eden-dir>
Idempotent; an anchor that is not found is reported and skipped (never fatal).
Remove by running the build with DIAG=0 (the swap re-syncs a clean tree).
"""
import sys
from pathlib import Path

root = Path(sys.argv[1])


def edit(rel, anchor, new, include=None, marker="NX2DIAG", after=False):
    path = root / rel
    text = path.read_text()
    if marker in text:
        print(f"diag: {rel} already instrumented ({marker})")
        return
    if text.count(anchor) != 1:
        print(f"diag: AVISO anchor not found (or not unique) in {rel}: {anchor.strip()[:60]!r}")
        return
    text = text.replace(anchor, anchor + new if after else new + anchor)
    if include:
        for inc in include.split("\n"):
            if inc not in text:
                first = text.index("#include")
                text = text[:first] + inc + "\n" + text[first:]
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

# The old crash: a null access inside WalkBlock. Kept only as a guard (no per-call print).
edit(
    "src/core/memory.cpp",
    "        if (!AddressSpaceContains(*current_page_table, addr, size)) {\n            on_unmapped(offset, size, addr);\n",
    '''        if (current_page_table == nullptr || current_page_table->entries.data() == nullptr) {
            std::fprintf(stderr, "[NX2DIAG] WalkBlock with a null page table, returning false\\n");
            return false;
        }
''',
    include="#include <cstdio>",
    marker="NX2DIAG] WalkBlock with a null",
)

# The guest stopped touching memory and compiling code after its graphics boot: what are its threads doing?
edit(
    "src/core/core.cpp",
    "    std::atomic_bool is_paused{};\n",
    "    std::jthread diag_watchdog; // NX2DIAG\n",
    include="#include <thread>\n#include <chrono>\n#include <cstdio>",
    marker="std::jthread diag_watchdog",
)
edit(
    "src/core/core.cpp",
    "        core_timing.SyncPause(false);\n        is_paused.store(false, std::memory_order_relaxed);\n",
    '''        if (!diag_watchdog.joinable()) {
            // NX2DIAG: every 15 s (40 times) list each guest thread: state 1 = waiting, 2 = runnable
            // (no wait reason = running or spinning). pc/lr are the context saved when the thread
            // last stopped, so they only mean something for waiting threads.
            diag_watchdog = std::jthread([this](std::stop_token stop) {
                for (int tick = 1; tick <= 40 && !stop.stop_requested(); ++tick) {
                    for (int i = 0; i < 150 && !stop.stop_requested(); ++i)
                        std::this_thread::sleep_for(std::chrono::milliseconds(100));
                    if (stop.stop_requested()) break;
                    auto processes = kernel.GetProcessList();
                    std::fprintf(stderr, "[NX2DIAG] threads t=%ds processes=%zu\\n", tick * 15, processes.size());
                    for (auto& process : processes) {
                        Kernel::KScopedLightLock ll{process->GetListLock()};
                        for (auto& thread : process->GetThreadList()) {
                            const auto& ctx = thread.GetContext();
                            std::fprintf(stderr,
                                         "[NX2DIAG]  %s tid=%llu core=%d state=%u wait=%u pc=%#llx lr=%#llx sp=%#llx\\n",
                                         process->GetName(), static_cast<unsigned long long>(thread.GetThreadId()),
                                         static_cast<int>(thread.GetActiveCore()),
                                         static_cast<unsigned>(thread.GetState()) & 0xF,
                                         static_cast<unsigned>(thread.GetWaitReasonForDebugging()),
                                         static_cast<unsigned long long>(ctx.pc),
                                         static_cast<unsigned long long>(ctx.lr),
                                         static_cast<unsigned long long>(ctx.sp));
                        }
                    }
                    std::fflush(stderr);
                }
            });
        }
''',
    marker="NX2DIAG: every 15 s",
    after=True,
)

# An unknown IPC command: show the whole request, not 8 words (the log shows only the first 8).
edit(
    "src/core/hle/service/service.cpp",
    "    system.GetReporter().SaveUnimplementedFunctionReport(ctx, ctx.GetCommand(), function_name, service_name);\n",
    '''    {
        static std::atomic<int> diag_unknown{0};
        if (diag_unknown.fetch_add(1) < 300) {
            std::fprintf(stderr, "[NX2DIAG] unknown IPC %s::%u words:", service_name,
                         static_cast<unsigned>(ctx.GetCommand()));
            for (int i = 0; i < 24; ++i)
                std::fprintf(stderr, " %x", static_cast<unsigned>(cmd_buf[i]));
            std::fprintf(stderr, "\\n");
        }
    }
''',
    include="#include <cstdio>\n#include <atomic>",
    marker="NX2DIAG] unknown IPC",
)
