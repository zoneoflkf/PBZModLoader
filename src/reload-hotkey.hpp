#pragma once
#include "core.hpp"
#include <optional>
#include <string_view>

struct ReloadHotkey {
    UINT modifiers=MOD_ALT;
    UINT key=VK_F5;
    std::string name="Alt+F5";
    bool invalid=false;

    bool matches(LPARAM message) const {
        return HIWORD(message)==key && (LOWORD(message)&~MOD_NOREPEAT)==modifiers;
    }
};

inline std::optional<ReloadHotkey> parseReloadHotkey(const std::wstring& value) {
    std::wstring_view remaining=value;
    if(remaining.find_first_not_of(L" \t")==std::wstring_view::npos) return ReloadHotkey{};

    UINT modifiers=0;
    for(;;) {
        const auto separator=remaining.find(L'+');
        const auto part=remaining.substr(0,separator);
        const auto first=part.find_first_not_of(L" \t");
        if(first==std::wstring_view::npos) return std::nullopt;
        std::wstring token(part.substr(first,part.find_last_not_of(L" \t")-first+1));
        for(auto& ch:token) if(ch>=L'a' && ch<=L'z') ch-=L'a'-L'A';

        if(separator==std::wstring_view::npos) {
            if(token.size()==1 && ((token[0]>=L'A' && token[0]<=L'Z') || (token[0]>=L'0' && token[0]<=L'9')))
                return ReloadHotkey{modifiers,static_cast<UINT>(token[0]),utf8(value)};
            if(token.size()<2 || token.size()>3 || token[0]!=L'F' || token[1]<L'1' || token[1]>L'9' ||
               token.find_first_not_of(L"0123456789",1)!=std::wstring::npos) return std::nullopt;
            const auto function=std::stoul(token.substr(1));
            // Windows reserves F12 for the debugger.
            if(function>24 || function==12) return std::nullopt;
            return ReloadHotkey{modifiers,static_cast<UINT>(VK_F1+function-1),utf8(value)};
        }

        UINT modifier=0;
        if(token==L"ALT") modifier=MOD_ALT;
        else if(token==L"CTRL") modifier=MOD_CONTROL;
        else if(token==L"SHIFT") modifier=MOD_SHIFT;
        if(!modifier || (modifiers&modifier)) return std::nullopt;
        modifiers|=modifier;
        remaining.remove_prefix(separator+1);
    }
}

inline std::optional<ReloadHotkey> readReloadHotkey(const fs::path& configPath) {
    // Keep the file stable while Windows reads the INI. Retry on the next poll
    // if an editor is writing it or replacing it via a temporary file.
    Handle file(CreateFileW(configPath.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,
        OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr));
    if(file.h==INVALID_HANDLE_VALUE) return std::nullopt;
    try {
        if(auto hotkey=parseReloadHotkey(ini(configPath,L"Loader",L"ReloadHotkey"))) return hotkey;
    } catch(const std::runtime_error&) { /* Oversized INI value. */ }
    ReloadHotkey fallback;
    fallback.invalid=true;
    return fallback;
}
