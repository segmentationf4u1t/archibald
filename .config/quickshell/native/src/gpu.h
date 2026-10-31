#pragma once

#include <QVariantList>

// NVML through dlopen("libnvidia-ml.so.1"); an empty list when the library or a GPU is unavailable.
// Rows are {index, util} or, with `detail`, {index, name, util, memUsed, memTotal, temp, power,
// powerLimit, fan} in MiB, °C, W and %; NaN marks a value the driver does not report.
QVariantList queryGpus(bool detail);
