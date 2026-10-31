#include "gpu.h"

#include <QByteArray>
#include <QDebug>
#include <QString>
#include <QVariantMap>

#include <cmath>
#include <dlfcn.h>
#include <limits>
#include <vector>

namespace {

constexpr double NaN = std::numeric_limits<double>::quiet_NaN();
constexpr int NVML_SUCCESS = 0;
constexpr int NVML_TEMPERATURE_GPU = 0;

using nvmlReturn_t = int;
struct nvmlDevice_st;
using nvmlDevice_t = nvmlDevice_st*;
struct nvmlUtilization_t {
    unsigned int gpu;
    unsigned int memory;
};
struct nvmlMemory_t {
    unsigned long long total;
    unsigned long long free;
    unsigned long long used;
};
struct nvmlMemory_v2_t {
    unsigned int version;
    unsigned long long total;
    unsigned long long reserved;
    unsigned long long free;
    unsigned long long used;
};

using InitFn = nvmlReturn_t (*)();
using CountFn = nvmlReturn_t (*)(unsigned int*);
using HandleFn = nvmlReturn_t (*)(unsigned int, nvmlDevice_t*);
using NameFn = nvmlReturn_t (*)(nvmlDevice_t, char*, unsigned int);
using UtilFn = nvmlReturn_t (*)(nvmlDevice_t, nvmlUtilization_t*);
using MemoryFn = nvmlReturn_t (*)(nvmlDevice_t, nvmlMemory_t*);
using MemoryV2Fn = nvmlReturn_t (*)(nvmlDevice_t, nvmlMemory_v2_t*);
using TempFn = nvmlReturn_t (*)(nvmlDevice_t, int, unsigned int*);
using U32Fn = nvmlReturn_t (*)(nvmlDevice_t, unsigned int*);

struct Nvml {
    bool loaded = false;
    bool ok = false;
    bool warned = false;
    InitFn init = nullptr;
    CountFn count = nullptr;
    HandleFn handle = nullptr;
    NameFn name = nullptr;
    UtilFn utilization = nullptr;
    MemoryFn memory = nullptr;
    MemoryV2Fn memoryV2 = nullptr;
    TempFn temperature = nullptr;
    U32Fn powerUsage = nullptr;
    U32Fn powerLimit = nullptr;
    U32Fn fanSpeed = nullptr;
    std::vector<nvmlDevice_t> devices;
};

Nvml& nvml() {
    static Nvml nvml;
    return nvml;
}

template <typename T>
void resolve(void* lib, T& fn, const char* symbol) {
    fn = reinterpret_cast<T>(::dlsym(lib, symbol));
}

bool load(Nvml& n) {
    if (n.ok)
        return true;
    if (n.loaded)
        return false;   // a previous attempt failed; retried by the next call after a driver load
    n.loaded = true;

    void* lib = ::dlopen("libnvidia-ml.so.1", RTLD_LAZY);
    if (lib == nullptr) {
        if (!n.warned) {
            n.warned = true;
            qWarning("gpu: libnvidia-ml.so.1 not available: %s", ::dlerror());
        }
        n.loaded = false;   // allow another attempt later
        return false;
    }

    resolve(lib, n.init, "nvmlInit_v2");
    if (n.init == nullptr)
        resolve(lib, n.init, "nvmlInit");
    resolve(lib, n.count, "nvmlDeviceGetCount_v2");
    if (n.count == nullptr)
        resolve(lib, n.count, "nvmlDeviceGetCount");
    resolve(lib, n.handle, "nvmlDeviceGetHandleByIndex_v2");
    if (n.handle == nullptr)
        resolve(lib, n.handle, "nvmlDeviceGetHandleByIndex");
    resolve(lib, n.name, "nvmlDeviceGetName");
    resolve(lib, n.utilization, "nvmlDeviceGetUtilizationRates");
    resolve(lib, n.memory, "nvmlDeviceGetMemoryInfo");
    resolve(lib, n.memoryV2, "nvmlDeviceGetMemoryInfo_v2");
    resolve(lib, n.temperature, "nvmlDeviceGetTemperature");
    resolve(lib, n.powerUsage, "nvmlDeviceGetPowerUsage");
    resolve(lib, n.powerLimit, "nvmlDeviceGetEnforcedPowerLimit");
    resolve(lib, n.fanSpeed, "nvmlDeviceGetFanSpeed");

    if (n.init == nullptr || n.count == nullptr || n.handle == nullptr || n.utilization == nullptr) {
        n.loaded = false;
        return false;
    }
    if (n.init() != NVML_SUCCESS) {
        n.loaded = false;
        return false;
    }

    unsigned int numDevices = 0;
    if (n.count(&numDevices) != NVML_SUCCESS)
        return false;
    n.devices.reserve(numDevices);
    for (unsigned int i = 0; i < numDevices; ++i) {
        nvmlDevice_t device = nullptr;
        if (n.handle(i, &device) == NVML_SUCCESS && device != nullptr)
            n.devices.push_back(device);
    }
    n.ok = true;
    return true;
}

} // namespace

QVariantList queryGpus(bool detail) {
    QVariantList rows;
    Nvml& n = nvml();
    if (!load(n))
        return rows;

    rows.reserve(qsizetype(n.devices.size()));
    for (unsigned int i = 0; i < n.devices.size(); ++i) {
        nvmlDevice_t device = n.devices[i];
        nvmlUtilization_t utilization {};
        const nvmlReturn_t utilRc = n.utilization(device, &utilization);

        QVariantMap row;
        row.insert(QStringLiteral("index"), int(i));
        row.insert(QStringLiteral("util"), utilRc == NVML_SUCCESS ? double(utilization.gpu) : NaN);
        if (detail) {
            char name[96] = {};
            row.insert(QStringLiteral("name"), n.name && n.name(device, name, sizeof name) == NVML_SUCCESS
                                                   ? QString::fromUtf8(name)
                                                   : QString());
            double used = NaN;
            double total = NaN;
            if (n.memoryV2 != nullptr) {
                nvmlMemory_v2_t mem {};
                mem.version = sizeof(nvmlMemory_v2_t) | (2u << 24);
                if (n.memoryV2(device, &mem) == NVML_SUCCESS) {
                    used = double(mem.used) / 1048576.0;
                    total = double(mem.total) / 1048576.0;
                }
            }
            if (n.memory != nullptr && (std::isnan(used) || std::isnan(total))) {
                nvmlMemory_t mem {};
                if (n.memory(device, &mem) == NVML_SUCCESS) {
                    used = double(mem.used) / 1048576.0;
                    total = double(mem.total) / 1048576.0;
                }
            }
            row.insert(QStringLiteral("memUsed"), used);
            row.insert(QStringLiteral("memTotal"), total);

            unsigned int temp = 0;
            row.insert(QStringLiteral("temp"), n.temperature
                                                    && n.temperature(device, NVML_TEMPERATURE_GPU, &temp) == NVML_SUCCESS
                                                ? double(temp)
                                                : NaN);
            unsigned int power = 0;
            row.insert(QStringLiteral("power"), n.powerUsage && n.powerUsage(device, &power) == NVML_SUCCESS
                                                    ? double(power) / 1000.0
                                                    : NaN);
            unsigned int limit = 0;
            row.insert(QStringLiteral("powerLimit"), n.powerLimit && n.powerLimit(device, &limit) == NVML_SUCCESS
                                                         ? double(limit) / 1000.0
                                                         : NaN);
            unsigned int fan = 0;
            row.insert(QStringLiteral("fan"), n.fanSpeed && n.fanSpeed(device, &fan) == NVML_SUCCESS ? double(fan)
                                                                                                    : NaN);
        }
        rows.append(row);
    }
    return rows;
}
