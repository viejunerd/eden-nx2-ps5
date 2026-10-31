// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
// Folder games: extracted titles in the game files' roms/ folder, found the way eden-nx2's game
// list does it (any file named `main`), here only inside an exefs/ folder that also holds
// main.npdm: "Game/base/exefs/main" and "Game/updates/exefs/main" are two entries.
#include <algorithm>
#include <string>
#include <sys/stat.h>
#include <vector>

#include "native_directory.h"
#include "settings_store.h"

namespace Eden {

namespace folder_games_detail {
inline bool IsFileAt(const std::string& path) {
    struct stat info {};
    return stat(path.c_str(), &info) == 0 && S_ISREG(info.st_mode);
}

inline void Find(const std::string& roms, const std::string& relative, int depth, std::vector<std::string>& found) {
    if (depth > 4 || found.size() >= 512) return;
    std::error_code error;
    const std::string folder = relative.empty() ? roms : roms + "/" + relative;
    for (const auto& entry : ReadNativeDirectory(folder, error)) {
        const std::string name = entry.path().filename().string();
        if (name.empty() || name[0] == '.') continue;
        const std::string child = relative.empty() ? name : relative + "/" + name;
        struct stat info {};
        if (stat((roms + "/" + child).c_str(), &info) != 0 || !S_ISDIR(info.st_mode)) continue;
        if (name == "exefs") {
            if (!relative.empty() && IsFileAt(roms + "/" + child + "/main") &&
                IsFileAt(roms + "/" + child + "/main.npdm") && IsFolderGame(child + "/main"))
                found.push_back(child + "/main");
        } else {
            Find(roms, child, depth + 1, found);
        }
    }
}
}  // namespace folder_games_detail

// The folder games under roms, as library names ("Game/base/exefs/main"), sorted.
inline std::vector<std::string> FindFolderGames(const std::string& roms) {
    std::vector<std::string> found;
    folder_games_detail::Find(roms, {}, 0, found);
    std::sort(found.begin(), found.end());
    return found;
}

// "Game [base]" for "Game/base/exefs/main", "Game" for "Game/exefs/main".
inline std::string FolderGameTitle(const std::string& name) {
    const std::size_t first = name.find('/');
    const std::size_t last = name.rfind("/exefs/main");
    std::string title = name.substr(0, first);
    if (first != std::string::npos && first < last) title += " [" + name.substr(first + 1, last - first - 1) + "]";
    return title;
}

}  // namespace Eden
