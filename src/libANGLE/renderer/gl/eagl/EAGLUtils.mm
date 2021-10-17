//
// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/gl/eagl/EAGLUtils.h"

#import "common/platform.h"

#if defined(ANGLE_PLATFORM_IOS) && !defined(ANGLE_PLATFORM_MACCATALYST)

#    import <QuartzCore/QuartzCore.h>
#    import <objc/message.h>
#    import <objc/runtime.h>

namespace eagl
{

namespace
{

class Impl
{
public:
    Impl()
    {
        classEAGLContext = objc_getClass("EAGLContext");
        classCAEAGLLayer = objc_getClass("CAEAGLLayer");

        // [EAGLContext setCurrentContext:]
        m_setCurrentContextSel = @selector(setCurrentContext:);
        m_setCurrentContextMethod = class_getClassMethod(classEAGLContext, m_setCurrentContextSel);
        if (m_setCurrentContextMethod)
        {
            IMP setCurrentContextImp;
            setCurrentContextImp    = method_getImplementation(m_setCurrentContextMethod);
            m_setCurrentContextFunc = reinterpret_cast<SetCurrentContextMsgFunc>(setCurrentContextImp);

        }
        else
        {
            m_setCurrentContextFunc = nullptr;
        }

        // [EAGLContext presentRenderbuffer:]
        m_presentRenderbufferSel    = @selector(presentRenderbuffer:);
        m_presentRenderbufferMethod = class_getInstanceMethod(classEAGLContext, m_presentRenderbufferSel);
        if (m_presentRenderbufferMethod) {
            IMP presentRenderbufferImp;
            presentRenderbufferImp    = method_getImplementation(m_presentRenderbufferMethod);
            m_presentRenderbufferFunc = reinterpret_cast<PresentRenderbufferMsgFunc>(presentRenderbufferImp);
        }
        else {
            m_presentRenderbufferFunc = nullptr;
        }
    }

    BOOL setCurrentContext(EAGLContextObj ctx)
    {
        if (m_setCurrentContextFunc) {
            return m_setCurrentContextFunc(classEAGLContext, m_setCurrentContextSel, ctx);
        }
        return NO;
    }

    void presentRenderbuffer(EAGLContextObj ctx, NSUInteger target)
    {
        if (m_presentRenderbufferFunc) {
            m_presentRenderbufferFunc(ctx, m_presentRenderbufferSel, target);
        }
    }

    Class classEAGLContext;
    Class classCAEAGLLayer;

private:
    // setCurrentContext method's metadata
    using SetCurrentContextMsgFunc = BOOL (*)(Class, SEL, id);

    Method m_setCurrentContextMethod;
    SetCurrentContextMsgFunc m_setCurrentContextFunc;
    SEL m_setCurrentContextSel;


    // presentRenderbuffer method's metadata
    using PresentRenderbufferMsgFunc = void (*)(id, SEL, NSUInteger);

    Method m_presentRenderbufferMethod;
    PresentRenderbufferMsgFunc m_presentRenderbufferFunc;
    SEL m_presentRenderbufferSel;
};

Impl &getImpl()
{
    static Impl s_impl;
    return s_impl;
}
}

EAGLContextObj createWithAPI(RenderingAPI api)
{
    Impl &impl         = getImpl();
    EAGLContextObj ctx = [impl.classEAGLContext alloc];

    if (!ctx)
    {
        return nil;
    }
    SEL initWithAPI = sel_registerName("initWithAPI:");
    auto iApi       = static_cast<NSUInteger>(api);

    using MsgSignature = id (*)(id, SEL, NSUInteger);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);
    ctx                = msgSend(ctx, initWithAPI, iApi);

    return ctx;
}
EAGLContextObj createWithAPIAndSharedContext(RenderingAPI api, EAGLContextObj sharedContext)
{
    Impl &impl         = getImpl();
    EAGLContextObj ctx = [impl.classEAGLContext alloc];

    if (!ctx)
    {
        return nil;
    }

    // sharedContext.sharegroup
    SEL shareGroupSel      = sel_registerName("sharegroup");
    using ShareGroupSig    = id (*)(id, SEL);
    auto shareGroupMsgSend = reinterpret_cast<ShareGroupSig>(objc_msgSend);
    id shareGroup          = shareGroupMsgSend(sharedContext, shareGroupSel);

    // ctx = [EAGLContext initWithAPI:api sharegroup:sharedContext.sharegroup]
    SEL initWithAPIAndSharedGroupSel = sel_registerName("initWithAPI:sharegroup:");
    auto iApi                        = static_cast<NSUInteger>(api);
    using InitMsg                    = id (*)(id, SEL, NSUInteger, id);
    auto initMsgSend                 = reinterpret_cast<InitMsg>(objc_msgSend);
    ctx = initMsgSend(ctx, initWithAPIAndSharedGroupSel, iApi, shareGroup);

    return ctx;
}
BOOL setCurrentContext(EAGLContextObj ctx)
{
    Impl &impl                       = getImpl();
    return impl.setCurrentContext(ctx);
}
BOOL texImageIOSurface(EAGLContextObj ctx,
                       IOSurfaceRef iosurface,
                       NSUInteger target,
                       NSUInteger internalFormat,
                       uint32_t width,
                       uint32_t height,
                       NSUInteger format,
                       NSUInteger type,
                       uint32_t plane)
{
    static SEL selector =
        sel_registerName("texImageIOSurface:target:internalFormat:width:height:format:type:plane:");

    using MsgSignature = BOOL (*)(id, SEL, IOSurfaceRef, NSUInteger, NSUInteger, uint32_t, uint32_t,
                                  NSUInteger, NSUInteger, uint32_t);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);

    BOOL re = msgSend(ctx, selector, iosurface, target, internalFormat, width, height, format, type,
                      plane);

    return re;
}
void presentRenderbuffer(EAGLContextObj ctx, NSUInteger target)
{
    Impl &impl = getImpl();

    impl.presentRenderbuffer(ctx, target);
}
void renderbufferStorage(EAGLContextObj ctx, NSUInteger target, CAEAGLLayerObj drawable)
{
    SEL selector = sel_registerName("renderbufferStorage:fromDrawable:");

    using MsgSignature = void (*)(id, SEL, NSUInteger, id);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);

    msgSend(ctx, selector, target, drawable);
}

CAEAGLLayerObj createCAEAGLLayer()
{
    Impl &impl = getImpl();

    CAEAGLLayerObj layer = [impl.classCAEAGLLayer alloc];

    if (!layer)
    {
        return nil;
    }

    SEL initSel        = sel_registerName("init");
    using MsgSignature = id (*)(id, SEL);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);
    layer              = msgSend(layer, initSel);

    return layer;
}
void setCAEAGLLayerFrame(CAEAGLLayerObj layer, const CGRect &frame)
{
    static SEL kSetFrameSel = sel_registerName("setFrame:");

    using MsgSignature = void (*)(id, SEL, CGRect);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);

    msgSend(layer, kSetFrameSel, frame);
}

void setCAEAGLContentsScale(CAEAGLLayerObj layer, const double scale)
{
    static SEL kSetContentsScaleSel = sel_registerName("setContentsScale:");

    using MsgSignature = void (*)(id, SEL, CGFloat);
    auto msgSend       = reinterpret_cast<MsgSignature>(objc_msgSend);

    msgSend(layer, kSetContentsScaleSel, static_cast<CGFloat>(scale));
}

}

#endif  // defined(ANGLE_PLATFORM_IOS)
