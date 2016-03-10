/* gmp.h stub */

#ifndef __STUB__GMP_H__
#define __STUB__GMP_H__

#if defined(__x86_64__) || \
    defined(__sparc64__) || \
    defined(__arch64__) || \
    defined(__powerpc64__) || \
    defined(__s390x__)
#include "gmp-64.h"
#else
#include "gmp-32.h"
#endif

#endif