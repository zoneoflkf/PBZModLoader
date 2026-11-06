#include "../src/core.hpp"
#include "../src/evidence-log.hpp"
#include <winioctl.h>

static void testRunRetention(const fs::path& root) {
    check(evidenceRunLimit(L"")==10 && evidenceRunLimit(L"-1")==10 &&
          evidenceRunLimit(L"2x")==10 && evidenceRunLimit(L"00")==0,"parse retention");
    const auto runPath=[&](int day) {
        return root/("202601"+std::to_string(10+day)+"-000000-1-dll");
    };
    EvidenceLog disabled;
    disabled.initialize(runPath(0),L"",L"0");
    disabled.append("silent");
    check(!fs::exists(root),"disabled does not create evidence");
    EvidenceLog active;
    active.initialize(runPath(0));
    active.append("active");
    for(int day=1;day<=13;++day) {
        EvidenceLog logger;
        logger.initialize(runPath(day));
        logger.append("record");
        if(day==1) std::ofstream(runPath(day)/"verification.json")<<"{}";
        if(day==2) std::ofstream(runPath(day)/"loader.1.log")<<"old";
    }
    check(fs::exists(runPath(0)/"loader.log") && fs::exists(runPath(1)/"loader.log") &&
          fs::exists(runPath(1)/"verification.json"),"protect active and annotated runs");
    check(!fs::exists(runPath(2)) && !fs::exists(runPath(3)) &&
          fs::exists(runPath(4)/"loader.log"),"retain ten complete ordinary runs");
    EvidenceLog single;
    single.initialize(runPath(14),L"",L"1");
    single.append("latest");
    disabled.append("silent");
    check(!fs::exists(runPath(13)) && fs::exists(runPath(14)/"loader.log"),"custom limit");
    // Protected files still consume the budget, including their loader logs.
    std::ofstream(root/"ballast").close();
    fs::resize_file(root/"ballast",120ULL<<20);
    EvidenceLog blocked;
    blocked.initialize(runPath(15),L"120",L"1");
    blocked.append("no room");
    check(fs::exists(runPath(1)/"loader.log") && !fs::exists(runPath(15)),"protect evidence under quota pressure");
}

int main() {
    const fs::path root=fs::temp_directory_path()/("pbz-log-test-"+std::to_string(GetCurrentProcessId()));
    try {
        check(fs::create_directory(root),"create unique fixture");
        testRunRetention(root/L"retention");
        fs::remove_all(root/L"retention");
        check(evidenceBudget(L"-9")==120ULL<<20 && evidenceBudget(L"119")==120ULL<<20,"minimum budget");
        check(evidenceBudget(L"512")==512ULL<<20,"custom budget");
        check(evidenceBudget(L"4097")==4ULL<<30 && evidenceBudget(L"999999999999999999999")==4ULL<<30,"maximum budget");
        check(evidenceBudget(L"")==2ULL<<30 && evidenceBudget(L"256x")==2ULL<<30,"default budget");
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
