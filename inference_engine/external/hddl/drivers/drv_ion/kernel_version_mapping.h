// Copyright (C) 2019 Intel Corporation
//
// SPDX-License-Identifier: Apache-2.0
#ifndef __HDDL_KERNEL_VERSION_MAPPING__
#define __HDDL_KERNEL_VERSION_MAPPING__

#include <linux/version.h>

#ifdef CentOS
#if RHEL_RELEASE_CODE >= RHEL_RELEASE_VERSION(7, 5)
#define MAPPED_VERSION KERNEL_VERSION(4, 16, 0)
#elif RHEL_RELEASE_CODE >= RHEL_RELEASE_VERSION(7, 4)
#define MAPPED_VERSION KERNEL_VERSION(4, 6, 0)
#endif

#else
#define MAPPED_VERSION LINUX_VERSION_CODE
#endif

#endif
