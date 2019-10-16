/*
 * CC3GLMatrix.m
 *
 * $Version: cocos3d 0.5.4 (f5cd4df5048c) on 2011-04-14 $
 * Author: Bill Hollings
 * Copyright (c) 2010-2011 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 *
 * See header file CC3GLMatrix.h for full API documentation.
 */

#import "CC3GLMatrix.h"
#import "CC3Math.h"
#import "CC3Kazmath.h"


#pragma mark CC3Matrix private method declaration

@interface CC3GLMatrix (Private)
-(id) initParent;
-(id) initWithFirstElement: (GLfloat) e00 remainingElements: (va_list) args;
-(void) swap: (GLuint) idx1 with: (GLuint) idx2;
+(void) swap: (GLuint) idx1 with: (GLuint) idx2 inMatrix: (GLfloat*) aGLMatrix;
@end


#pragma mark -
#pragma mark CC3ArrayMatrix class cluster implementation class

@interface CC3GLArrayMatrix : CC3GLMatrix {
	GLfloat glArray[16];
}

@end

@implementation CC3GLArrayMatrix

-(GLfloat*) glMatrix {
	return glArray;
}

@end


#pragma mark -
#pragma mark CC3GLPointerMatrix class cluster implementation class

@interface CC3GLPointerMatrix : CC3GLMatrix {
	GLfloat* glMatrix;
}

@end

@implementation CC3GLPointerMatrix

-(GLfloat*) glMatrix {
	return glMatrix;
}

-(id) initOnGLMatrix: (GLfloat*) aGLMtx {
	if ( (self = [self initParent]) ) {
		glMatrix = aGLMtx;
	}
	return self;
}

@end


#pragma mark -
#pragma mark CC3Matrix implementation

@implementation CC3GLMatrix

@synthesize isIdentity;

/**
 * Abstract class simply returns NULL.
 * Subclasses will provide concrete access to the appropriate structure.
 */
-(GLfloat*) glMatrix {
	return NULL;
}


#pragma mark Allocation and initialization

-(id) initParent {
	return [super init];
}

-(id) init {
	if ( [self isKindOfClass: [CC3GLArrayMatrix class]] ) {
		if( (self = [self initParent]) ) {
			[self populateZero];
		}
		return self;
	} else {
		[self release];
		return [[CC3GLArrayMatrix alloc] init];
	}
}

+(id) matrix {
	if ( [self isSubclassOfClass: [CC3GLArrayMatrix class]] ) {
		return [[[self alloc] init] autorelease];
	} else {
		return [CC3GLArrayMatrix matrix];
	}
}

-(id) initIdentity {
	if ( [self isKindOfClass: [CC3GLArrayMatrix class]] ) {
		if( (self = [self initParent]) ) {
			[self populateIdentity];
		}
		return self;
	} else {
		[self release];
		return [[CC3GLArrayMatrix alloc] initIdentity];
	}
}

+(id) identity {
	if ( [self isSubclassOfClass: [CC3GLArrayMatrix class]] ) {
		return [[[self alloc] initIdentity] autorelease];
	} else {
		return [CC3GLArrayMatrix identity];
	}
}

-(id) initFromGLMatrix: (GLfloat*) aGLMtx {
	if ( [self isKindOfClass: [CC3GLArrayMatrix class]] ) {
		if( (self = [self initParent]) ) {
			[self populateFromGLMatrix: aGLMtx];
		}
		return self;
	} else {
		[self release];
		return [[CC3GLArrayMatrix alloc] initFromGLMatrix: aGLMtx];
	}
}

+(id) matrixFromGLMatrix: (GLfloat*) aGLMtx {
	if ( [self isSubclassOfClass: [CC3GLArrayMatrix class]] ) {
		return [[[self alloc] initFromGLMatrix: aGLMtx] autorelease];
	} else {
		return [CC3GLArrayMatrix matrixFromGLMatrix: aGLMtx];
	}
}

-(id) initWithFirstElement: (GLfloat) e00 remainingElements: (va_list) args {
	if ( [self isKindOfClass: [CC3GLArrayMatrix class]] ) {
		if( (self = [self initParent]) ) {
			GLfloat* p = self.glMatrix;
			*p++ = e00;
			for (int i = 1; i < 16; i++) {
				*p++ = (GLfloat)va_arg(args, double);
			}
		}
	} else {
		[self release];
		self = [[CC3GLArrayMatrix alloc] initWithFirstElement: e00 remainingElements: args];
	}
	return self;
}

-(id) initWithElements: (GLfloat) e00, ... {
	va_list args;
	va_start(args, e00);
	self = [self initWithFirstElement: e00 remainingElements: args];
	va_end(args);
	return self;
}

+(id) matrixWithElements: (GLfloat) e00, ... {
	va_list args;
	va_start(args, e00);
	CC3GLMatrix* mtx = [[CC3GLArrayMatrix alloc] initWithFirstElement: e00 remainingElements: args];
	va_end(args);
	return [mtx autorelease];
}

-(id) initOnGLMatrix: (GLfloat*) aGLMtx {
	[self release];
	return [[CC3GLPointerMatrix alloc] initOnGLMatrix: aGLMtx];
}

+(id) matrixOnGLMatrix: (GLfloat*) aGLMtx {
	if ( [self isSubclassOfClass: [CC3GLPointerMatrix class]] ) {
		return [[[self alloc] initOnGLMatrix: aGLMtx] autorelease];
	} else {
		return [CC3GLPointerMatrix matrixOnGLMatrix: aGLMtx];
	}
}

- (id) copyWithZone: (NSZone*) zone {
	return [[CC3GLArrayMatrix matrixFromGLMatrix: self.glMatrix] retain];
}

-(NSString*) description {
	GLfloat* m = self.glMatrix;
	NSMutableString* desc = [NSMutableString stringWithCapacity: 200];
	[desc appendFormat: @"\n\t[%.3f, ", m[0]];
	[desc appendFormat: @"%.3f, ", m[4]];
	[desc appendFormat: @"%.3f, ", m[8]];
	[desc appendFormat: @"%.3f,\n\t ", m[12]];
	[desc appendFormat: @"%.3f, ", m[1]];
	[desc appendFormat: @"%.3f, ", m[5]];
	[desc appendFormat: @"%.3f, ", m[9]];
	[desc appendFormat: @"%.3f,\n\t ", m[13]];
	[desc appendFormat: @"%.3f, ", m[2]];
	[desc appendFormat: @"%.3f, ", m[6]];
	[desc appendFormat: @"%.3f, ", m[10]];
	[desc appendFormat: @"%.3f,\n\t ", m[14]];
	[desc appendFormat: @"%.3f, ", m[3]];
	[desc appendFormat: @"%.3f, ", m[7]];
	[desc appendFormat: @"%.3f, ", m[11]];
	[desc appendFormat: @"%.3f]", m[15]];
	return desc;
}


#pragma mark -
#pragma mark Instance population

static const GLfloat identityContents[] = { 1.0f, 0.0f, 0.0f, 0.0f,
											0.0f, 1.0f, 0.0f, 0.0f,
											0.0f, 0.0f, 1.0f, 0.0f,
											0.0f, 0.0f, 0.0f, 1.0f };

-(void) populateFrom: (CC3GLMatrix*) aMtx {
	if (aMtx.isIdentity) {
		[self populateIdentity];
	} else {
		[self populateFromGLMatrix: aMtx.glMatrix];
	}
}

-(void) populateFromGLMatrix: (GLfloat*) aGLMtx {
	[[self class] copyMatrix: aGLMtx into: self.glMatrix];
	isIdentity = NO;
}

-(void) populateZero {
	memset(self.glMatrix, 0, 16 * sizeof(GLfloat));
	isIdentity = NO;
}

-(void) populateIdentity {
	if (!isIdentity) {
		[[self class] copyMatrix: (GLfloat*)identityContents into: self.glMatrix];
		isIdentity = YES;
	}
}

-(void) populateFromTranslation: (CC3Vector) aVector {
/*
     | 1  0  0  x |
 M = | 0  1  0  y |
     | 0  0  1  z |
     | 0  0  0  1 |
*/
	// Start with identity, then if the vector is not zero,
	// add the translation components, and mark not identity.
	[self populateIdentity];

	if (!CC3VectorsAreEqual(aVector, kCC3VectorZero)) {
		GLfloat* m = self.glMatrix;
		m[12] = aVector.x;
		m[13] = aVector.y;
		m[14] = aVector.z;
		isIdentity = NO;
	}
}

-(void) populateFromRotation: (CC3Vector) aVector {
	if (CC3VectorsAreEqual(aVector, kCC3VectorZero)) {
		[self populateIdentity];
	} else {
		CC3Vector rotRads = CC3VectorScaleUniform(aVector, DegreesToRadiansFactor);
		kmMat4RotationYXZ((kmMat4*)self.glMatrix, rotRads.x, rotRads.y, rotRads.z);
		isIdentity = NO;
	}
}

-(void) populateFromQuaternion: (CC3Vector4) aQuaternion {
	if (CC3Vector4sAreEqual(aQuaternion, kCC3Vector4QuaternionIdentity)) {
		[self populateIdentity];
	} else {
		kmMat4RotationQuaternion((kmMat4*)self.glMatrix, (kmQuaternion*)&aQuaternion);
		isIdentity = NO;
	}
}

-(void) populateFromScale: (CC3Vector) aVector {
/*
     |  x  0  0  0 |
 M = |  0  y  0  0 |
     |  0  0  z  0 |
     |  0  0  0  1 |
 */
	// Start with identity, then if the vector is not unity,
	// add the scale components, and mark not identity.
	[self populateIdentity];
	
	if (!CC3VectorsAreEqual(aVector, kCC3VectorUnitCube)) {
		GLfloat* m = self.glMatrix;
		m[0] = aVector.x;
		m[5] = aVector.y;
		m[10] = aVector.z;
		isIdentity = NO;
	}
}

-(void) populateToPointTowards: (CC3Vector) fwdDirection withUp: (CC3Vector) upDirection {
	[[self class] populate: self.glMatrix toPointTowards: fwdDirection withUp: upDirection];
	isIdentity = NO;
}

-(void) populateToLookAt: (CC3Vector) targetLocation
			   withEyeAt: (CC3Vector) eyeLocation
				  withUp: (CC3Vector) upDirection {

	[[self class] populate: self.glMatrix
				  toLookAt: targetLocation
				 withEyeAt: eyeLocation
					withUp: upDirection];
	isIdentity = NO;
}

-(void) populateFromFrustumLeft: (GLfloat) left
					   andRight: (GLfloat) right
					  andBottom: (GLfloat) bottom
						 andTop: (GLfloat) top  
						andNear: (GLfloat) near
						 andFar: (GLfloat) far {
	[[self class] populate: self.glMatrix
		   fromFrustumLeft: left andRight: right
				 andBottom: bottom andTop: top  
				   andNear: near andFar: far];
	isIdentity = NO;
}

-(void) populateOrthoFromFrustumLeft: (GLfloat) left
							andRight: (GLfloat) right
						   andBottom: (GLfloat) bottom
							  andTop: (GLfloat) top  
							 andNear: (GLfloat) near
							  andFar: (GLfloat) far {
	[[self class] populateOrtho: self.glMatrix
				fromFrustumLeft: left andRight: right
					  andBottom: bottom andTop: top  
						andNear: near andFar: far];
	isIdentity = NO;
}


#pragma mark Matrix population

+(void) copyMatrix: (GLfloat*) srcGLMatrix into: (GLfloat*) destGLMatrix {
	memcpy(destGLMatrix, srcGLMatrix, 16 * sizeof(GLfloat));
}

+(void) populate: (GLfloat*) aGLMatrix toPointTowards: (CC3Vector) fwdDirection withUp: (CC3Vector) upDirection {
/*
     |  rx  ux  -fx  0 |
 M = |  ry  uy  -fy  0 |
     |  rz  uz  -fz  0 |
     |  0   0    0   1 |
	 
	 where f is the normalized Forward vector (the direction being pointed to)
	 and u is the normalized Up vector in the rotated frame
	 and r is the normalized Right vector in the rotated frame
 */
	CC3Vector f, u, r;
	
	f = CC3VectorNormalize(fwdDirection);
	r = CC3VectorNormalize(CC3VectorCross(f, upDirection));
	u = CC3VectorCross(r, f);			// already normalized since f & r are orthonormal
	
	aGLMatrix[0]  = r.x;
	aGLMatrix[1]  = r.y;
	aGLMatrix[2]  = r.z;
	aGLMatrix[3] = 0.0;
	
	aGLMatrix[4]  = u.x;
	aGLMatrix[5]  = u.y;
	aGLMatrix[6]  = u.z;
	aGLMatrix[7] = 0.0;
	
	aGLMatrix[8]  = -f.x;
	aGLMatrix[9]  = -f.y;
	aGLMatrix[10] = -f.z;
	aGLMatrix[11] = 0.0;
	
	aGLMatrix[12]  = 0.0;
	aGLMatrix[13]  = 0.0;
	aGLMatrix[14] = 0.0;
	aGLMatrix[15] = 1.0;
}

+(void) populate: (GLfloat*) aGLMatrix
		toLookAt: (CC3Vector) targetLocation
	   withEyeAt: (CC3Vector) eyeLocation
		  withUp: (CC3Vector) upDirection {
	
	CC3Vector fwdDir = CC3VectorDifference(targetLocation, eyeLocation);
	[self populate: aGLMatrix toPointTowards: fwdDir withUp: upDirection];
	[self transpose: aGLMatrix];		
	[self translate: aGLMatrix by: CC3VectorNegate(eyeLocation)];
}

+(void) populate: (GLfloat*) aGLMatrix
 fromFrustumLeft: (GLfloat) left
		andRight: (GLfloat) right
	   andBottom: (GLfloat) bottom
		  andTop: (GLfloat) top  
		 andNear: (GLfloat) near
		  andFar: (GLfloat) far {
	
	aGLMatrix[0]  = (2.0 * near) / (right - left);
	aGLMatrix[1]  = 0.0;
	aGLMatrix[2]  = 0.0;
	aGLMatrix[3] = 0.0;
	
	aGLMatrix[4]  = 0.0;
	aGLMatrix[5]  = (2.0 * near) / (top - bottom);
	aGLMatrix[6]  = 0.0;
	aGLMatrix[7] = 0.0;
	
	aGLMatrix[8]  = (right + left) / (right - left);
	aGLMatrix[9]  = (top + bottom) / (top - bottom);
	aGLMatrix[10] = -(far + near) / (far - near);
	aGLMatrix[11] = -1.0;
	
	aGLMatrix[12]  = 0.0;
	aGLMatrix[13]  = 0.0;
	aGLMatrix[14] = -(2.0 * far * near) / (far - near);
	aGLMatrix[15] = 0.0;
}

+(void) populateOrtho: (GLfloat*) aGLMatrix
	  fromFrustumLeft: (GLfloat) left
			 andRight: (GLfloat) right
			andBottom: (GLfloat) bottom
			   andTop: (GLfloat) top  
			  andNear: (GLfloat) near
			   andFar: (GLfloat) far {
	
	aGLMatrix[0]  = 2.0 / (right - left);
	aGLMatrix[1]  = 0.0;
	aGLMatrix[2]  = 0.0;
	aGLMatrix[3] = 0.0;
	
	aGLMatrix[4]  = 0.0;
	aGLMatrix[5]  = 2.0 / (top - bottom);
	aGLMatrix[6]  = 0.0;
	aGLMatrix[7] = 0.0;

	aGLMatrix[8]  = 0.0;
	aGLMatrix[9]  = 0.0;
	aGLMatrix[10]  = -2.0 / (far - near);
	aGLMatrix[11] = 0.0;

	aGLMatrix[12]  = -(right + left) / (right - left);
	aGLMatrix[13]  = -(top + bottom) / (top - bottom);
	aGLMatrix[14] = -(far + near) / (far - near);
	aGLMatrix[15] = 1.0;
}


#pragma mark -
#pragma mark Instance accessing

 // CAUTION: This is a simple convenience utility. For speed, it does not honour
 // the isIdentity flag. It is the responsibility of the caller to deal with that flag.
-(void) swap: (GLuint) idx1 with: (GLuint) idx2 {
	[[self class] swap: idx1 with: idx2 inMatrix: self.glMatrix];
}

-(CC3Vector) extractRotation {
	return [[self class] extractRotationYXZFromMatrix: self.glMatrix];
}

-(CC3Vector4) extractQuaternion {
	return [[self class] extractQuaternionFromMatrix: self.glMatrix];
}

-(CC3Vector) extractForwardDirection {
	return [[self class] extractForwardDirectionFrom: self.glMatrix];
}

-(CC3Vector) extractUpDirection {
	return [[self class] extractUpDirectionFrom: self.glMatrix];
}

-(CC3Vector) extractRightDirection {
	return [[self class] extractRightDirectionFrom: self.glMatrix];
}


#pragma mark Matrix accessing

+(void) swap: (GLuint) idx1 with: (GLuint) idx2 inMatrix: (GLfloat*) aGLMatrix {
	GLfloat tmp = aGLMatrix[idx1];
	aGLMatrix[idx1] = aGLMatrix[idx2];
	aGLMatrix[idx2] = tmp;
}

// Assumes YXZ euler order, which is the OpenGL ES default
+(CC3Vector) extractRotationYXZFromMatrix: (GLfloat*) aGLMatrix {
/*
     |  cycz + sxsysz   czsxsy - cysz   cxsy  0 |
 M = |  cxsz            cxcz           -sx    0 |
     |  cysxsz - czsy   cyczsx + sysz   cxcy  0 |
     |  0               0               0     1 |
 
     where cA = cos(A), sA = sin(A) for A = x,y,z
 */
	GLfloat radX, radY, radZ;
	GLfloat cxsz = aGLMatrix[1];
	GLfloat cxcz = aGLMatrix[5];
	GLfloat sx = -aGLMatrix[9];
	GLfloat cxsy = aGLMatrix[8];
	GLfloat cxcy = aGLMatrix[10];
	if (sx < +1.0) {
		if (sx > -1.0) {
			radX = asin(sx);
			radY = atan2(cxsy, cxcy);
			radZ = atan2(cxsz, cxcz);
		}
		else {		// sx = -1. Not a unique solution: radZ + radY = atan2(-m01,m00).
			radX = -M_PI_2;
			radY = atan2(-aGLMatrix[4], aGLMatrix[0]);
			radZ = 0.0;
		}
	}
	else {			// sx = +1. Not a unique solution: radZ - radY = atan2(-m01,m00).
		radX = +M_PI_2;
		radY = -atan2(-aGLMatrix[4], aGLMatrix[0]);
		radZ = 0.0;
	}	
	return cc3v(RadiansToDegrees(radX), RadiansToDegrees(radY), RadiansToDegrees(radZ));
}

// Assumes ZYX euler order
+(CC3Vector) extractRotationZYXFromMatrix: (GLfloat*) aGLMatrix {
/*
     |  cycz  -cxsz + sxsycz   sxsz + cxsycz  0 |
 M = |  cysz   cxcz + sxsysz  -sxcz + cxsysz  0 |
     | -sy     sxcy            cxcy           0 |
     |  0      0               0              1 |
	 
     where cA = cos(A), sA = sin(A) for A = x,y,z
 */
	GLfloat radX, radY, radZ;
	GLfloat cycz = aGLMatrix[0];
	GLfloat cysz = aGLMatrix[1];
	GLfloat sy = -aGLMatrix[2];
	GLfloat sxcy = aGLMatrix[6];
	GLfloat cxcy = aGLMatrix[10];
	if (sy < +1.0) {
		if (sy > -1.0) {
			radY = asin(sy);
			radZ = atan2(cysz, cycz);
			radX = atan2(sxcy, cxcy);
		}
		else {		// sy = -1. Not a unique solution: radX + radZ = atan2(-m12,m11).
			radY = -M_PI_2;
			radZ = atan2(-aGLMatrix[9], aGLMatrix[5]);
			radX = 0.0;
		}
	}
	else {			// sy = +1. Not a unique solution: radX - radZ = atan2(-m12,m11).
		radY = +M_PI_2;
		radZ = -atan2(-aGLMatrix[9], aGLMatrix[5]);
		radX = 0.0;
	}	
	return cc3v(RadiansToDegrees(radX), RadiansToDegrees(radY), RadiansToDegrees(radZ));
}

+(CC3Vector4) extractQuaternionFromMatrix: (GLfloat*) aGLMatrix {
	CC3Vector4 quaternion;
	kmQuaternionRotationMatrix((kmQuaternion*)&quaternion, (kmMat4*)aGLMatrix);
	return quaternion;
}

+(CC3Vector) extractForwardDirectionFrom: (GLfloat*) aGLMatrix {
	return cc3v(-aGLMatrix[8], -aGLMatrix[9], -aGLMatrix[10]);
}

+(CC3Vector) extractUpDirectionFrom: (GLfloat*) aGLMatrix {
	return cc3v(aGLMatrix[4], aGLMatrix[5], aGLMatrix[6]);
}

+(CC3Vector) extractRightDirectionFrom: (GLfloat*) aGLMatrix {
	return cc3v(aGLMatrix[0], aGLMatrix[1], aGLMatrix[2]);
}


#pragma mark -
#pragma mark Instance transformations

-(void) translateBy: (CC3Vector) translationVector
		   rotateBy: (CC3Vector) rotationVector
			scaleBy: (CC3Vector) scaleVector {
	// if not ALL identity transforms, transform this matrix
	if ( !(CC3VectorsAreEqual(translationVector, kCC3VectorZero) &&
		   CC3VectorsAreEqual(rotationVector, kCC3VectorZero) &&
		   CC3VectorsAreEqual(scaleVector, kCC3VectorUnitCube)) ) {
		[[self class] transform: self.glMatrix
					translateBy: translationVector
					   rotateBy: rotationVector
						scaleBy: scaleVector];
		isIdentity = NO;
	}
}

-(void) translateBy: (CC3Vector) aVector {
	// Short-circuit an identity transform
	if ( !CC3VectorsAreEqual(aVector, kCC3VectorZero) ) {
		[[self class] translate: self.glMatrix by: aVector];
		isIdentity = NO;
	}
}

-(void) translateByX: (GLfloat) distance {
	// Short-circuit an identity transform
	if ( distance != 0.0f ) {
		[[self class] translate: self.glMatrix byX: distance];
		isIdentity = NO;
	}
}

-(void) translateByY: (GLfloat) distance {
	// Short-circuit an identity transform
	if ( distance != 0.0f ) {
		[[self class] translate: self.glMatrix byY: distance];
		isIdentity = NO;
	}
}

-(void) translateByZ: (GLfloat) distance {
	// Short-circuit an identity transform
	if ( distance != 0.0f ) {
		[[self class] translate: self.glMatrix byZ: distance];
		isIdentity = NO;
	}
}

-(void) rotateBy: (CC3Vector) aVector {
	// Short-circuit an identity transform
	if ( !CC3VectorsAreEqual(aVector, kCC3VectorZero) ) {
		[[self class] rotateYXZ: self.glMatrix by: aVector];
		isIdentity = NO;
	}
}

-(void) rotateByX: (GLfloat) degrees {
	// Short-circuit an identity transform
	if ( degrees != 0.0f ) {
		[[self class] rotate: self.glMatrix byX: degrees];
		isIdentity = NO;
	}
}

-(void) rotateByY: (GLfloat) degrees {
	// Short-circuit an identity transform
	if ( degrees != 0.0f ) {
		[[self class] rotate: self.glMatrix byY: degrees];
		isIdentity = NO;
	}
}

-(void) rotateByZ: (GLfloat) degrees {
	// Short-circuit an identity transform
	if ( degrees != 0.0f ) {
		[[self class] rotate: self.glMatrix byZ: degrees];
		isIdentity = NO;
	}
}

-(void) rotateByQuaternion: (CC3Vector4) aQuaternion {
	// Short-circuit an identity transform
	if ( !CC3Vector4sAreEqual(aQuaternion, kCC3Vector4QuaternionIdentity) ) {
		[[self class] rotate: self.glMatrix byQuaternion: aQuaternion];
		isIdentity = NO;
	}
}

-(void) scaleBy: (CC3Vector) aVector {
	// Short-circuit an identity transform
	if ( !CC3VectorsAreEqual(aVector, kCC3VectorUnitCube) ) {
		[[self class] scale: self.glMatrix by: aVector];
		isIdentity = NO;
	}
}

-(void) scaleByX: (GLfloat) scaleFactor {
	// Short-circuit an identity transform
	if ( scaleFactor != 1.0f ) {
		[[self class] scale: self.glMatrix byX: scaleFactor];
		isIdentity = NO;
	}
}

-(void) scaleByY: (GLfloat) scaleFactor {
	// Short-circuit an identity transform
	if ( scaleFactor != 1.0f ) {
		[[self class] scale: self.glMatrix byY: scaleFactor];
		isIdentity = NO;
	}
}

-(void) scaleByZ: (GLfloat) scaleFactor {
	// Short-circuit an identity transform
	if ( scaleFactor != 1.0f ) {
		[[self class] scale: self.glMatrix byZ: scaleFactor];
		isIdentity = NO;
	}
}

-(void) scaleUniformlyBy: (GLfloat) scaleFactor {
	// Short-circuit an identity transform
	if ( scaleFactor != 1.0f ) {
		[[self class] scale: self.glMatrix uniformlyBy: scaleFactor];
		isIdentity = NO;
	}
}

#pragma mark Matrix transformations

+(void) transform: (GLfloat*) aGLMatrix
	  translateBy: (CC3Vector) translationVector
		 rotateBy: (CC3Vector) rotationVector
		  scaleBy: (CC3Vector) scaleVector {

	kmVec3 kmTranslation = kmVec3Make(translationVector.x, translationVector.y, translationVector.z);
	kmVec3 kmRotation = kmVec3Make(DegreesToRadians(rotationVector.x),
								   DegreesToRadians(rotationVector.y),
								   DegreesToRadians(rotationVector.z));
	kmVec3 kmScale = kmVec3Make(scaleVector.x, scaleVector.y, scaleVector.z);

	kmMat4 mXfm;
	kmMat4Transformation(&mXfm, kmTranslation, kmRotation, kmScale);
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mXfm];
}

+(void) rotateYXZ: (GLfloat*) aGLMatrix by: (CC3Vector) aVector {
	kmMat4 mRot;
	CC3Vector rotRads = CC3VectorScaleUniform(aVector, DegreesToRadiansFactor);
	kmMat4RotationYXZ(&mRot, rotRads.x, rotRads.y, rotRads.z);
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) rotateZYX: (GLfloat*) aGLMatrix by: (CC3Vector) aVector {
	kmMat4 mRot;
	CC3Vector rotRads = CC3VectorScaleUniform(aVector, DegreesToRadiansFactor);
	kmMat4RotationZYX(&mRot, rotRads.x, rotRads.y, rotRads.z);
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) rotate: (GLfloat*) aGLMatrix byX: (GLfloat) degrees {
	kmMat4 mRot;
	kmMat4RotationX(&mRot, DegreesToRadians(degrees));
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) rotate: (GLfloat*) aGLMatrix byY: (GLfloat) degrees {
	kmMat4 mRot;
	kmMat4RotationY(&mRot, DegreesToRadians(degrees));
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) rotate: (GLfloat*) aGLMatrix byZ: (GLfloat) degrees {
	kmMat4 mRot;
	kmMat4RotationZ(&mRot, DegreesToRadians(degrees));
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) rotate: (GLfloat*) aGLMatrix byQuaternion: (CC3Vector4) aQuaternion {
	kmMat4 mRot;
	kmMat4RotationQuaternion(&mRot, (kmQuaternion*)&aQuaternion);
	[self multiply: aGLMatrix byMatrix: (GLfloat*)&mRot];
}

+(void) translate: (GLfloat*) aGLMatrix by: (CC3Vector) aVector {
	GLfloat* m = aGLMatrix;					// Make a simple alias
	
	m[12] = aVector.x * m[0] + aVector.y * m[4] + aVector.z * m[8] + m[12];
	m[13] = aVector.x * m[1] + aVector.y * m[5] + aVector.z * m[9] + m[13];
	m[14] = aVector.x * m[2] + aVector.y * m[6] + aVector.z * m[10] + m[14];
    m[15] = aVector.x * m[3] + aVector.y * m[7] + aVector.z * m[11] + m[15];
}


+(void) translate: (GLfloat*) aGLMatrix byX: (GLfloat) distance {
	[self translate: aGLMatrix by: cc3v(distance, 0.0, 0.0)];
}

+(void) translate: (GLfloat*) aGLMatrix byY: (GLfloat) distance {
	[self translate: aGLMatrix by: cc3v(0.0, distance, 0.0)];
}

+(void) translate: (GLfloat*) aGLMatrix byZ: (GLfloat) distance {
	[self translate: aGLMatrix by: cc3v(0.0, 0.0, distance)];
}

+(void) scale: (GLfloat*) aGLMatrix by: (CC3Vector) aVector {
	GLfloat* m = aGLMatrix;					// Make a simple alias

	m[0] *= aVector.x;
	m[1] *= aVector.x;
	m[2] *= aVector.x;
	m[3] *= aVector.x;
	
	m[4] *= aVector.y;
	m[5] *= aVector.y;
	m[6] *= aVector.y;
	m[7] *= aVector.y;
	
	m[8] *= aVector.z;
	m[9] *= aVector.z;
	m[10] *= aVector.z;
	m[11] *= aVector.z;
}

+(void) scale: (GLfloat*) aGLMatrix byX: (GLfloat) scaleFactor {
	[self scale: aGLMatrix by: cc3v(scaleFactor, 1.0, 1.0)];
}

+(void) scale: (GLfloat*) aGLMatrix byY: (GLfloat) scaleFactor {
	[self scale: aGLMatrix by: cc3v(1.0, scaleFactor, 1.0)];
}

+(void) scale: (GLfloat*) aGLMatrix byZ: (GLfloat) scaleFactor {
	[self scale: aGLMatrix by: cc3v(1.0, 1.0, scaleFactor)];
}
	
+(void) scale: (GLfloat*) aGLMatrix uniformlyBy: (GLfloat) scaleFactor {
	[self scale: aGLMatrix by: cc3v(scaleFactor, scaleFactor, scaleFactor)];
}
		 

#pragma mark -
#pragma mark Instance math operations

// Includes short-circuits when one of the matrix is an identity matrix
-(void) multiplyByMatrix: (CC3GLMatrix*) aGLMatrix {

	// If other matrix is identity, this matrix doesn't change, so leave
	if (aGLMatrix.isIdentity) {
		return;
	}
	
	// If this matrix is identity, it just becomes the other matrix
	if (self.isIdentity) {
		[self populateFrom: aGLMatrix];
		return;
	}

	// Otherwise, go through with the multiplication
	[[self class] multiply: self.glMatrix byMatrix: aGLMatrix.glMatrix];
	isIdentity = NO;
}

-(CC3Vector) transformLocation: (CC3Vector) aLocation {
	// Short-circuit if this is an identity matrix
	if (isIdentity) {
		return aLocation;
	} else {
		return [[self class] transformLocation: aLocation withMatrix: self.glMatrix];
	}
}

-(CC3Vector) transformDirection: (CC3Vector) aDirection {
	// Short-circuit if this is an identity matrix
	if (isIdentity) {
		return aDirection;
	} else {
		return [[self class] transformDirection: aDirection withMatrix: self.glMatrix];
	}
}

-(CC3Vector4) transformHomogeneousVector: (CC3Vector4) aVector {
	// Short-circuit if this is an identity matrix
	if (isIdentity) {
		return aVector;
	} else {
		return [[self class] transformHomogeneousVector: aVector withMatrix: self.glMatrix];
	}
}

-(void) transpose {
	// Short-circuit if this is an identity matrix
	if (!isIdentity) {
		[[self class] transpose: self.glMatrix];
	}
}

-(BOOL) invert {
	// Short-circuit if this is an identity matrix
	if (isIdentity) {
		return YES;
	} else {
		return [[self class] invert: self.glMatrix];
	}
}

-(BOOL) invertAffine {
	// Short-circuit if this is an identity matrix
	if (isIdentity) {
		return YES;
	} else {
		return [[self class] invertAffine: self.glMatrix];
	}
}

-(void) invertRigid {
	// Short-circuit if this is an identity matrix
	if (!isIdentity) {
		[[self class] invertRigid: self.glMatrix];
	}
}


#pragma mark Matrix math operations

+(void) multiply: (GLfloat*) aGLMatrix byMatrix: (GLfloat*) anotherGLMatrix {
	kmMat4 mOut;
	kmMat4Multiply(&mOut, (kmMat4*)aGLMatrix, (kmMat4*)anotherGLMatrix);
	[self copyMatrix: (GLfloat*)&mOut into: aGLMatrix];
}

+(CC3Vector) transformLocation: (CC3Vector) aLocation withMatrix: (GLfloat*) aGLMatrix {
	return CC3VectorFromCC3Vector4([self transformHomogeneousVector: CC3Vector4FromCC3Vector(aLocation, 1.0)
														withMatrix: aGLMatrix]);
}

+(CC3Vector) transformDirection: (CC3Vector) aDirection withMatrix: (GLfloat*) aGLMatrix {
	return CC3VectorFromCC3Vector4([self transformHomogeneousVector: CC3Vector4FromCC3Vector(aDirection, 0.0)
														withMatrix: aGLMatrix]);
}

+(CC3Vector4) transformHomogeneousVector: (CC3Vector4) aVector withMatrix: (GLfloat*) aGLMatrix {
	CC3Vector4 vOut;
	GLfloat* m = aGLMatrix;					// Make a simple alias

	vOut.x = aVector.x * m[0] + aVector.y * m[4] + aVector.z * m[8] + aVector.w * m[12];
	vOut.y = aVector.x * m[1] + aVector.y * m[5] + aVector.z * m[9] + aVector.w * m[13];
	vOut.z = aVector.x * m[2] + aVector.y * m[6] + aVector.z * m[10] + aVector.w * m[14];
    vOut.w = aVector.x * m[3] + aVector.y * m[7] + aVector.z * m[11] + aVector.w * m[15];

	return vOut;
}

+(void) transpose: (GLfloat*) aGLMatrix {
	[self swap: 1 with: 4 inMatrix: aGLMatrix];
	[self swap: 2 with: 8 inMatrix: aGLMatrix];
	[self swap: 3 with: 12 inMatrix: aGLMatrix];
	[self swap: 6 with: 9 inMatrix: aGLMatrix];
	[self swap: 7 with: 13 inMatrix: aGLMatrix];
	[self swap: 11 with: 14 inMatrix: aGLMatrix];
}

+(BOOL) invert: (GLfloat*) aGLMatrix {
    kmMat4 inv;
	[[self class] copyMatrix: aGLMatrix into: (GLfloat*)&inv];

    kmMat4 tmp;
	[[self class] copyMatrix: (GLfloat*)identityContents into: (GLfloat*)&tmp];
    
	BOOL wasInverted = kmGaussJordan(&inv, &tmp);
	if (wasInverted) {
		[[self class] copyMatrix: (GLfloat*)&inv into: aGLMatrix];
	}
    return wasInverted;
}

+(BOOL) invertAffine: (GLfloat*) aGLMatrix {
/*
 M = |  L  t |
     |  0  1 |
	 
	 where L is a 3x3 linear tranformation matrix, t is a translation vector, and 0 is a row of 3 zeros
 */

	GLfloat* m = aGLMatrix;					// Make a simple alias
	BOOL wasInverted = [self invert: m];	// Invert the matrix
	m[3] = m[7] = m[11] = 0.0f;				// Ensure bottom row are exactly {0, 0, 0, 1}
	m[15] = 1.0f;
    return wasInverted;
}

+(void) invertRigid: (GLfloat*) aGLMatrix {
/*
 M = |  RT  -RT(t) |
     |  0     1    |
	 
	 where RT is the transposed 3x3 rotation matrix extracted from the 4x4 matrix
	 and t is a translation vector extracted from the 4x4 matrix
 */
	
	GLfloat* m = aGLMatrix;		// Make a simple alias
	
	// Extract translation component of matrix and remove it to leave a rotation-only matrix
	CC3Vector t = cc3v(m[12], m[13], m[14]);
	m[12] = m[13] = m[14] = 0.0f;

	// Transpose (invert) rotation matrix
	[self transpose: m];
	
	// Transform negated translation with transposed rotation matrix
	// and reinsert into transposed matrix
	t = [self transformDirection: CC3VectorNegate(t) withMatrix: m];	
	m[12] = t.x;
	m[13] = t.y;
	m[14] = t.z;
}

@end



