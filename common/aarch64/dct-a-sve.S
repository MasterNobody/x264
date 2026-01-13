/****************************************************************************
 * dct-a-sve.S: aarch64 transform and zigzag
 *****************************************************************************
 * Copyright (C) 2009-2026 x264 project
 *
 * Authors: David Chen <david.chen@myais.com.cn>
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

#include "asm.S"
#include "dct-a-common.S"

ENABLE_SVE

function zigzag_interleave_8x8_cavlc_sve, export=1
    ptrue       p2.s, vl2
    ld4         {v0.8h,v1.8h,v2.8h,v3.8h}, [x1],  #64
    ld4         {v4.8h,v5.8h,v6.8h,v7.8h}, [x1]
    umax        v16.8h, v0.8h,  v4.8h
    umax        v17.8h, v1.8h,  v5.8h
    umax        v18.8h, v2.8h,  v6.8h
    umax        v19.8h, v3.8h,  v7.8h
    stp         q0, q4, [x0]
    stp         q1, q5, [x0, #32]
    stp         q2, q6, [x0, #64]
    stp         q3, q7, [x0, #96]
    umaxp       v16.8h, v16.8h, v17.8h
    umaxp       v18.8h, v18.8h, v19.8h
    umaxp       v16.8h, v16.8h, v18.8h
    cmtst       v16.4s, v16.4s, v16.4s
    neg         v16.4s, v16.4s
    st1b        {z16.s}, p2, [x2]
    add         x2, x2, #8
    dup         v17.2d, v16.d[1]
    st1b        {z17.s}, p2, [x2]
    ret
endfunc

.macro zigzag_sub_4x4 f, ac
function zigzag_sub_4x4\ac\()_\f\()_sve, export=1
    ptrue       p0.s, vl4
    index       z30.s, #0, #FENC_STRIDE/4
    index       z31.s, #0, #FDEC_STRIDE/4
    movrel      x5,  X(sub4x4_\f)
    ldr         q16, [x5]
    ld1w        {z0.s}, p0/z, [x1, z30.s, uxtw #2]
    tbl         v2.16b, {v0.16b}, v16.16b
    ld1w        {z1.s}, p0/z, [x2, z31.s, uxtw #2]
    tbl         v3.16b, {v1.16b}, v16.16b
    usubl       v4.8h,  v2.8b,  v3.8b
.ifc \ac, ac
    str         h4, [x3]
    mov         v4.h[0], wzr
.endif
    st1w        {z0.s}, p0, [x2, z31.s, uxtw #2]
    usubl2      v5.8h,  v2.16b, v3.16b
    orr         v6.16b, v4.16b, v5.16b
    umaxv       d6, p0, z6.d
    fmov        x7, d6
    stp         q4, q5, [x0]
    tst         x7, x7
    cset        w0, ne
    ret
endfunc
.endm

zigzag_sub_4x4 field
zigzag_sub_4x4 field, ac
zigzag_sub_4x4 frame
zigzag_sub_4x4 frame, ac
