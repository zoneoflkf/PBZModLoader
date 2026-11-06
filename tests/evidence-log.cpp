#include "../src/core.hpp"
#include "../src/evidence-log.hpp"
#include <winioctl.h>

int main() {
    const fs::path root=fs::temp_directory_path()/("pbz-log-test-"+std::to_string(GetCurrentProcessId()));
    try {
        check(fs::create_directory(root),"create unique fixture");
        constexpr U64 expectedBudget=2ULL<<30;
        // Leave 128 MiB for rotation fixtures without writing 2 GiB of data.
        const auto ballast=root/L"retained.bin";
        {
            Handle sparse(CreateFileW(ballast.c_str(),GENERIC_WRITE,0,nullptr,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,nullptr));
            DWORD returned=0;
            check(DeviceIoControl(sparse.h,FSCTL_SET_SPARSE,nullptr,0,nullptr,0,&returned,nullptr),"create sparse quota fixture");
        }
        fs::resize_file(ballast,expectedBudget-(128ULL<<20));
        auto oldest=root/L"20260101-000000-1-dll", recent=root/L"20260102-000000-2-dll";
        fs::create_directory(oldest);
        fs::create_directory(recent);
        const auto oldFile=oldest/L"loader.log", recentFile=recent/L"loader.log";
        std::ofstream(oldFile).close();
        fs::resize_file(oldFile,112ULL<<20);
        fs::last_write_time(oldFile,fs::file_time_type::clock::now()-std::chrono::hours(24));
        std::ofstream(recentFile).close();
        fs::resize_file(recentFile,8ULL<<20);
        auto run=root/L"20260103-000000-3-dll";
        EvidenceLog logger;
        logger.initialize(run);
        std::string record(4096,'x');
        logger.append(record);
        check(fs::exists(oldFile),"retain history at quota");
        for(int i=1;i<5000;++i) logger.append(record);
        logger.shutdown();
        check(!fs::exists(oldFile) && fs::exists(recentFile),"oldest evicted first");
        check(fs::exists(run/L"loader.2.log"),"multiple rotations");
        U64 written=0;
        for(const auto& entry:fs::directory_iterator(run)) {
            check(entry.file_size()<=(8ULL<<20),"segment limit");
            written+=entry.file_size();
        }
        check(written>5000ULL*record.size() && written<5000ULL*record.size()+128,"all records plus shutdown");
        // Unrelated data consumes the quota but is never evicted.
        auto other=root/L"keep.bin";
        std::ofstream(other).close();
        fs::resize_file(other,128ULL<<20);
        EvidenceLog blocked;
        auto second=root/L"20260104-000000-4-dll";
        blocked.initialize(second);
        blocked.append(record);
        check(fs::exists(other) && !fs::exists(second) && fs::exists(run/L"loader.2.log"),"fail closed, protect active segment");
        fs::remove(other);
        Sleep(5100);
        for(int i=0;i<40000;++i) blocked.append(record);
        check(!fs::exists(second/L"loader.log") && fs::exists(second/L"loader.19.log"),"evict early segments of ongoing run");
        check(fs::exists(run/L"loader.2.log"),"preserve other active writer");
        U64 total=0;
        for(const auto& entry:fs::recursive_directory_iterator(root))
            if(entry.is_regular_file()) total+=entry.file_size();
        check(total<=expectedBudget,"sustained spam stays within directory budget");
        std::cout<<"PASS evidence log rotation and directory quota\n";
    } catch(const std::exception& error) {
        std::cerr<<error.what()<<'\n';
        return 1;
    }
    fs::remove_all(root);
}
