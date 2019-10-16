/*
 * CC3Kazmath.h
 *
 * $Version: cocos3d 0.5.3 (dc0d1961822d) on 2011-04-05 $
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
 */

/** @file */	// Doxygen marker

#define KM_FALSE 0
#define KM_TRUE 1
#define kmScalar float

/** A three-dimensional vector. */
typedef struct kmVec3 {
	kmScalar x;
	kmScalar y;
	kmScalar z;
} kmVec3;

/** A homogeneous four-dimensional vector. */
typedef struct kmVec4 {
	kmScalar x;
	kmScalar y;
	kmScalar z;
	kmScalar w;
} kmVec4;

/** A rotational quaternion */
typedef struct kmQuaternion {
	kmScalar x;
	kmScalar y;
	kmScalar z;
	kmScalar w;
} kmQuaternion;

/** A standard 4x4 matrix */
typedef struct {
	kmScalar mat[16];
} kmMat4;


/** Returns a kmVec3 structure constructed from the vector components. */
kmVec3 kmVec3Make(kmScalar x, kmScalar y, kmScalar z);

/** Returns the length of the vector. */
kmScalar kmVec3Length(const kmVec3* pIn);

/** Normalizes the vector to unit length, stores the result in pOut and returns the result. */
kmVec3* kmVec3Normalize(kmVec3* pOut, const kmVec3* pIn);

/** Multiplies pM1 with pM2, stores the result in pOut, returns pOut. */
kmMat4* kmMat4Multiply(kmMat4* pOut, const kmMat4* pM1, const kmMat4* pM2);

/**
 * Builds a rotation matrix that rotates around all three axes, y (yaw), x (pitch) and z (roll),
 * in that order, stores the result in pOut and returns the result.
 * This algorithm matches up along the positive Y axis, which is the OpenGL ES default.
 */
kmMat4* kmMat4RotationYXZ(kmMat4* pOut, const kmScalar xRadians, const kmScalar yRadians, const kmScalar zRadians);

/**
 * Builds a rotation matrix that rotates around all three axes z (roll), y (yaw), and x (pitch),
 * in that order, stores the result in pOut and returns the result
 * This algorithm matches up along the positive Z axis, which is used by some commercial 3D worlds.
 */
kmMat4* kmMat4RotationZYX(kmMat4* pOut, const kmScalar xRadians, const kmScalar yRadians, const kmScalar zRadians);

/** Builds a rotation matrix around the X-axis, stores the result in pOut and returns the result */
kmMat4* kmMat4RotationX(kmMat4* pOut, const float radians);

/** Builds a rotation matrix around the Y-axis, stores the result in pOut and returns the result */
kmMat4* kmMat4RotationY(kmMat4* pOut, const float radians);

/** Builds a rotation matrix around the Z-axis, stores the result in pOut and returns the result */
kmMat4* kmMat4RotationZ(kmMat4* pOut, const float radians);

/**
 * Build a rotation matrix from an axis and an angle, 
 * stores the result in pOut and returns the result.
 */
kmMat4* kmMat4RotationAxisAngle(kmMat4* pOut, const kmVec3* axis, kmScalar radians);

/**
 * Builds a rotation matrix from a quaternion to a rotation matrix,
 * stores the result in pOut and returns the result.
 */
kmMat4* kmMat4RotationQuaternion(kmMat4* pOut, const kmQuaternion* pQ);

/** Extracts a quaternion from a rotation matrix, stores the result in quat and returns the result */
kmQuaternion* kmQuaternionRotationMatrix(kmQuaternion* quat, const kmMat4* pIn);

/**
 * Builds a transformation matrix that translates, rotates and scales according to the specified vectors,
 * stores the result in pOut and returns the result.
 */
kmMat4* kmMat4Transformation(kmMat4* pOut, const kmVec3 translation, const kmVec3 rotation, const kmVec3 scale);

/** Gauss-Jordan matrix inversion function */
int kmGaussJordan(kmMat4 *a, kmMat4 *b);

/** Get the value from the matrix at the specfied row and column. */
float kmMatGet(const kmMat4* pIn, int row, int col);

/** Set the value into the matrix at the specfied row and column. */
void kmMatSet(kmMat4 * pIn, int row, int col, float value);

/** Swap the elements in the matrix at the specfied row and column coordinates. */
void kmMatSwap(kmMat4 * pIn, int r1, int c1, int r2, int c2);
