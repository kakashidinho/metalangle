/*
 * CC3Kazmath.c
 *
 * Copyright (c) 2008, Luke Benstead.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * http://www.kazade.co.uk/kazmath/
 *
 * Augmented and modified for use with Objective-C in cocos3D by Bill Hollings
 * Additions and modifications copyright (c) 2010-2011 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 * 
 * See header file CC3Kazmath.h for full API documentation.
 */

#import "CC3Kazmath.h"
#import <stdlib.h>
#import <memory.h>
#import <math.h>


// Returns a kmVec3 structure constructed from the vector components.
kmVec3 kmVec3Make(kmScalar x, kmScalar y, kmScalar z) {
	kmVec3 v;
	v.x = x;
	v.y = y;
	v.z = z;
	return v;
}

// Returns the length of the vector.
kmScalar kmVec3Length(const kmVec3* pIn) {
	return sqrtf((pIn->x * pIn->x) + (pIn->y * pIn->y) + (pIn->z * pIn->z));
}

// Normalizes the vector to unit length, stores the result in pOut and returns the result.
kmVec3* kmVec3Normalize(kmVec3* pOut, const kmVec3* pIn) {
	kmScalar l = 1.0f / kmVec3Length(pIn);
	
	kmVec3 v;
	v.x = pIn->x * l;
	v.y = pIn->y * l;
	v.z = pIn->z * l;
	
	pOut->x = v.x;
	pOut->y = v.y;
	pOut->z = v.z;
	
	return pOut;
}

// Multiplies pM1 with pM2, stores the result in pOut, returns pOut
kmMat4* kmMat4Multiply(kmMat4* pOut, const kmMat4* pM1, const kmMat4* pM2) {
	const float *m1 = pM1->mat, *m2 = pM2->mat;
	float *m = pOut->mat;
	
	m[0] = m1[0] * m2[0] + m1[4] * m2[1] + m1[8] * m2[2] + m1[12] * m2[3];
	m[1] = m1[1] * m2[0] + m1[5] * m2[1] + m1[9] * m2[2] + m1[13] * m2[3];
	m[2] = m1[2] * m2[0] + m1[6] * m2[1] + m1[10] * m2[2] + m1[14] * m2[3];
	m[3] = m1[3] * m2[0] + m1[7] * m2[1] + m1[11] * m2[2] + m1[15] * m2[3];
	
	m[4] = m1[0] * m2[4] + m1[4] * m2[5] + m1[8] * m2[6] + m1[12] * m2[7];
	m[5] = m1[1] * m2[4] + m1[5] * m2[5] + m1[9] * m2[6] + m1[13] * m2[7];
	m[6] = m1[2] * m2[4] + m1[6] * m2[5] + m1[10] * m2[6] + m1[14] * m2[7];
	m[7] = m1[3] * m2[4] + m1[7] * m2[5] + m1[11] * m2[6] + m1[15] * m2[7];
	
	m[8] = m1[0] * m2[8] + m1[4] * m2[9] + m1[8] * m2[10] + m1[12] * m2[11];
	m[9] = m1[1] * m2[8] + m1[5] * m2[9] + m1[9] * m2[10] + m1[13] * m2[11];
	m[10] = m1[2] * m2[8] + m1[6] * m2[9] + m1[10] * m2[10] + m1[14] * m2[11];
	m[11] = m1[3] * m2[8] + m1[7] * m2[9] + m1[11] * m2[10] + m1[15] * m2[11];
	
	m[12] = m1[0] * m2[12] + m1[4] * m2[13] + m1[8] * m2[14] + m1[12] * m2[15];
	m[13] = m1[1] * m2[12] + m1[5] * m2[13] + m1[9] * m2[14] + m1[13] * m2[15];
	m[14] = m1[2] * m2[12] + m1[6] * m2[13] + m1[10] * m2[14] + m1[14] * m2[15];
	m[15] = m1[3] * m2[12] + m1[7] * m2[13] + m1[11] * m2[14] + m1[15] * m2[15];
	
	return pOut;
}

// Builds a rotation matrix that rotates around all three axes, y (yaw), x (pitch), z (roll),
// (equivalently to separate rotations, in that order), stores the result in pOut and returns the result.
kmMat4* kmMat4RotationYXZ(kmMat4* pOut, const kmScalar xRadians, const kmScalar yRadians, const kmScalar zRadians) {
/*
     |  cycz + sxsysz   czsxsy - cysz   cxsy  0 |
 M = |  cxsz            cxcz           -sx    0 |
     |  cysxsz - czsy   cyczsx + sysz   cxcy  0 |
     |  0               0               0     1 |
	 
     where cA = cos(A), sA = sin(A) for A = x,y,z
 */
	kmScalar* m = pOut->mat;
	
	kmScalar cx = cosf(xRadians);
	kmScalar sx = sinf(xRadians);
	kmScalar cy = cosf(yRadians);
	kmScalar sy = sinf(yRadians);
	kmScalar cz = cosf(zRadians);
	kmScalar sz = sinf(zRadians);
	
	m[0] = (cy * cz) + (sx * sy * sz);
	m[1] = cx * sz;
	m[2] = (cy * sx * sz) - (cz * sy);
	m[3] = 0.0;
	
	m[4] = (cz * sx * sy) - (cy * sz);
	m[5] = cx * cz;
	m[6] = (cy * cz * sx) + (sy * sz);
	m[7] = 0.0;
	
	m[8] = cx * sy;
	m[9] = -sx;
	m[10] = cx * cy;
	m[11] = 0.0;
	
	m[12] = 0.0;
	m[13] = 0.0;
	m[14] = 0.0;
	m[15] = 1.0;
	
	return pOut;
}

// Builds a rotation matrix that rotates around all three axes, z (roll), y (yaw), x (pitch),
// (equivalently to separate rotations, in that order), stores the result in pOut and returns the result.
kmMat4* kmMat4RotationZYX(kmMat4* pOut, const kmScalar xRadians, const kmScalar yRadians, const kmScalar zRadians) {
/*
     |  cycz  -cxsz + sxsycz   sxsz + cxsycz  0 |
 M = |  cysz   cxcz + sxsysz  -sxcz + cxsysz  0 |
     | -sy     sxcy            cxcy           0 |
     |  0      0               0              1 |

     where cA = cos(A), sA = sin(A) for A = x,y,z
*/
	kmScalar* m = pOut->mat;

	kmScalar cx = cosf(xRadians);
	kmScalar sx = sinf(xRadians);
	kmScalar cy = cosf(yRadians);
	kmScalar sy = sinf(yRadians);
	kmScalar cz = cosf(zRadians);
	kmScalar sz = sinf(zRadians);
	
	m[0] = cy * cz;
	m[1] = cy * sz;
	m[2] = -sy;
	m[3] = 0.0;
	
	m[4] = -(cx * sz) + (sx * sy * cz);
	m[5] = (cx * cz) + (sx * sy * sz);
	m[6] = sx * cy;
	m[7] = 0.0;
	
	m[8] = (sx * sz) + (cx * sy * cz);
	m[9] = -(sx * cz) + (cx * sy * sz);
	m[10] = cx * cy;
	m[11] = 0.0;
	
	m[12] = 0.0;
	m[13] = 0.0;
	m[14] = 0.0;
	m[15] = 1.0;
	
	return pOut;
}

// Builds a rotation matrix around the X-axis, stores the result in pOut and returns the result
kmMat4* kmMat4RotationX(kmMat4* pOut, const float radians) {
/*
     |  1  0       0       0 |
 M = |  0  cos(A) -sin(A)  0 |
     |  0  sin(A)  cos(A)  0 |
     |  0  0       0       1 |
*/
	kmScalar* m = pOut->mat;
	
	m[0] = 1.0f;
	m[1] = 0.0f;
	m[2] = 0.0f;
	m[3] = 0.0f;
	
	m[4] = 0.0f;
	m[5] = cosf(radians);
	m[6] = sinf(radians);
	m[7] = 0.0f;
	
	m[8] = 0.0f;
	m[9] = -sinf(radians);
	m[10] = cosf(radians);
	m[11] = 0.0f;
	
	m[12] = 0.0f;
	m[13] = 0.0f;
	m[14] = 0.0f;
	m[15] = 1.0f;
	
	return pOut;
}

// Builds a rotation matrix around the Y-axis, stores the result in pOut and returns the result
kmMat4* kmMat4RotationY(kmMat4* pOut, const float radians) {
/*
     |  cos(A)  0   sin(A)  0 |
 M = |  0       1   0       0 |
     | -sin(A)  0   cos(A)  0 |
     |  0       0   0       1 |
*/
	kmScalar* m = pOut->mat;
	
	m[0] = cosf(radians);
	m[1] = 0.0f;
	m[2] = -sinf(radians);
	m[3] = 0.0f;
	
	m[4] = 0.0f;
	m[5] = 1.0f;
	m[6] = 0.0f;
	m[7] = 0.0f;
	
	m[8] = sinf(radians);
	m[9] = 0.0f;
	m[10] = cosf(radians);
	m[11] = 0.0f;
	
	m[12] = 0.0f;
	m[13] = 0.0f;
	m[14] = 0.0f;
	m[15] = 1.0f;
	
	return pOut;
}

// Builds a rotation matrix around the Z-axis, stores the result in pOut and returns the result
kmMat4* kmMat4RotationZ(kmMat4* pOut, const float radians) {
/*
     |  cos(A)  -sin(A)   0   0 |
 M = |  sin(A)   cos(A)   0   0 |
     |  0        0        1   0 |
     |  0        0        0   1 |
*/
	kmScalar* m = pOut->mat;
	
	m[0] = cosf(radians);
	m[1] = sinf(radians);
	m[2] = 0.0f;
	m[3] = 0.0f;
	
	m[4] = -sinf(radians);;
	m[5] = cosf(radians);
	m[6] = 0.0f;
	m[7] = 0.0f;
	
	m[8] = 0.0f;
	m[9] = 0.0f;
	m[10] = 1.0f;
	m[11] = 0.0f;
	
	m[12] = 0.0f;
	m[13] = 0.0f;
	m[14] = 0.0f;
	m[15] = 1.0f;
	
	return pOut;
}

// Build a rotation matrix from an axis and an angle, stores the result in pOut and returns the result.
kmMat4* kmMat4RotationAxisAngle(kmMat4* pOut, const kmVec3* axis, kmScalar radians) {
/*
     |      									|
     | C + XX(1 - C)   -ZS + XY(1-C)  YS + ZX(1-C)   0 |
     |                                                 |
M =  | ZS + XY(1-C)    C + YY(1 - C)  -XS + YZ(1-C)  0 |
     |                                                 |
     | -YS + ZX(1-C)   XS + YZ(1-C)   C + ZZ(1 - C)  0 |
     |                                                 |
     |      0              0               0         1 |

     where X, Y, Z define axis of rotation and C = cos(A), S = sin(A) for A = angle of rotation
*/
	kmScalar ca = cosf(radians);
	kmScalar sa = sinf(radians);
	
	kmVec3 rax;
	kmVec3Normalize(&rax, axis);
	
	pOut->mat[0] = ca + rax.x * rax.x * (1 - ca);
	pOut->mat[1] = rax.z * sa + rax.y * rax.x * (1 - ca);
	pOut->mat[2] = -rax.y * sa + rax.z * rax.x * (1 - ca);
	pOut->mat[3] = 0.0f;
	
	pOut->mat[4] = -rax.z * sa + rax.x * rax.y * (1 - ca);
	pOut->mat[5] = ca + rax.y * rax.y * (1 - ca);
	pOut->mat[6] = rax.x * sa + rax.z * rax.y * (1 - ca);
	pOut->mat[7] = 0.0f;
	
	pOut->mat[8] = rax.y * sa + rax.x * rax.z * (1 - ca);
	pOut->mat[9] = -rax.x * sa + rax.y * rax.z * (1 - ca);
	pOut->mat[10] = ca + rax.z * rax.z * (1 - ca);
	pOut->mat[11] = 0.0f;
	
	pOut->mat[12] = 0.0f;
	pOut->mat[13] = 0.0f;
	pOut->mat[14] = 0.0f;
	pOut->mat[15] = 1.0f;
	
	return pOut;
}

// Builds a rotation matrix from a quaternion to a rotation matrix,
// stores the result in pOut and returns the result
kmMat4* kmMat4RotationQuaternion(kmMat4* pOut, const kmQuaternion* pQ) {
/*
     |       2     2									|
     | 1 - 2Y  - 2Z    2XY + 2ZW      2XZ - 2YW		 0	|
     |													|
     |                       2     2					|
 M = | 2XY - 2ZW       1 - 2X  - 2Z   2YZ + 2XW		 0	|
     |													|
     |                                      2     2		|
     | 2XZ + 2YW       2YZ - 2XW      1 - 2X  - 2Y	 0	|
     |													|
     |     0			   0			  0          1  |
*/
	kmScalar* m = pOut->mat;

	kmScalar twoXX = 2.0f * pQ->x * pQ->x;
	kmScalar twoXY = 2.0f * pQ->x * pQ->y;
	kmScalar twoXZ = 2.0f * pQ->x * pQ->z;
	kmScalar twoXW = 2.0f * pQ->x * pQ->w;
	
	kmScalar twoYY = 2.0f * pQ->y * pQ->y;
	kmScalar twoYZ = 2.0f * pQ->y * pQ->z;
	kmScalar twoYW = 2.0f * pQ->y * pQ->w;
	
	kmScalar twoZZ = 2.0f * pQ->z * pQ->z;
	kmScalar twoZW = 2.0f * pQ->z * pQ->w;
	
	m[0] = 1.0f - twoYY - twoZZ;
	m[1] = twoXY - twoZW;
	m[2] = twoXZ + twoYW;
	m[3] = 0.0f;
	
	m[4] = twoXY + twoZW;
	m[5] = 1.0f - twoXX - twoZZ;
	m[6] = twoYZ - twoXW;
	m[7] = 0.0f;
	
	m[8] = twoXZ - twoYW;
	m[9] = twoYZ + twoXW;
	m[10] = 1.0f - twoXX - twoYY;
	m[11] = 0.0f;
	
	m[12] = 0.0f;
	m[13] = 0.0f;
	m[14] = 0.0f;
	m[15] = 1.0f;
	
	return pOut;
}

// Extracts a quaternion from a rotation matrix, stores the result in quat and returns the result.
// This implementation is actually taken from the Quaternions article in Jeff LaMarche's excellent
// series on OpenGL programming for the iOS. Jeff's original source and explanation can be found here:
// http://iphonedevelopment.blogspot.com/2010/04/opengl-es-from-ground-up-9-intermission.html
// It has been adapted here for this library.
kmQuaternion* kmQuaternionRotationMatrix(kmQuaternion* quat, const kmMat4* pIn) {
#define QUATERNION_TRACE_ZERO_TOLERANCE 0.0001f
	kmScalar trace, s;
	const kmScalar* m = pIn->mat;
	
	trace = m[0] + m[5] + m[10];
	if (trace > 0.0f) {
		s = sqrtf(trace + 1.0f);
		quat->w = s * 0.5f;
		s = 0.5f / s;
		
		quat->x = (m[9] - m[6]) * s;
		quat->y = (m[2] - m[8]) * s;
		quat->z = (m[4] - m[1]) * s;
	} else {
		enum {A,E,I} biggest;
		if (m[0] > m[5])
			if (m[10] > m[0])
				biggest = I;   
			else
				biggest = A;
			else
				if (m[10] > m[0])
					biggest = I;
				else
					biggest = E;
		
		switch (biggest) {
			case A:
				s = sqrtf(m[0] - (m[5] + m[10]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->x = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[9] - m[6]) * s;
					quat->y = (m[1] + m[4]) * s;
					quat->z = (m[2] + m[8]) * s;
					break;
				}
				s = sqrtf(m[10] - (m[0] + m[5]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->z = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[4] - m[1]) * s;
					quat->x = (m[8] + m[2]) * s;
					quat->y = (m[9] + m[6]) * s;
					break;
				}
				s = sqrtf(m[5] - (m[10] + m[0]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->y = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[2] - m[8]) * s;
					quat->z = (m[6] + m[9]) * s;
					quat->x = (m[4] + m[1]) * s;
					break;
				}
				break;
				
			case E:
				s = sqrtf(m[5] - (m[10] + m[0]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->y = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[2] - m[8]) * s;
					quat->z = (m[6] + m[9]) * s;
					quat->x = (m[4] + m[1]) * s;
					break;
				}
				s = sqrtf(m[10] - (m[0] + m[5]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->z = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[4] - m[1]) * s;
					quat->x = (m[8] + m[2]) * s;
					quat->y = (m[9] + m[6]) * s;
					break;
				}
				s = sqrtf(m[0] - (m[5] + m[10]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->x = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[9] - m[6]) * s;
					quat->y = (m[1] + m[4]) * s;
					quat->z = (m[2] + m[8]) * s;
					break;
				}
				break;
				
			case I:
				s = sqrtf(m[10] - (m[0] + m[5]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->z = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[4] - m[1]) * s;
					quat->x = (m[8] + m[2]) * s;
					quat->y = (m[9] + m[6]) * s;
					break;
				}
				s = sqrtf(m[0] - (m[5] + m[10]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->x = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[9] - m[6]) * s;
					quat->y = (m[1] + m[4]) * s;
					quat->z = (m[2] + m[8]) * s;
					break;
				}
				s = sqrtf(m[5] - (m[10] + m[0]) + 1.0f);
				if (s > QUATERNION_TRACE_ZERO_TOLERANCE) {
					quat->y = s * 0.5f;
					s = 0.5f / s;
					quat->w = (m[2] - m[8]) * s;
					quat->z = (m[6] + m[9]) * s;
					quat->x = (m[4] + m[1]) * s;
					break;
				}
				break;
				
			default:
				break;
		}
	}
	return quat;
}

// Builds a transformation matrix that translates, rotates and scales according to the specified vectors,
// stores the result in pOut and returns the result
kmMat4* kmMat4Transformation(kmMat4* pOut, const kmVec3 translation, const kmVec3 rotation, const kmVec3 scale) {
/*
     |  gxR0  gyR4  gzR8   tx |
 M = |  gxR1  gyR5  gzR9   ty |
     |  gxR2  gyR6  gzR10  tz |
     |  0     0     0      1  |
	 
     where Rn is an element of the rotation matrix (R0 - R15).
     where tx = translation.x, ty = translation.y, tz = translation.z
     where gx = scale.x, gy = scale.y, gz = scale.z
*/	

	// Start with basic rotation matrix
	kmMat4RotationYXZ(pOut, rotation.x, rotation.y, rotation.z);
	
	// Adjust for scale and translation
	kmScalar* m = pOut->mat;

	m[0] *= scale.x;
	m[1] *= scale.x;
	m[2] *= scale.x;
	m[3] = 0.0;
	
	m[4] *= scale.y;
	m[5] *= scale.y;
	m[6] *= scale.y;
	m[7] = 0.0;
	
	m[8] *= scale.z;
	m[9] *= scale.z;
	m[10] *= scale.z;
	m[11] = 0.0;
	
	m[12] = translation.x;
	m[13] = translation.y;
	m[14] = translation.z;
	m[15] = 1.0;
	
	return pOut;
}

float kmMatGet(const kmMat4* pIn, int row, int col) {
	return pIn->mat[row + 4*col];
}

void kmMatSet(kmMat4* pIn, int row, int col, float value) {
	pIn->mat[row + 4*col] = value;
}

void kmMatSwap(kmMat4* pIn, int r1, int c1, int r2, int c2) {
	float tmp = kmMatGet(pIn,r1,c1);
	kmMatSet(pIn,r1,c1,kmMatGet(pIn,r2,c2));
	kmMatSet(pIn,r2,c2, tmp);
}

// Returns an upper and a lower triangular matrix which are L and R in the Gauss algorithm
int kmGaussJordan(kmMat4* a, kmMat4* b) {
    int i, icol = 0, irow = 0, j, k, l, ll, n = 4, m = 4;
    float big, dum, pivinv;
    int indxc[n];
    int indxr[n];
    int ipiv[n];
	
    for (j = 0; j < n; j++) {
        ipiv[j] = 0;
    }
	
    for (i = 0; i < n; i++) {
        big = 0.0f;
        for (j = 0; j < n; j++) {
            if (ipiv[j] != 1) {
                for (k = 0; k < n; k++) {
                    if (ipiv[k] == 0) {
                        if (abs(kmMatGet(a,j, k)) >= big) {
                            big = abs(kmMatGet(a,j, k));
                            irow = j;
                            icol = k;
                        }
                    }
                }
            }
        }
        ++(ipiv[icol]);
        if (irow != icol) {
            for (l = 0; l < n; l++) {
                kmMatSwap(a,irow, l, icol, l);
            }
            for (l = 0; l < m; l++) {
                kmMatSwap(b,irow, l, icol, l);
            }
        }
        indxr[i] = irow;
        indxc[i] = icol;
        if (kmMatGet(a,icol, icol) == 0.0) {
            return KM_FALSE;
        }
        pivinv = 1.0f / kmMatGet(a,icol, icol);
        kmMatSet(a,icol, icol, 1.0f);
        for (l = 0; l < n; l++) {
            kmMatSet(a,icol, l, kmMatGet(a,icol, l) * pivinv);
        }
        for (l = 0; l < m; l++) {
            kmMatSet(b,icol, l, kmMatGet(b,icol, l) * pivinv);
        }
		
        for (ll = 0; ll < n; ll++) {
            if (ll != icol) {
                dum = kmMatGet(a,ll, icol);
                kmMatSet(a,ll, icol, 0.0f);
                for (l = 0; l < n; l++) {
                    kmMatSet(a,ll, l, kmMatGet(a,ll, l) - kmMatGet(a,icol, l) * dum);
                }
                for (l = 0; l < m; l++) {
                    kmMatSet(b,ll, l, kmMatGet(a,ll, l) - kmMatGet(b,icol, l) * dum);
                }
            }
        }
    }
	//    This is the end of the main loop over columns of the reduction. It only remains to unscram-
	//    ble the solution in view of the column interchanges. We do this by interchanging pairs of
	//    columns in the reverse order that the permutation was built up.
    for (l = n - 1; l >= 0; l--) {
        if (indxr[l] != indxc[l]) {
            for (k = 0; k < n; k++) {
                kmMatSwap(a,k, indxr[l], k, indxc[l]);
            }
        }
    }
    return KM_TRUE;
}
