/*****************************************************************************
 * asm.S: AArch64 utility macros
 *****************************************************************************
 * Copyright (C) 2008-2025 x264 project
 *
 * Authors: Mans Rullgard <mans@mansr.com>
 *          David Conrad <lessen42@gmail.com>
 *          Janne Grunau <janne-x264@jannau.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@x264.com.
 *****************************************************************************/

#include "config.h"

#define GLUE(a, b) a ## b
#define JOIN(a, b) GLUE(a, b)

#ifdef PREFIX
#   define BASE _x264_
#   define SYM_PREFIX _
#else
#   define BASE x264_
#   define SYM_PREFIX
#endif

#ifdef BIT_DEPTH
#   define EXTERN_ASM JOIN(JOIN(BASE, BIT_DEPTH), _)
#else
#   define EXTERN_ASM BASE
#endif

#define X(s) JOIN(EXTERN_ASM, s)
#define X264(s) JOIN(BASE, s)
#define EXT(s) JOIN(SYM_PREFIX, s)

#ifdef __ELF__
#   define ELF
#else
#   define ELF  #
#endif

#ifdef __MACH__
#   define MACH
#else
#   define MACH #
#endif

#if HAVE_AS_FUNC
#   define FUNC
#else
#   define FUNC #
#endif

        .arch AS_ARCH_LEVEL
#if HAVE_AS_ARCHEXT_DOTPROD_DIRECTIVE
#define ENABLE_DOTPROD  .arch_extension dotprod
#define DISABLE_DOTPROD .arch_extension nodotprod
#else
#define ENABLE_DOTPROD
#define DISABLE_DOTPROD
#endif
#if HAVE_AS_ARCHEXT_I8MM_DIRECTIVE
#define ENABLE_I8MM  .arch_extension i8mm
#define DISABLE_I8MM .arch_extension noi8mm
#else
#define ENABLE_I8MM
#define DISABLE_I8MM
#endif
#if HAVE_AS_ARCHEXT_SVE_DIRECTIVE
#define ENABLE_SVE  .arch_extension sve
#define DISABLE_SVE .arch_extension nosve
#else
#define ENABLE_SVE
#define DISABLE_SVE
#endif
#if HAVE_AS_ARCHEXT_SVE2_DIRECTIVE
#define ENABLE_SVE2  .arch_extension sve2
#define DISABLE_SVE2 .arch_extension nosve2
#else
#define ENABLE_SVE2
#define DISABLE_SVE2
#endif

/* If we do support the .arch_extension directives, disable support for all
 * the extensions that we may use, in case they were implicitly enabled by
 * the .arch level. This makes it clear if we try to assemble an instruction
 * from an unintended extension set; we only allow assmbling such instructions
 * within regions where we explicitly enable those extensions. */
DISABLE_DOTPROD
DISABLE_I8MM
DISABLE_SVE
DISABLE_SVE2

.macro  function name, export=0, align=2
    .macro endfunc
.if \export
ELF     .size   EXTERN_ASM\name, . - EXTERN_ASM\name
.else
ELF     .size   \name, . - \name
.endif
FUNC    .endfunc
        .purgem endfunc
    .endm
        .text
        .align          \align
    .if \export
        .global EXTERN_ASM\name
ELF     .type   EXTERN_ASM\name, %function
FUNC    .func   EXTERN_ASM\name
EXTERN_ASM\name:
    .else
ELF     .type   \name, %function
FUNC    .func   \name
\name:
    .endif
.endm

.macro  const   name, align=2
    .macro endconst
ELF     .size   \name, . - \name
        .purgem endconst
    .endm
ELF     .section        .rodata
MACH    .const_data
        .align          \align
\name:
.endm

.macro  movrel rd, val, offset=0
#if defined(__APPLE__)
  .if \offset < 0
        adrp            \rd, \val@PAGE
        add             \rd, \rd, \val@PAGEOFF
        sub             \rd, \rd, -(\offset)
  .else
        adrp            \rd, \val+(\offset)@PAGE
        add             \rd, \rd, \val+(\offset)@PAGEOFF
  .endif
#elif defined(PIC) && defined(_WIN32)
  .if \offset < 0
        adrp            \rd, \val
        add             \rd, \rd, :lo12:\val
        sub             \rd, \rd, -(\offset)
  .else
        adrp            \rd, \val+(\offset)
        add             \rd, \rd, :lo12:\val+(\offset)
  .endif
#elif defined(PIC)
        adrp            \rd, \val+(\offset)
        add             \rd, \rd, :lo12:\val+(\offset)
#else
        ldr             \rd, =\val+\offset
#endif
.endm

#define FDEC_STRIDE 32
#define FENC_STRIDE 16


.macro SUMSUB_AB   sum, sub, a, b
    add         \sum,  \a,  \b
    sub         \sub,  \a,  \b
.endm

.macro unzip t1, t2, s1, s2
    uzp1        \t1,  \s1,  \s2
    uzp2        \t2,  \s1,  \s2
.endm

.macro transpose t1, t2, s1, s2
    trn1        \t1,  \s1,  \s2
    trn2        \t2,  \s1,  \s2
.endm

.macro transpose4x4.h v0, v1, v2, v3, t0, t1, t2, t3
    transpose   \t0\().2s,  \t2\().2s,  \v0\().2s,  \v2\().2s
    transpose   \t1\().2s,  \t3\().2s,  \v1\().2s,  \v3\().2s
    transpose   \v0\().4h,  \v1\().4h,  \t0\().4h,  \t1\().4h
    transpose   \v2\().4h,  \v3\().4h,  \t2\().4h,  \t3\().4h
.endm

.macro transpose4x8.h v0, v1, v2, v3, t0, t1, t2, t3
    transpose   \t0\().4s,  \t2\().4s,  \v0\().4s,  \v2\().4s
    transpose   \t1\().4s,  \t3\().4s,  \v1\().4s,  \v3\().4s
    transpose   \v0\().8h,  \v1\().8h,  \t0\().8h,  \t1\().8h
    transpose   \v2\().8h,  \v3\().8h,  \t2\().8h,  \t3\().8h
.endm


.macro transpose8x8.h r0, r1, r2, r3, r4, r5, r6, r7, r8, r9
    trn1        \r8\().8h,  \r0\().8h,  \r1\().8h
    trn2        \r9\().8h,  \r0\().8h,  \r1\().8h
    trn1        \r1\().8h,  \r2\().8h,  \r3\().8h
    trn2        \r3\().8h,  \r2\().8h,  \r3\().8h
    trn1        \r0\().8h,  \r4\().8h,  \r5\().8h
    trn2        \r5\().8h,  \r4\().8h,  \r5\().8h
    trn1        \r2\().8h,  \r6\().8h,  \r7\().8h
    trn2        \r7\().8h,  \r6\().8h,  \r7\().8h

    trn1        \r4\().4s,  \r0\().4s,  \r2\().4s
    trn2        \r2\().4s,  \r0\().4s,  \r2\().4s
    trn1        \r6\().4s,  \r5\().4s,  \r7\().4s
    trn2        \r7\().4s,  \r5\().4s,  \r7\().4s
    trn1        \r5\().4s,  \r9\().4s,  \r3\().4s
    trn2        \r9\().4s,  \r9\().4s,  \r3\().4s
    trn1        \r3\().4s,  \r8\().4s,  \r1\().4s
    trn2        \r8\().4s,  \r8\().4s,  \r1\().4s

    trn1        \r0\().2d,  \r3\().2d,  \r4\().2d
    trn2        \r4\().2d,  \r3\().2d,  \r4\().2d

    trn1        \r1\().2d,  \r5\().2d,  \r6\().2d
    trn2        \r5\().2d,  \r5\().2d,  \r6\().2d

    trn2        \r6\().2d,  \r8\().2d,  \r2\().2d
    trn1        \r2\().2d,  \r8\().2d,  \r2\().2d

    trn1        \r3\().2d,  \r9\().2d,  \r7\().2d
    trn2        \r7\().2d,  \r9\().2d,  \r7\().2d
.endm

.macro  transpose_8x16.b r0, r1, r2, r3, r4, r5, r6, r7, t0, t1
    trn1        \t0\().16b, \r0\().16b, \r1\().16b
    trn2        \t1\().16b, \r0\().16b, \r1\().16b
    trn1        \r1\().16b, \r2\().16b, \r3\().16b
    trn2        \r3\().16b, \r2\().16b, \r3\().16b
    trn1        \r0\().16b, \r4\().16b, \r5\().16b
    trn2        \r5\().16b, \r4\().16b, \r5\().16b
    trn1        \r2\().16b, \r6\().16b, \r7\().16b
    trn2        \r7\().16b, \r6\().16b, \r7\().16b

    trn1        \r4\().8h,  \r0\().8h,  \r2\().8h
    trn2        \r2\().8h,  \r0\().8h,  \r2\().8h
    trn1        \r6\().8h,  \r5\().8h,  \r7\().8h
    trn2        \r7\().8h,  \r5\().8h,  \r7\().8h
    trn1        \r5\().8h,  \t1\().8h,  \r3\().8h
    trn2        \t1\().8h,  \t1\().8h,  \r3\().8h
    trn1        \r3\().8h,  \t0\().8h,  \r1\().8h
    trn2        \t0\().8h,  \t0\().8h,  \r1\().8h

    trn1        \r0\().4s,  \r3\().4s,  \r4\().4s
    trn2        \r4\().4s,  \r3\().4s,  \r4\().4s

    trn1        \r1\().4s,  \r5\().4s,  \r6\().4s
    trn2        \r5\().4s,  \r5\().4s,  \r6\().4s

    trn2        \r6\().4s,  \t0\().4s,  \r2\().4s
    trn1        \r2\().4s,  \t0\().4s,  \r2\().4s

    trn1        \r3\().4s,  \t1\().4s,  \r7\().4s
    trn2        \r7\().4s,  \t1\().4s,  \r7\().4s
.endm

.macro  transpose_4x16.b r0, r1, r2, r3, t4, t5, t6, t7
    trn1        \t4\().16b, \r0\().16b,  \r1\().16b
    trn2        \t5\().16b, \r0\().16b,  \r1\().16b
    trn1        \t6\().16b, \r2\().16b,  \r3\().16b
    trn2        \t7\().16b, \r2\().16b,  \r3\().16b

    trn1        \r0\().8h,  \t4\().8h,  \t6\().8h
    trn2        \r2\().8h,  \t4\().8h,  \t6\().8h
    trn1        \r1\().8h,  \t5\().8h,  \t7\().8h
    trn2        \r3\().8h,  \t5\().8h,  \t7\().8h
.endm

.macro  transpose_4x8.b  r0, r1, r2, r3, t4, t5, t6, t7
    trn1        \t4\().8b,  \r0\().8b,  \r1\().8b
    trn2        \t5\().8b,  \r0\().8b,  \r1\().8b
    trn1        \t6\().8b,  \r2\().8b,  \r3\().8b
    trn2        \t7\().8b,  \r2\().8b,  \r3\().8b

    trn1        \r0\().4h,  \t4\().4h,  \t6\().4h
    trn2        \r2\().4h,  \t4\().4h,  \t6\().4h
    trn1        \r1\().4h,  \t5\().4h,  \t7\().4h
    trn2        \r3\().4h,  \t5\().4h,  \t7\().4h
.endm
