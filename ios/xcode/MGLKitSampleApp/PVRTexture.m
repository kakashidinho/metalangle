/*

    File: PVRTexture.m
Abstract: The PVRTexture class is responsible for loading .pvr files.
 Version: 1.6

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2014 Apple Inc. All Rights Reserved.


*/

#import "PVRTexture.h"

#import <MetalANGLE/GLES2/gl2ext.h>

static const uint32_t kPVRVersion3 = 0x03525650;

enum
{
    kPVRTextureFlagTypePVRTC_RGB_2,
    kPVRTextureFlagTypePVRTC_RGBA_2,
    kPVRTextureFlagTypePVRTC_RGB_4,
    kPVRTextureFlagTypePVRTC_RGBA_4,

    kPVRTextureFlagTypeASTC_4x4 = 27,
    kPVRTextureFlagTypeASTC_8x8 = 34,
};

enum
{
    kPVRTextureColorSpaceLinear,
    kPVRTextureColorSpaceSRGB,
};

typedef struct _PVRTexHeader
{
    uint32_t version;
    uint32_t flags;
    uint32_t pixelFormat[2];
    uint32_t colourSpace;
    uint32_t channelType;
    uint32_t height;
    uint32_t width;
    uint32_t depth;
    uint32_t numSurfaces;
    uint32_t numFaces;
    uint32_t numMipmaps;
    uint32_t metaDataSize;
} PVRTexHeader;

static void GetFormatBlockInfo(uint64_t format,
                               uint32_t *blockWidth,
                               uint32_t *blockHeight,
                               uint32_t *bpp,
                               uint32_t *minBlocks)
{
    switch (format)
    {
        case kPVRTextureFlagTypePVRTC_RGB_2:
        case kPVRTextureFlagTypePVRTC_RGBA_2:
            *blockWidth = 8;
            *blockHeight = 4;
            *bpp = 2;
            *minBlocks = 2;
            break;
        case kPVRTextureFlagTypePVRTC_RGB_4:
        case kPVRTextureFlagTypePVRTC_RGBA_4:
            *blockWidth = 4;
            *blockHeight = 4;
            *bpp = 4;
            *minBlocks = 2;
            break;
        case kPVRTextureFlagTypeASTC_4x4:
            *blockWidth = 4;
            *blockHeight = 4;
            *bpp = 8;
            *minBlocks = 1;
            break;
        case kPVRTextureFlagTypeASTC_8x8:
            *blockWidth = 8;
            *blockHeight = 8;
            *bpp = 2;
            *minBlocks = 1;
            break;
        default:
            // Not supported;
            abort();
    }
}

static bool GetFormatInfo(uint64_t format,
                          uint32_t colorSpace,
                          uint32_t *blockWidth,
                          uint32_t *blockHeight,
                          uint32_t *bpp,
                          uint32_t *minBlocks,
                          BOOL *hasAlpha,
                          GLenum *internalFormat)
{
    *minBlocks = 0;
    *hasAlpha = NO;
    switch (format)
    {
        case kPVRTextureFlagTypePVRTC_RGB_2:
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB_PVRTC_2BPPV1_EXT;
            else
                *internalFormat = GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG;
            break;
        case kPVRTextureFlagTypePVRTC_RGBA_2:
            *hasAlpha = YES;
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB_ALPHA_PVRTC_2BPPV1_EXT;
            else
                *internalFormat = GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG;
            break;
        case kPVRTextureFlagTypePVRTC_RGB_4:
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB_PVRTC_4BPPV1_EXT;
            else
                *internalFormat = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
            break;
        case kPVRTextureFlagTypePVRTC_RGBA_4:
            *hasAlpha = YES;
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB_ALPHA_PVRTC_4BPPV1_EXT;
            else
                *internalFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
            break;
        case kPVRTextureFlagTypeASTC_4x4:
            *hasAlpha = YES;
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR;
            else
                *internalFormat = GL_COMPRESSED_RGBA_ASTC_4x4_KHR;
            break;
        case kPVRTextureFlagTypeASTC_8x8:
            *hasAlpha = YES;
            if (colorSpace == kPVRTextureColorSpaceSRGB)
                *internalFormat = GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR;
            else
                *internalFormat = GL_COMPRESSED_RGBA_ASTC_8x8_KHR;
            break;
        default:
            // Not supported;
            return false;
    }

    GetFormatBlockInfo(format, blockWidth, blockHeight, bpp, minBlocks);

    return true;
}

@implementation PVRTexture

@synthesize name = _name;
@synthesize width = _width;
@synthesize height = _height;
@synthesize internalFormat = _internalFormat;
@synthesize hasAlpha = _hasAlpha;


- (BOOL)unpackPVRData:(NSData *)data
{
    BOOL success = FALSE;
    const PVRTexHeader *header = NULL;
    uint32_t pvrVersion;
    uint64_t format;
    uint32_t colorSpace;
    uint32_t dataLength = 0, dataOffset = 0, dataSize = 0;
    uint32_t blockSize = 0, widthBlocks = 0, heightBlocks = 0;
    uint32_t blockWidth = 0, blockHeight = 0;
    uint32_t minBlocks = 0;
    uint32_t width = 0, height = 0, bpp = 4;
    uint32_t metaDataSize = 0;
    uint32_t numMipmaps = 0;
    const uint8_t *bytes = NULL;

    header = (const PVRTexHeader *)[data bytes];

    pvrVersion = CFSwapInt32LittleToHost(header->version);

    if (pvrVersion != kPVRVersion3)
    {
        return FALSE;
    }

    memcpy(&format, header->pixelFormat, sizeof(format));
    format = CFSwapInt64LittleToHost(format);
    colorSpace = CFSwapInt32LittleToHost(header->colourSpace);
    numMipmaps = CFSwapInt32LittleToHost(header->numMipmaps);
    metaDataSize = CFSwapInt32LittleToHost(header->metaDataSize);

    if (GetFormatInfo(format, colorSpace, &blockWidth, &blockHeight, &bpp, &minBlocks, &_hasAlpha,
                      &_internalFormat))
    {
        [_imageData removeAllObjects];

        _width = width = CFSwapInt32LittleToHost(header->width);
        _height = height = CFSwapInt32LittleToHost(header->height);

        dataLength = (uint32_t)data.length - sizeof(PVRTexHeader) - metaDataSize;

        bytes = ((const uint8_t *)[data bytes]) + sizeof(PVRTexHeader) + metaDataSize;

        blockSize = blockWidth * blockHeight; // Pixel by pixel block size

        // Calculate the data size for each texture level and respect the minimum number of blocks
        for (uint32_t mip = 0; mip < numMipmaps; ++mip)
        {
            widthBlocks = width / blockWidth;
            heightBlocks = height / blockHeight;

            // Clamp to minimum number of blocks
            if (widthBlocks < minBlocks)
                widthBlocks = minBlocks;
            if (heightBlocks < minBlocks)
                heightBlocks = minBlocks;

            dataSize = widthBlocks * heightBlocks * ((blockSize  * bpp) / 8);

            [_imageData addObject:[NSData dataWithBytes:bytes+dataOffset length:dataSize]];

            dataOffset += dataSize;

            width = MAX(width >> 1, 1);
            height = MAX(height >> 1, 1);
        }

        success = TRUE;
    }

    return success;
}


- (BOOL)createGLTexture
{
    int width = _width;
    int height = _height;
    NSData *data;
    GLenum err;

    if ([_imageData count] > 0)
    {
        if (_name != 0)
            glDeleteTextures(1, &_name);

        glGenTextures(1, &_name);
        glBindTexture(GL_TEXTURE_2D, _name);
    }

    if ([_imageData count] > 1)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    else
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    for (int i=0; i < [_imageData count]; i++)
    {
        data = [_imageData objectAtIndex:i];
        glCompressedTexImage2D(GL_TEXTURE_2D, i, _internalFormat, width, height, 0, (int)[data length], [data bytes]);

        err = glGetError();
        if (err != GL_NO_ERROR)
        {
            NSLog(@"Error uploading compressed texture level: %d. glError: 0x%04X", i, err);
            return FALSE;
        }

        width = MAX(width >> 1, 1);
        height = MAX(height >> 1, 1);
    }

    [_imageData removeAllObjects];

    return TRUE;
}


- (id)initWithContentsOfFile:(NSString *)relpath
{
    if (self = [super init])
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:relpath ofType:nil];
        NSData *data   = [NSData dataWithContentsOfFile:path];

        _imageData = [[NSMutableArray alloc] initWithCapacity:10];

        _name = 0;
        _width = _height = 0;
        _internalFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
        _hasAlpha = FALSE;

        if (!data || ![self unpackPVRData:data] || ![self createGLTexture])
        {
            self = nil;
        }
    }

    return self;
}


- (id)initWithContentsOfURL:(NSURL *)url
{
    if (![url isFileURL])
    {
        return nil;
    }

    return [self initWithContentsOfFile:[url path]];
}


+ (id)pvrTextureWithContentsOfFile:(NSString *)path
{
    return [[self alloc] initWithContentsOfFile:path];
}


+ (id)pvrTextureWithContentsOfURL:(NSURL *)url
{
    if (![url isFileURL])
        return nil;

    return [PVRTexture pvrTextureWithContentsOfFile:[url path]];
}

+ (GLuint)glTextureWithContentsOfFile:(NSString *)path
{
    PVRTexture *pvrTextureWrapper = [PVRTexture pvrTextureWithContentsOfFile:path];
    GLuint texture                = pvrTextureWrapper.name;
    pvrTextureWrapper->_name      = 0;
    return texture;
}

- (void)dealloc
{
    _imageData = nil;

    if (_name != 0)
        glDeleteTextures(1, &_name);
}

@end
