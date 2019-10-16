/*
 * CC3Math.h
 *
 * $Version: cocos3d 0.5-beta (eab7e651f462) on 2011-01-31 $
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

/** @file */	// Doxygen marker

/* Base library of definitions and functions for operating in a 3D world. */

#import <math.h>


#pragma mark Basic math support

#define M_SQRT3  1.732050807568877f						/* sqrt(3) */
#define kCircleDegreesPeriod  360.0f

/** Conversion between degrees and radians. */
#define DegreesToRadiansFactor  0.017453292519943f			// PI / 180
#define RadiansToDegreesFactor  57.29577951308232f			// 180 / PI
#define DegreesToRadians(D) ((D) * DegreesToRadiansFactor)
#define RadiansToDegrees(R) ((R) * RadiansToDegreesFactor)

/** Returns -1, 0 or +1 if the arguement is negative, zero or positive respectively. */
#define SIGN(A)	((A) < 0 ? -1 :((A) > 0 ? 1 : 0))

/** Returns the value clamped to be between the min and max values */
#define CLAMP(val, min, max) (MIN(MAX((val), (min)), (max)))

/** Returns a weighted average of the two values, where weight is between zero and one, inclusive. */
#define WAVG(val1, val2, weight) ((val1) + (((val2) - (val1)) * CLAMP(weight, 0.0, 1.0)))

/**
 * Returns the positive modulo remainder of value divided by period.
 *
 * This function is similar to fmod() (and uses fmod()), but converts a negative result
 * into a positive value that is the same distance away from the end of the cycle as the
 * result was below zero. In this sense, this function behaves like the numbers on a clock,
 * and Cyclic(-2.0, 12.0) will return 10.0 rather than -2.0. 
 */
float Cyclic(float value, float period);

/**
 * Returns the difference between the specified minuend and subtrahend, in terms of the
 * minimum difference within the specified periodic cycle. Therefore, the result may be
 * positive or negative, but will always be between (+period/2) and (-period/2).
 *
 * For example, for the numbers on a compass, the period is 360, and
 * CyclicDifference(350, 10, 360) will yield -20 (ie- the smallest change from 10 degrees
 * to 350 degrees is -20 degrees) rather than +340 (from simple subtraction). Similarly,
 * CyclicDifference(10, 350, 360) will yield +20 (ie- the smallest change from 350 degrees
 * to 10 degrees is +20 degrees) rather than -340 (from simple subtraction).
 */
float CyclicDifference(float minuend, float subtrahend, float period);


#pragma mark Random number generation

/** Returns a random unsigned integer over the full unsigned interger range (between 0 and 0xFFFFFFFF). */
unsigned int RandomUInt();

/** Returns a random unsigned integer between 0 inclusive and the specified max exclusive. */
unsigned int RandomUIntBelow(unsigned int max);

/** Returns a random double between 0.0 inclusive and 1.0 exclusive. */
double RandomDouble();

/** Returns a random double between the specified min inclusive and the specified max exclusive. */
double RandomDoubleBetween(double min, double max);

/** Returns a random float between 0.0 inclusive and 1.0 exclusive. */
float RandomFloat();

/** Returns a random float between the specified min inclusive and the specified max exclusive. */
float RandomFloatBetween(float min, float max);
