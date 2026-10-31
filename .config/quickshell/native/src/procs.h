#pragma once

#include <QByteArray>
#include <QHash>
#include <QVariantList>

// utime + stime and starttime of one pid, kept between samples to derive CPU usage from the delta
struct ProcTick {
    quint64 ticks = 0;
    quint64 start = 0;
};

struct ProcSample {
    QVariantList cpu;      // [{pid, name, cpu}]
    QVariantList mem;      // [{pid, name, rss}]
    bool resample = false; // the previous sample is too old or too recent to derive CPU usage
};

// Read /proc/uptime and every /proc/<pid>/stat. CPU % is the utime+stime delta since `prev` (matched
// by pid and starttime), in percent of one thread like top; rss is in bytes. `prev` is replaced with
// this sample on every call, also when the result is unusable for CPU.
ProcSample sampleProcs(QHash<int, ProcTick>& prev, double& prevUptime, bool& hasPrev);
