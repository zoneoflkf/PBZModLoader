#pragma once
#include <algorithm>

// Segment allocation is serialized across game instances. Each open segment
// reserves its full capacity so the hot write path needs no directory scan.
class EvidenceLog {
    static constexpr DWORD segmentLimit=8*1024*1024;
    static constexpr U64 directoryLimit=2ULL*1024*1024*1024;
    static constexpr char shutdownLine[]="process-detach shutdown=true (not an exit-code assertion)\r\n";
    fs::path run;
    HANDLE file=INVALID_HANDLE_VALUE;
    DWORD bytes=0;
    unsigned segment=0;
    ULONGLONG retryAt=0;
    SRWLOCK lock=SRWLOCK_INIT;

    struct Candidate {
        fs::path path;
        fs::file_time_type time;
        U64 size;
    };

    bool makeRoom() {
        const auto root=run.parent_path();
        if(GetFileAttributesW(root.c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) return false;
        static const std::wregex runName(L"[0-9]{8}-[0-9]{6}-[0-9]+-dll");
        static const std::wregex logName(L"loader(\\.[0-9]+)?\\.log");
        U64 total=segmentLimit;
        std::vector<Candidate> old;
        for(auto it=fs::recursive_directory_iterator(root); it!=fs::recursive_directory_iterator(); ++it) {
            const auto& path=it->path();
            auto attr=GetFileAttributesW(path.c_str());
            if(attr==INVALID_FILE_ATTRIBUTES) return false;
            if(attr & FILE_ATTRIBUTE_REPARSE_POINT) { it.disable_recursion_pending(); continue; }
            if(!it->is_regular_file()) continue;
            U64 size=it->file_size();
            total+=size;
            if(path.parent_path().parent_path()!=root ||
               !std::regex_match(path.parent_path().filename().wstring(),runName) ||
               !std::regex_match(path.filename().wstring(),logName)) continue;
            // Writers deny write sharing. Account for their remaining capacity
            // and leave locked files alone, including active legacy loader.log.
            Handle probe(CreateFileW(path.c_str(),GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
                                     nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr));
            if(probe.h==INVALID_HANDLE_VALUE) {
                if(size<segmentLimit) total+=segmentLimit-size;
                continue;
            }
            old.push_back({path,it->last_write_time(),size});
        }
        std::sort(old.begin(),old.end(),[](const Candidate& a,const Candidate& b) {
            return a.time!=b.time ? a.time<b.time : a.path<b.path;
        });
        for(const auto& item:old) {
            if(total<=directoryLimit) break;
            if(DeleteFileW(item.path.c_str())) {
                total-=item.size;
                if(item.path.parent_path()!=run) RemoveDirectoryW(item.path.parent_path().c_str());
            }
        }
        return total<=directoryLimit;
    }

    bool openSegment() {
        Handle gate(CreateMutexW(nullptr,FALSE,L"Local\\PBZModLoaderEvidenceQuota"));
        if(!gate.h) return false;
        DWORD result=WaitForSingleObject(gate.h,1000);
        if(result!=WAIT_OBJECT_0 && result!=WAIT_ABANDONED) return false;
        struct Unlock { HANDLE mutex; ~Unlock(){ ReleaseMutex(mutex); } } unlock{gate.h};
        fs::create_directories(run.parent_path());
        if(!makeRoom()) return false;
        fs::create_directories(run);
        if(GetFileAttributesW(run.c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) return false;
        auto path=run/(segment ? L"loader."+std::to_wstring(segment)+L".log" : L"loader.log");
        file=CreateFileW(path.c_str(),FILE_APPEND_DATA,FILE_SHARE_READ,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr);
        if(file==INVALID_HANDLE_VALUE) return false;
        ++segment;
        bytes=0;
        return true;
    }

public:
    ~EvidenceLog() { if(file!=INVALID_HANDLE_VALUE) CloseHandle(file); }
    EvidenceLog()=default;
    EvidenceLog(const EvidenceLog&)=delete;
    EvidenceLog& operator=(const EvidenceLog&)=delete;

    void initialize(const fs::path& directory) { run=directory; }
    void append(const std::string& line) noexcept {
        AcquireSRWLockExclusive(&lock);
        struct Unlock { SRWLOCK* lock; ~Unlock(){ ReleaseSRWLockExclusive(lock); } } unlock{&lock};
        if(run.empty() || line.size()>segmentLimit-sizeof(shutdownLine)) return;
        if(file!=INVALID_HANDLE_VALUE && bytes+line.size()+sizeof(shutdownLine)>segmentLimit) {
            CloseHandle(file);
            file=INVALID_HANDLE_VALUE;
        }
        if(file==INVALID_HANDLE_VALUE) {
            auto now=GetTickCount64();
            if(now<retryAt) return;
            retryAt=now+5000;
            try { if(!openSegment()) return; }
            catch(...) { return; }
            retryAt=0;
        }
        DWORD written=0;
        WriteFile(file,line.data(),static_cast<DWORD>(line.size()),&written,nullptr);
        bytes+=written;
    }

    // Process detach runs under loader lock, after other threads may have died.
    void shutdown() noexcept {
        if(!TryAcquireSRWLockExclusive(&lock)) return;
        if(file!=INVALID_HANDLE_VALUE) {
            DWORD written;
            WriteFile(file,shutdownLine,sizeof(shutdownLine)-1,&written,nullptr);
        }
        ReleaseSRWLockExclusive(&lock);
    }
};
