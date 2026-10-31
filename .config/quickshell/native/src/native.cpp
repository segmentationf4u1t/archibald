#include "native.h"

#include <QtConcurrent/QtConcurrentRun>

#include "gpu.h"

Native::Native(QObject* parent)
    : QObject(parent) {}

Native::~Native() {
    if (m_worker.isRunning())
        m_worker.waitForFinished();   // the worker holds `this` until it returns
}

bool Native::sample() {
    if (m_busy.exchange(true))
        return false;
    if (m_worker.isRunning())
        m_worker.waitForFinished();   // a previous run is in its last few microseconds
    m_worker = QtConcurrent::run([this] {
        ProcSample sample;
        {
            QMutexLocker lock(&m_procMutex);
            sample = sampleProcs(m_proc.prev, m_proc.prevUptime, m_proc.hasPrev);
        }
        QVariantMap result;
        result.insert(QStringLiteral("cpu"), sample.cpu);
        result.insert(QStringLiteral("mem"), sample.mem);
        result.insert(QStringLiteral("resample"), sample.resample);
        m_busy.store(false);
        QMetaObject::invokeMethod(
            this,
            [this, result = std::move(result)] { emit sampled(result); },
            Qt::QueuedConnection
        );
    });
    return true;
}

void Native::reset() {
    QMutexLocker lock(&m_procMutex);
    m_proc.prev.clear();
    m_proc.prevUptime = 0;
    m_proc.hasPrev = false;
}

QVariantList Native::gpuUtil() { return queryGpus(false); }

QVariantList Native::gpuDetail() { return queryGpus(true); }
