#include "procs.h"

#include <QString>

#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

struct Row {
    int pid = 0;
    quint64 ticks = 0;
    quint64 start = 0;
    double rss = 0;
    double cpu = 0;
    qsizetype nameOff = -1;   // into the name buffer; -1 when no list was asked for
    qsizetype nameLen = 0;
};

qsizetype readFile(const char* path, char* buf, qsizetype cap) {
    int fd = ::open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    qsizetype n = ::read(fd, buf, cap - 1);
    ::close(fd);
    if (n <= 0)
        return -1;
    buf[n] = '\0';
    return n;
}

quint64 fieldU64(const char* start, const char* end) {
    quint64 v = 0;
    for (const char* p = start; p < end && *p >= '0' && *p <= '9'; ++p)
        v = v * 10 + quint64(*p - '0');
    return v;
}

// The 6 entries with the largest key, descending; ties keep input order (the same insertion used by
// the QML list this replaces).
void top6(const std::vector<Row>& rows, const std::vector<int>& pool, bool byCpu, int out[6], int& n) {
    n = 0;
    for (int idx: pool) {
        const double v = byCpu ? rows[idx].cpu : rows[idx].rss;
        int i = n;
        if (i == 6) {
            const double worst = byCpu ? rows[out[5]].cpu : rows[out[5]].rss;
            if (v <= worst)
                continue;
            i = 5;
            out[5] = idx;
        } else {
            out[n++] = idx;
        }
        while (i > 0 && (byCpu ? rows[out[i - 1]].cpu : rows[out[i - 1]].rss) < v) {
            out[i] = out[i - 1];
            out[i - 1] = idx;
            --i;
        }
    }
}

QVariantList toList(const std::vector<Row>& rows, const QByteArray& names, const int* idx, int n, bool byCpu) {
    QVariantList list;
    list.reserve(n);
    for (int i = 0; i < n; ++i) {
        const Row& r = rows[idx[i]];
        QVariantMap m;
        m.insert(QStringLiteral("pid"), r.pid);
        m.insert(QStringLiteral("name"), QString::fromUtf8(names.constData() + r.nameOff, r.nameLen));
        if (byCpu)
            m.insert(QStringLiteral("cpu"), r.cpu);
        else
            m.insert(QStringLiteral("rss"), r.rss);
        list.append(m);
    }
    return list;
}

bool numericName(const char* name, int& pid) {
    if (*name < '0' || *name > '9')
        return false;
    pid = 0;
    for (const char* p = name; *p; ++p) {
        if (*p < '0' || *p > '9' || pid > (1000000000 / 10))
            return false;
        pid = pid * 10 + (*p - '0');
    }
    return true;
}

} // namespace

ProcSample sampleProcs(QHash<int, ProcTick>& prev, double& prevUptime, bool& hasPrev) {
    static const long clkTck = ::sysconf(_SC_CLK_TCK);
    static const long pageSize = ::sysconf(_SC_PAGESIZE);

    ProcSample result;

    char buf[1024];
    qsizetype n = readFile("/proc/uptime", buf, sizeof buf);
    if (n <= 0)
        return result;
    double uptime = 0;
    {
        char* end = nullptr;
        uptime = std::strtod(buf, &end);
        if (end == buf)
            return result;
    }

    // /proc/[0-9]* in the order the shell glob produces: lexicographic by file name
    std::vector<std::string> pids;
    if (DIR* dir = ::opendir("/proc")) {
        while (dirent* entry = ::readdir(dir)) {
            int pid = 0;
            if (numericName(entry->d_name, pid))
                pids.emplace_back(entry->d_name);
        }
        ::closedir(dir);
    }
    std::sort(pids.begin(), pids.end());

    std::vector<Row> rows;
    rows.reserve(pids.size());
    QByteArray names;
    names.reserve(qsizetype(pids.size()) * 24);
    std::vector<int> known;   // rows whose pid and starttime match the previous sample
    known.reserve(pids.size());

    QHash<int, ProcTick> next;
    next.reserve(pids.size());

    for (const std::string& name: pids) {
        char path[64];
        qsizetype plen = qsizetype(std::snprintf(path, sizeof path, "/proc/%s/stat", name.c_str()));
        if (plen <= 0 || plen >= qsizetype(sizeof path))
            continue;
        qsizetype len = readFile(path, buf, sizeof buf);
        if (len <= 0)
            continue;   // the process vanished between readdir and open

        const char* line = buf;
        const char* end = buf + len;
        const char* open = static_cast<const char*>(std::memchr(line, '(', len));
        if (open == nullptr || open + 1 >= end)
            continue;
        const char* close = end;
        while (close > open && close[-1] != ')')
            --close;
        if (close == open)
            continue;
        --close;   // at ')'

        int pid = 0;
        numericName(name.c_str(), pid);

        Row row;
        row.pid = pid;
        const char* p = close + 1;
        if (p < end && *p == ' ')
            ++p;
        quint64 utime = 0;
        quint64 stime = 0;
        quint64 rss = 0;
        for (int field = 3; field <= 24 && p < end; ++field) {
            const char* next = static_cast<const char*>(std::memchr(p, ' ', qsizetype(end - p)));
            if (next == nullptr)
                next = end;
            if (field == 14)
                utime = fieldU64(p, next);
            else if (field == 15)
                stime = fieldU64(p, next);
            else if (field == 22)
                row.start = fieldU64(p, next);
            else if (field == 24)
                rss = fieldU64(p, next);
            p = next + 1;
        }
        row.ticks = utime + stime;
        row.rss = double(rss) * double(pageSize);

        const auto old = prev.constFind(pid);
        if (old != prev.constEnd() && old->start == row.start)
            known.push_back(int(rows.size()));

        row.nameOff = names.size();
        row.nameLen = close - open - 1;
        names.append(open + 1, row.nameLen);

        next.insert(pid, ProcTick {row.ticks, row.start});
        rows.push_back(row);
    }

    const double dt = hasPrev ? uptime - prevUptime : 0;
    const bool usable = hasPrev && dt >= 0.1 && dt <= 5;
    result.resample = !usable;

    std::vector<int> all(rows.size());
    for (qsizetype i = 0; i < qsizetype(rows.size()); ++i)
        all[i] = int(i);
    int idx[6];
    int count = 0;
    top6(rows, all, false, idx, count);
    result.mem = toList(rows, names, idx, count, false);

    if (usable) {
        for (int i: known)
            rows[i].cpu = 100.0 * double(rows[i].ticks - std::min(rows[i].ticks, prev.value(rows[i].pid).ticks))
                        / double(clkTck) / dt;
        count = 0;
        top6(rows, known, true, idx, count);
        result.cpu = toList(rows, names, idx, count, true);
    }

    prev = std::move(next);
    prevUptime = uptime;
    hasPrev = true;
    return result;
}
