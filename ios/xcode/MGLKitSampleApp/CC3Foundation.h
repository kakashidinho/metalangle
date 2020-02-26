/*
 * CC3Foundation.h
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
 */

/** @file */  // Doxygen marker

/** @mainpage cocos3d API reference
 *
 * @section intro About cocos3d
 *
 * Cocos3d extends cocos2d to add support for full 3D rendering, in combination with
 * normal cocos2d 2D rendering.
 *
 * Rendering of 3D objects is performed within a CC3Layer, which is a specialized cocos2d
 * layer. In your application, you will usually create a customized subclass of CC3Layer,
 * which you add to a CCScene, or other CCLayer, to act as a bridge between the 2D and
 * 3D rendering.
 *
 * The CC3Layer instance holds a reference to an instance of CC3World, which manages the
 * 3D model objects, including loading from 3D model files, such as PowerVR POD files.
 * You will usually create a customized subclass of CC3World to create and manage the
 * objects and dynamics of your 3D world.
 */

/* Base library of definitions and functions for operating in a 3D world. */

#import "CC3Logging.h"
#import "CC3Math.h"
#import "ccTypes.h"
//#import "CCDirector.h"

#pragma mark -
#pragma mark 3D cartesian vector structure and functions

/** A vector in 3D space. */
typedef struct
{
    GLfloat x; /**< The X-componenent of the vector. */
    GLfloat y; /**< The Y-componenent of the vector. */
    GLfloat z; /**< The Z-componenent of the vector. */
} CC3Vector;

/** A CC3Vector of zero length at the origin. */
static const CC3Vector kCC3VectorZero = {0.0, 0.0, 0.0};

/** A CC3Vector with each component equal to one, representing the diagonal of a unit cube. */
static const CC3Vector kCC3VectorUnitCube = {1.0, 1.0, 1.0};

/** The diagonal length of a unit cube. */
static const GLfloat kCC3VectorUnitCubeLength = M_SQRT3;

/** Unit vector pointing in the same direction as the positive X-axis. */
static const CC3Vector kCC3VectorUnitXPositive = {1.0, 0.0, 0.0};

/** Unit vector pointing in the same direction as the positive Y-axis. */
static const CC3Vector kCC3VectorUnitYPositive = {0.0, 1.0, 0.0};

/** Unit vector pointing in the same direction as the positive Z-axis. */
static const CC3Vector kCC3VectorUnitZPositive = {0.0, 0.0, 1.0};

/** Unit vector pointing in the same direction as the negative X-axis. */
static const CC3Vector kCC3VectorUnitXNegative = {-1.0, 0.0, 0.0};

/** Unit vector pointing in the same direction as the negative Y-axis. */
static const CC3Vector kCC3VectorUnitYNegative = {0.0, -1.0, 0.0};

/** Unit vector pointing in the same direction as the negative Z-axis. */
static const CC3Vector kCC3VectorUnitZNegative = {0.0, 0.0, -1.0};

/** Returns a string description of the specified CC3Vector struct in the form "(x, y, z)" */
NSString *NSStringFromCC3Vector(CC3Vector v);

/** Returns a CC3Vector structure constructed from the vector components. */
CC3Vector CC3VectorMake(GLfloat x, GLfloat y, GLfloat z);

/** Convenience alias macro to create CC3Vectors with less keystrokes. */
#define cc3v(X, Y, Z) CC3VectorMake((X), (Y), (Z))

/** Returns whether the two vectors are equal by comparing their respective components. */
BOOL CC3VectorsAreEqual(CC3Vector v1, CC3Vector v2);

/**
 * Returns a vector whose components comprise the minimum value of each of the respective
 * components of the two specfied vectors. In general, do not expect this method to return
 * one of the specified vectors, but a new vector, each of the components of which is the
 * minimum value for that component between the two vectors.
 */
CC3Vector CC3VectorMinimize(CC3Vector v1, CC3Vector v2);

/**
 * Returns a vector whose components comprise the maximum value of each of the respective
 * components of the two specfied vectors. In general, do not expect this method to return
 * one of the specified vectors, but a new vector, each of the components of which is the
 * maximum value for that component between the two vectors.
 */
CC3Vector CC3VectorMaximize(CC3Vector v1, CC3Vector v2);

/**
 * Returns the scalar length of the specified CC3Vector from the origin.
 * This is calculated as sqrt(x*x + y*y + z*z) and will always be positive.
 */
GLfloat CC3VectorLength(CC3Vector v);

/**
 * Returns a normalized copy of the specified CC3Vector so that its length is 1.0.
 * If the length is zero, the original vector (a zero vector) is returned.
 */
CC3Vector CC3VectorNormalize(CC3Vector v);

/**
 * Returns a vector that is the negative of the specified vector in all directions.
 * For vectors that represent directions, the returned vector points in the direction
 * opposite to the original.
 */
CC3Vector CC3VectorNegate(CC3Vector v);

/**
 * Returns a CC3Vector that is the inverse of the specified vector in all directions,
 * such that scaling the original by the inverse using CC3VectorScale will result in a vector
 * of unit dimension in each direction (1.0, 1.0, 1.0). The result of this function is effectively
 * calculated by dividing each component of the original vector into 1.0 (1.0/x, 1.0/y, 1.0/z).
 * It is the responsibility of the caller to ensure that none of the components of the original is
 * zero.
 */
CC3Vector CC3VectorInvert(CC3Vector v);

/**
 * Returns the result of adding the two specified vectors, by adding the corresponding components
 * of both vectors. This can also be thought of as a translation of the first vector by the second.
 */
CC3Vector CC3VectorAdd(CC3Vector v, CC3Vector translation);

/**
 * Returns the difference between two vectors, by subtracting the subtrahend from the minuend,
 * which is accomplished by subtracting each of the corresponding x,y,z components.
 */
CC3Vector CC3VectorDifference(CC3Vector minuend, CC3Vector subtrahend);

/**
 * Returns the difference between two rotation vectors, in terms of the minimal degrees,
 * along each axis, required to travel between the two roations, given that rotations
 * are cyclical with a period of 360 degrees. The result may be positive or negative,
 * but will always be between (+/-180 degrees).
 *
 * For example, the difference between 350 and 10 will yield -20 (ie- the smallest change
 * from 10 degrees to 350 degrees is -20 degrees) rather than +340 (from simple subtraction).
 * Similarly, the difference between 10 and 350 will yield +20 (ie- the smallest change from
 * 350 degrees to 10 degrees is +20 degrees) rather than -340 (from simple subtraction).
 */
CC3Vector CC3VectorRotationalDifference(CC3Vector minuend, CC3Vector subtrahend);

/** Returns the positive scalar distance between the ends of the two specified vectors. */
GLfloat CC3VectorDistance(CC3Vector start, CC3Vector end);

/**
 * Returns the result of scaling the original vector by the corresponding scale vector.
 * Scaling can be different for each axis. This has the effect of multiplying each component
 * of the vector by the corresponding component in the scale vector.
 */
CC3Vector CC3VectorScale(CC3Vector v, CC3Vector scale);

/** Returns the result of scaling the original vector by the corresponding scale factor uniformly
 * along all axes. */
CC3Vector CC3VectorScaleUniform(CC3Vector v, GLfloat scale);

/** Returns the dot-product of the two given vectors (v1 . v2). */
GLfloat CC3VectorDot(CC3Vector v1, CC3Vector v2);

/** Returns the cross-product of the two given vectors (v1 x v2). */
CC3Vector CC3VectorCross(CC3Vector v1, CC3Vector v2);

/**
 * Returns a linear interpolation between two vectors, based on the blendFactor.
 * which should be between zero and one inclusive. The returned value is calculated
 * as v1 + (blendFactor * (v2 - v1)). If the blendFactor is either zero or one
 * exactly, this method short-circuits to simply return v1 or v2 respectively.
 */
CC3Vector CC3VectorLerp(CC3Vector v1, CC3Vector v2, GLfloat blendFactor);

/**
 * Defines a ray or line in 3D space, by specifying a starting location and direction.
 *
 * For a line, the startLocation can variously be interpreted as the location of any
 * point on the line.
 */
typedef struct
{
    CC3Vector startLocation; /**< The location where the ray starts. */
    CC3Vector direction;     /**< The direction in which the ray points. */
} CC3Ray;

/**
 * Defines an axially-aligned-bounding-box (AABB), describing
 * a 3D volume by specifying the minimum and maximum 3D corners.
 */
typedef struct
{
    CC3Vector minimum; /**< The minimum corner (bottom-left-rear). */
    CC3Vector maximum; /**< The maximum corner (top-right-front). */
} CC3BoundingBox;

/**
 * Defines a simple vertex, containing location, normal, and texture coordinate
 * data. Useful for interleaving vertex data for presentation to the GL engine.
 */
typedef struct
{
    CC3Vector location; /**< The 3D location of the vertex. */
    CC3Vector normal;   /**< The 3D normal at the vertex. */
    ccTex2F texCoord;   /**< The 2D coordinate of this vertex on the texture. */
} CCTexturedVertex;

#pragma mark -
#pragma mark 3D angular vector structure and functions

/**
 * An angle such as a heading or inclination.
 * Can be measured in degrees or radians and may be positive or negative.
 */
typedef GLfloat CC3Angle;

/** Specifies a vector using angular coordinate axes. Angles are measured in degrees or radians. */
typedef struct
{
    CC3Angle heading;     /**< The horizontal heading. */
    CC3Angle inclination; /**< The inclination from horizontal. */
    GLfloat radius;       /**< The radial distance. */
} CC3AngularVector;

/** Returns a string description of the specified CC3AngularVector struct in the form "(heading,
 * inclination, radius)" */
NSString *NSStringFromCC3AngularVector(CC3AngularVector av);

/** Returns an CC3AngularVector structure constructed from the vector components. */
CC3AngularVector CC3AngularVectorMake(GLfloat heading, GLfloat inclination, GLfloat radius);

/**
 * Returns an CC3AngularVector providing the heading, inclination & radius of the specified
 * CC3Vector. Heading is measured in degrees, in the X-Z plane, clockwise from the negative Z-axis.
 * Inclination is measured in degrees, with up being in the positive-Y direction.
 */
CC3AngularVector CC3AngularVectorFromVector(CC3Vector v);

/**
 * Returns a CC3Vector from the specified CC3AngularVector.
 * Heading is measured in degrees, in the X-Z plane, clockwise from the negative Z-axis.
 * Inclination is measured in degrees, with up being in the positive-Y direction.
 */
CC3Vector CC3VectorFromAngularVector(CC3AngularVector av);

/**
 * Returns the difference between two CC3AngularVectors, by subtracting the corresponding heading,
 * inclination & radial components. Note that this is NOT true vector arithmetic, which would
 * yield a completely different angular and radial results.
 */
CC3AngularVector CC3AngularVectorDifference(CC3AngularVector minuend, CC3AngularVector subtrahend);

#pragma mark -
#pragma mark Cartesian vector in 4D homogeneous coordinate space structure and functions

/** A homogeneous vector in 4D graphics matrix space. */
typedef struct
{
    GLfloat x; /**< The X-componenent of the vector. */
    GLfloat y; /**< The Y-componenent of the vector. */
    GLfloat z; /**< The Z-componenent of the vector. */
    GLfloat w; /**< The homogeneous ratio factor. */
} CC3Vector4;

/** A CC3Vector4 of zero length at the origin. */
static const CC3Vector4 kCC3Vector4Zero = {0.0, 0.0, 0.0, 0.0};

/** A CC3Vector4 that represents the identity quaternion. */
static const CC3Vector4 kCC3Vector4QuaternionIdentity = {0.0, 0.0, 0.0, 1.0};

/** Returns a string description of the specified CC3Vector4 struct in the form "(x, y, z, w)" */
NSString *NSStringFromCC3Vector4(CC3Vector4 v);

/** Returns a CC3Vector4 structure constructed from the vector components. */
CC3Vector4 CC3Vector4Make(GLfloat x, GLfloat y, GLfloat z, GLfloat w);

/** Returns a CC3Vector4 structure constructed from a 3D vector and a w component. */
CC3Vector4 CC3Vector4FromCC3Vector(CC3Vector v, GLfloat w);

/**
 * Returns a CC3Vector structure constructed from a CC3Vector4. The CC3Vector4 is first homogenized
 * (via CC3Vector4Homogenize), before copying the resulting x, y & z coordinates into the CC3Vector.
 */
CC3Vector CC3VectorFromCC3Vector4(CC3Vector4 v);

/** Returns whether the two vectors are equal by comparing their respective components. */
BOOL CC3Vector4sAreEqual(CC3Vector4 v1, CC3Vector4 v2);

/**
 * If the specified homogeneous vector represents a location (w is not zero), returns
 * a homoginized copy of the vector, by dividing each component by the w-component
 * (including the w-component itself, leaving it with a value of one).
 * If the specified vector is a direction (w is zero), the vector is returned unchanged.
 */
CC3Vector4 CC3Vector4Homogenize(CC3Vector4 v);

/**
 * Returns the scalar length of the specified vector from the origin, including the w-component
 * This is calculated as sqrt(x*x + y*y + z*z + w*w) and will always be positive.
 */
GLfloat CC3Vector4Length(CC3Vector4 v);

/** Returns a normalized copy of the specified vector so that its length is 1.0. The w-component is
 * also normalized. */
CC3Vector4 CC3Vector4Normalize(CC3Vector4 v);

/** Returns a vector that is the negative of the specified vector in all directions. */
CC3Vector4 CC3Vector4Negate(CC3Vector4 v);

/** Returns the result of scaling the original vector by the corresponding scale factor uniformly
 * along all axes. */
CC3Vector4 CC3Vector4ScaleUniform(CC3Vector4 v, GLfloat scale);

/**
 * Returns the result of translating the original vector by the corresponding translation amounts
 * in each direction. This corresponds to an addition of one vector to the other.
 */
CC3Vector4 CC3Vector4Translate(CC3Vector4 v, CC3Vector4 translation);

/** Returns the dot-product of the two given vectors (v1 . v2). */
GLfloat CC3Vector4Dot(CC3Vector4 v1, CC3Vector4 v2);

/**
 * Returns a spherical linear interpolation between two vectors, based on the blendFactor.
 * which should be between zero and one inclusive. The returned value is calculated
 * as v1 + (blendFactor * (v2 - v1)). If the blendFactor is either zero or one
 * exactly, this method short-circuits to simply return v1 or v2 respectively.
 */
CC3Vector4 CC3Vector4Slerp(CC3Vector4 v1, CC3Vector4 v2, GLfloat blendFactor);

#pragma mark -
#pragma mark Plane and frustum structures and functions

/** The coefficients of the equation for a plane in 3D space (ax + by + cz + d = 0). */
typedef struct
{
    GLfloat a; /**< The a coefficient in the planar equation. */
    GLfloat b; /**< The b coefficient in the planar equation. */
    GLfloat c; /**< The c coefficient in the planar equation. */
    GLfloat d; /**< The d coefficient in the planar equation. */
} CC3Plane;

/** Returns a string description of the specified CC3Plane struct in the form "(a, b, c, d)" */
NSString *NSStringFromCC3Plane(CC3Plane p);

/** Returns a CC3Plane structure constructed from the specified coefficients. */
CC3Plane CC3PlaneMake(GLfloat a, GLfloat b, GLfloat c, GLfloat d);

/**
 * Returns a CC3Plane structure that contains the specified points.
 *
 * The direction of the normal of the returned plane is dependent on the winding order
 * of the three points. Winding is done in the order the points are specified
 * (p1 -> p2 -> p3), and the normal will point in the direction that has the three points
 * winding in a counter-clockwise direction, according to a right-handed coordinate
 * system. If the direction of the normal is important, be sure to specify the three
 * points in the appropriate order.
 */
CC3Plane CC3PlaneFromPoints(CC3Vector p1, CC3Vector p2, CC3Vector p3);

/** Returns a normalized copy of the specified CC3Plane so that the length of its normal (a, b, c)
 * is 1.0 */
CC3Plane CC3PlaneNormalize(CC3Plane p);

/** Returns the distance from the point represented by the vector to the specified normalized plane.
 */
GLfloat CC3DistanceFromNormalizedPlane(CC3Plane p, CC3Vector v);

/** Returns the normal of the plane, which is (a, b, c) from the planar equation. */
CC3Vector CC3PlaneNormal(CC3Plane p);

/**
 * Returns the location point of the intersection of the specified plane and a ray, which
 * is defined by a starting location and a direction.
 *
 * The returned result is a 4D vector, where the x, y & z components give the intersection
 * location in 3D space, and the w component gives the distance from the rayStart to the
 * intersection location. If this value is negative, the intersection point is in the
 * opposite direction to where the ray is pointing.
 *
 * If the ray is parallel to the plane, no intersection occurs, and the returned 4D vector
 * will be zeroed (equal to kCC3Vector4Zero).
 */
// CC3Vector4 CC3RayIntersectionWithPlane(CC3Plane plane, CC3Vector rayStart, CC3Vector rayDir);

/**
 * Returns the location of the point where the specified ray intersects the specified plane.
 *
 * The returned result is a 4D vector, where the x, y & z components give the intersection
 * location in 3D space, and the w component gives the distance from the startLocation of
 * the ray to the intersection location, in multiples of the ray direction vector. If this
 * value is negative, the intersection point is in the direction opposite to the direction
 * of the ray.
 *
 * If the ray is parallel to the plane, no intersection occurs, and the returned 4D vector
 * will be zeroed (equal to kCC3Vector4Zero).
 */
CC3Vector4 CC3RayIntersectionWithPlane(CC3Ray ray, CC3Plane plane);

#pragma mark -
#pragma mark Viewport structure and functions

/** GL viewport data */
typedef struct
{
    GLint x;   /**< The X-position of the bottom-left corner of the viewport. */
    GLint y;   /**< The Y-position of the bottom-left corner of the viewport. */
    GLsizei w; /**< The width of the viewport. */
    GLsizei h; /**< The height of the viewport. */
} CC3Viewport;

/** Returns a string description of the specified CC3Viewport struct in the form "(x, y, w, h)" */
NSString *NSStringFromCC3Viewport(CC3Viewport vp);

/** Returns a CC3Viewport structure constructed from the specified components. */
CC3Viewport CC3ViewportMake(GLint x, GLint y, GLint w, GLint h);

/** Returns whether the two viewports are equal by comparing their respective components. */
BOOL CC3ViewportsAreEqual(CC3Viewport vp1, CC3Viewport vp2);

/**
 * Returns whether the specified point lies within the specified viewport.
 * A point is considered inside the viewport if its coordinates lie inside
 * the viewport or on the minimum X or minimum Y edge.
 */
BOOL CC3ViewportContainsPoint(CC3Viewport vp, CGPoint point);

/** Returns the dimensions of the specified viewport as a rectangle. */
CGRect CGRectFromCC3Viewport(CC3Viewport vp);

#pragma mark -
#pragma mark ccColor4F constants and functions

/** Opaque Red */
static const ccColor4F kCCC4FRed = {1.0, 0.0, 0.0, 1.0};

/** Opaque Green */
static const ccColor4F kCCC4FGreen = {0.0, 1.0, 0.0, 1.0};

/** Opaque Blue */
static const ccColor4F kCCC4FBlue = {0.0, 0.0, 1.0, 1.0};

/** Opaque Cyan */
static const ccColor4F kCCC4FCyan = {0.0, 1.0, 1.0, 1.0};

/** Opaque Magenta */
static const ccColor4F kCCC4FMagenta = {1.0, 0.0, 1.0, 1.0};

/** Opaque Yellow */
static const ccColor4F kCCC4FYellow = {1.0, 1.0, 0.0, 1.0};

/** Opaque Light Gray */
static const ccColor4F kCCC4FLightGray = {(2.0 / 3.0), (2.0 / 3.0), (2.0 / 3.0), 1.0};

/** Opaque Dark Gray */
static const ccColor4F kCCC4FDarkGray = {(1.0 / 3.0), (1.0 / 3.0), (1.0 / 3.0), 1.0};

/** Opaque White */
static const ccColor4F kCCC4FWhite = {1.0, 1.0, 1.0, 1.0};

/** Opaque Black */
static const ccColor4F kCCC4FBlack = {0.0, 0.0, 0.0, 1.0};

/** Transparent Black */
static const ccColor4F kCCC4FBlackTransparent = {0.0, 0.0, 0.0, 0.0};

/** Returns a string description of the specified ccColor4F in the form "(r, g, b, a)" */
NSString *NSStringFromCCC4F(ccColor4F rgba);

/** Returns an ccColor4F structure constructed from the specified components */
ccColor4F CCC4FMake(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);

/** Returns whether the two colors are equal by comparing their respective components. */
BOOL CCC4FAreEqual(ccColor4F c1, ccColor4F c2);

/**
 * Returns the result of adding the two specified colors, by adding the corresponding components.
 * Each of the resulting color components is clamped to be between 0.0 and 1.0.
 * This can also be thought of as a translation of the first color by the second.
 */
ccColor4F CCC4FAdd(ccColor4F rgba, ccColor4F translation);

/**
 * Returns the difference between two colors, by subtracting the subtrahend from the minuend,
 * which is accomplished by subtracting each of the corresponding r,g, b, a components.
 * Each of the resulting color components is clamped to be between 0.0 and 1.0.
 */
ccColor4F CCC4FDifference(ccColor4F minuend, ccColor4F subtrahend);

/**
 * Returns an ccColor4F structure whose values are those of the specified original color,
 * where each color component has been translated by the specified offset.
 * Each of the resulting color components is clamped to be between 0.0 and 1.0.
 */
ccColor4F CCC4FUniformTranslate(ccColor4F rgba, GLfloat offset);

/**
 * Returns an ccColor4F structure whose values are a weighted average of the specified base color
 * and the blend color. The parameter blendWeight should be between zero and one. A value of zero
 * will leave the base color unchanged. A value of one will result in the blend being the same as
 * the blend color.
 */
ccColor4F CCC4FBlend(ccColor4F baseColor, ccColor4F blendColor, GLfloat blendWeight);

/**
 * Returns a random ccColor4F where each component value between the specified min inclusive and
 * the specified max exclusive. This can be useful when creating particle systems.
 */
ccColor4F RandomCCC4FBetween(ccColor4F min, ccColor4F max);

/** Returns a GLfloat between 0 and 1 converted from the specified GLubyte value between 0 and 255.
 */
GLfloat CCColorFloatFromByte(GLubyte colorValue);

/** Returns a GLubyte between 0 and 255 converted from the specified GLfloat value between 0 and 1.
 */
GLubyte CCColorByteFromFloat(GLfloat colorValue);

#pragma mark -
#pragma mark Miscellaneous extensions and functionality

/** Extension category to support cocos3d functionality. */
@interface NSObject (CC3)

/**
 * Convenience method to automatically autorelease when copying objects.
 * Invokes the copy method to create a copy of this instance, autoreleases it, and returns it.
 */
- (id)copyAutoreleased;

@end
