//
// Copyright 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ImageMtl.h:
//    Defines the class interface for ImageMtl, implementing ImageImpl.
//

#ifndef LIBANGLE_RENDERER_METAL_IMAGEMTL_H
#define LIBANGLE_RENDERER_METAL_IMAGEMTL_H

#include "libANGLE/renderer/ImageImpl.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

namespace rx
{
class ImageMtl : public ImageImpl
{
  public:
    ImageMtl(const egl::ImageState &state, const gl::Context *context);
    ~ImageMtl() override;
    void onDestroy(const egl::Display *display) override;

    egl::Error initialize(const egl::Display *display) override;

    angle::Result orphan(const gl::Context *context, egl::ImageSibling *sibling) override;

    const mtl::TextureRef &getTexture() const { return mNativeTexture; }
    gl::TextureType getImageTextureType() const { return mImageTextureType; }
    uint32_t getImageLevel() const { return mImageLevel; }
    uint32_t getImageLayer() const { return mImageLayer; }

  private:
    gl::TextureType mImageTextureType;
    uint32_t mImageLevel = 0;
    uint32_t mImageLayer = 0;

    mtl::TextureRef mNativeTexture;

    const gl::Context *mContext;
};
}

#endif /* LIBANGLE_RENDERER_METAL_IMAGEMTL_H */
