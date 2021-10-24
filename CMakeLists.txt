#
# Copyright (c) 2008-2019 the Urho3D project.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# 20190119 - Eli Aloni (A.K.A elix22) - initial creation
# 20211017 - Le Hoang Quyen (A.K.A kakashidinho) - GL backend & MGLKit added

set (TARGET_NAME metalangle)
set (SRC_FILES)

# Always turn on optimization
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")

add_definitions(
    -DANGLE_GENERATE_SHADER_DEBUG_INFO
    -DJSON_USE_EXCEPTION=0
)

if(APPLE)
  # Enable OpenGL backend on iOS as backup.
  if(IOS OR TVOS)
    add_definitions(
        -DANGLE_ENABLE_GLSL
        -DANGLE_ENABLE_ESSL
        -DANGLE_ENABLE_OPENGL
    )
  endif()
	add_definitions(-DANGLE_ENABLE_METAL)
	add_definitions(-DSYSCONFDIR=\"/etc\"   -DFALLBACK_CONFIG_DIRS=\"/etc/xdg\" -DFALLBACK_DATA_DIRS=\"/usr/local/share:/usr/share\")
	SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++1z -Wincompatible-pointer-types -Wargument-outside-range")
endif()

if(ANDROID)
	message(FATAL_ERROR "Unsupported for now")
endif()

if(WIN32)
	message(FATAL_ERROR "Unsupported for now")
endif()

if(__linux__)
	message(FATAL_ERROR "Unsupported for now")
endif()



set (libangle_common_sources
  src/common/Color.h
  src/common/Color.inc
  src/common/FastVector.h
  src/common/FixedVector.h
  src/common/Float16ToFloat32.cpp
  src/common/MemoryBuffer.cpp
  src/common/MemoryBuffer.h
  src/common/Optional.h
  src/common/PackedEGLEnums_autogen.cpp
  src/common/PackedEGLEnums_autogen.h
  src/common/PackedEnums.cpp
  src/common/PackedEnums.h
  src/common/PackedGLEnums_autogen.cpp
  src/common/PackedGLEnums_autogen.h
  src/common/PoolAlloc.cpp
  src/common/PoolAlloc.h
  src/common/aligned_memory.cpp
  src/common/aligned_memory.h
  src/common/android_util.cpp
  src/common/android_util.h
  src/common/angleutils.cpp
  src/common/angleutils.h
  src/common/apple_platform_utils.h
  src/common/bitset_utils.h
  src/common/debug.cpp
  src/common/debug.h
  src/common/mathutil.cpp
  src/common/mathutil.h
  src/common/matrix_utils.cpp
  src/common/matrix_utils.h
  src/common/platform.h
  src/common/string_utils.cpp
  src/common/string_utils.h
  src/common/system_utils.cpp
  src/common/system_utils.h
  src/common/third_party/base/anglebase/base_export.h
  src/common/third_party/base/anglebase/containers/mru_cache.h
  src/common/third_party/base/anglebase/logging.h
  src/common/third_party/base/anglebase/macros.h
  src/common/third_party/base/anglebase/numerics/safe_conversions.h
  src/common/third_party/base/anglebase/numerics/safe_conversions_impl.h
  src/common/third_party/base/anglebase/numerics/safe_math.h
  src/common/third_party/base/anglebase/numerics/safe_math_impl.h
  src/common/third_party/base/anglebase/sha1.cc
  src/common/third_party/base/anglebase/sha1.h
  src/common/third_party/base/anglebase/sys_byteorder.h
  src/common/third_party/smhasher/src/PMurHash.cpp
  src/common/third_party/smhasher/src/PMurHash.h
  src/common/third_party/xxhash/xxhash.h
  src/common/third_party/xxhash/xxhash.c
  src/common/tls.cpp
  src/common/tls.h
  src/common/uniform_type_info_autogen.cpp
  src/common/utilities.cpp
  src/common/utilities.h
  src/common/vector_utils.h
  src/common/version.h)

if(APPLE)
if(IOS OR TVOS)
	set (libangle_common_sources ${libangle_common_sources} src/common/system_utils_cocoa.mm)
else()
	set (libangle_common_sources ${libangle_common_sources} src/common/system_utils_mac.cpp)
	set (libangle_common_sources ${libangle_common_sources} src/common/system_utils_posix.cpp)
endif()
endif()

source_group("angle_common"            FILES ${libangle_common_sources})

list (APPEND SRC_FILES ${libangle_common_sources})

set (libangle_image_util_sources
  src/image_util/copyimage.cpp
  src/image_util/copyimage.h
  src/image_util/copyimage.inc
  src/image_util/generatemip.h
  src/image_util/generatemip.inc
  src/image_util/imageformats.cpp
  src/image_util/imageformats.h
  src/image_util/loadimage.cpp
  src/image_util/loadimage.h
  src/image_util/loadimage.inc
  src/image_util/loadimage_etc.cpp)

source_group("angle_image_util"            FILES ${libangle_image_util_sources})

list (APPEND SRC_FILES ${libangle_image_util_sources})



set (libangle_sources
  src/common/event_tracer.cpp
  src/common/event_tracer.h
  src/libANGLE/AttributeMap.cpp
  src/libANGLE/AttributeMap.h
  src/libANGLE/BinaryStream.h
  src/libANGLE/BlobCache.cpp
  src/libANGLE/BlobCache.h
  src/libANGLE/Buffer.cpp
  src/libANGLE/Buffer.h
  src/libANGLE/Caps.cpp
  src/libANGLE/Caps.h
  src/libANGLE/Compiler.cpp
  src/libANGLE/Compiler.h
  src/libANGLE/Config.cpp
  src/libANGLE/Config.h
  src/libANGLE/Constants.h
  src/libANGLE/Context.cpp
  src/libANGLE/Context_gles_1_0.cpp
  src/libANGLE/Context_gles_1_0_autogen.h
  src/libANGLE/Context.h
  src/libANGLE/Debug.cpp
  src/libANGLE/Debug.h
  src/libANGLE/Device.cpp
  src/libANGLE/Device.h
  src/libANGLE/Display.cpp
  src/libANGLE/Display.h
  src/libANGLE/EGLSync.cpp
  src/libANGLE/EGLSync.h
  src/libANGLE/Error.cpp
  src/libANGLE/Error.h
  src/libANGLE/Error.inc
  src/libANGLE/ErrorStrings.h
  src/libANGLE/Fence.cpp
  src/libANGLE/Fence.h
  src/libANGLE/format_map_desktop.cpp
  src/libANGLE/Framebuffer.cpp
  src/libANGLE/Framebuffer.h
  src/libANGLE/FramebufferAttachment.cpp
  src/libANGLE/FramebufferAttachment.h
  src/libANGLE/FrameCapture.cpp
  src/libANGLE/GLES1Renderer.cpp
  src/libANGLE/GLES1Renderer.h
  src/libANGLE/GLES1Shaders.inc
  src/libANGLE/GLES1State.cpp
  src/libANGLE/GLES1State.h
  src/libANGLE/HandleAllocator.cpp
  src/libANGLE/HandleAllocator.h
  src/libANGLE/HandleRangeAllocator.h
  src/libANGLE/HandleRangeAllocator.cpp
  src/libANGLE/Image.h
  src/libANGLE/Image.cpp
  src/libANGLE/ImageIndex.h
  src/libANGLE/ImageIndex.cpp
  src/libANGLE/IndexRangeCache.cpp
  src/libANGLE/IndexRangeCache.h
  src/libANGLE/LoggingAnnotator.cpp
  src/libANGLE/LoggingAnnotator.h
  src/libANGLE/MemoryObject.h
  src/libANGLE/MemoryObject.cpp
  src/libANGLE/MemoryProgramCache.cpp
  src/libANGLE/MemoryProgramCache.h
  src/libANGLE/Observer.cpp
  src/libANGLE/Observer.h
  src/libANGLE/Overlay.cpp
  src/libANGLE/Overlay_autogen.cpp
  src/libANGLE/Overlay_font_autogen.cpp
  src/libANGLE/OverlayWidgets.cpp
  src/libANGLE/Path.h
  src/libANGLE/Path.cpp
  src/libANGLE/Platform.cpp
  src/libANGLE/Program.cpp
  src/libANGLE/Program.h
  src/libANGLE/ProgramLinkedResources.cpp
  src/libANGLE/ProgramLinkedResources.h
  src/libANGLE/ProgramPipeline.cpp
  src/libANGLE/ProgramPipeline.h
  src/libANGLE/Query.cpp
  src/libANGLE/Query.h
  src/libANGLE/RefCountObject.h
  src/libANGLE/Renderbuffer.cpp
  src/libANGLE/Renderbuffer.h
  src/libANGLE/ResourceManager.cpp
  src/libANGLE/ResourceManager.h
  src/libANGLE/ResourceMap.h
  src/libANGLE/Sampler.cpp
  src/libANGLE/Sampler.h
  src/libANGLE/Semaphore.cpp
  src/libANGLE/Semaphore.h
  src/libANGLE/Shader.cpp
  src/libANGLE/Shader.h
  src/libANGLE/SizedMRUCache.h
  src/libANGLE/State.cpp
  src/libANGLE/State.h
  src/libANGLE/Stream.cpp
  src/libANGLE/Stream.h
  src/libANGLE/Surface.cpp
  src/libANGLE/Surface.h
  src/libANGLE/Texture.cpp
  src/libANGLE/Texture.h
  src/libANGLE/Thread.cpp
  src/libANGLE/Thread.h
  src/libANGLE/TransformFeedback.cpp
  src/libANGLE/TransformFeedback.h
  src/libANGLE/Uniform.cpp
  src/libANGLE/Uniform.h
  src/libANGLE/VaryingPacking.cpp
  src/libANGLE/VaryingPacking.h
  src/libANGLE/Version.h
  src/libANGLE/Version.inc
  src/libANGLE/VertexArray.cpp
  src/libANGLE/VertexArray.h
  src/libANGLE/VertexAttribute.cpp
  src/libANGLE/VertexAttribute.h
  src/libANGLE/VertexAttribute.inc
  src/libANGLE/WorkerThread.cpp
  src/libANGLE/WorkerThread.h
  src/libANGLE/angletypes.cpp
  src/libANGLE/angletypes.h
  src/libANGLE/angletypes.inc
  src/libANGLE/es3_copy_conversion_table_autogen.cpp
  src/libANGLE/features.h
  src/libANGLE/format_map_autogen.cpp
  src/libANGLE/formatutils.cpp
  src/libANGLE/formatutils.h
  src/libANGLE/histogram_macros.h
  src/libANGLE/queryconversions.cpp
  src/libANGLE/queryconversions.h
  src/libANGLE/queryutils.cpp
  src/libANGLE/queryutils.h
  src/libANGLE/renderer/BufferImpl.h
  src/libANGLE/renderer/CompilerImpl.h
  src/libANGLE/renderer/ContextImpl.cpp
  src/libANGLE/renderer/ContextImpl.h
  src/libANGLE/renderer/driver_utils.cpp
  src/libANGLE/renderer/driver_utils.h
  src/libANGLE/renderer/DeviceImpl.cpp
  src/libANGLE/renderer/DeviceImpl.h
  src/libANGLE/renderer/DisplayImpl.cpp
  src/libANGLE/renderer/DisplayImpl.h
  src/libANGLE/renderer/EGLImplFactory.h
  src/libANGLE/renderer/FenceNVImpl.h
  src/libANGLE/renderer/Format_table_autogen.cpp
  src/libANGLE/renderer/Format.h
  src/libANGLE/renderer/FramebufferAttachmentObjectImpl.h
  src/libANGLE/renderer/FramebufferImpl.h
    src/libANGLE/renderer/glImplFactory.h
    src/libANGLE/renderer/glslang_wrapper_utils.cpp
  src/libANGLE/renderer/ImageImpl.h
  src/libANGLE/renderer/PathImpl.h
  src/libANGLE/renderer/ProgramImpl.h
  src/libANGLE/renderer/ProgramPipelineImpl.h
  src/libANGLE/renderer/QueryImpl.cpp
  src/libANGLE/renderer/QueryImpl.h
  src/libANGLE/renderer/RenderbufferImpl.h
  src/libANGLE/renderer/RenderTargetCache.h
  src/libANGLE/renderer/SamplerImpl.h
  src/libANGLE/renderer/ShaderImpl.h
  src/libANGLE/renderer/StreamProducerImpl.h
  src/libANGLE/renderer/SurfaceImpl.cpp
  src/libANGLE/renderer/SurfaceImpl.h
  src/libANGLE/renderer/SyncImpl.h
  src/libANGLE/renderer/TextureImpl.cpp
  src/libANGLE/renderer/TextureImpl.h
  src/libANGLE/renderer/TransformFeedbackImpl.h
  src/libANGLE/renderer/VertexArrayImpl.h
  src/libANGLE/renderer/copyvertex.h
  src/libANGLE/renderer/copyvertex.inc
    src/libANGLE/renderer/glslang_wrapper_utils.h
    src/libANGLE/renderer/glslang_wrapper_utils.cpp
  src/libANGLE/renderer/load_functions_table.h
  src/libANGLE/renderer/load_functions_table_autogen.cpp
  src/libANGLE/renderer/renderer_utils.cpp
  src/libANGLE/renderer/renderer_utils.h
  src/libANGLE/renderer/ShaderImpl.cpp
  src/libANGLE/renderer/SamplerImpl.h
  src/libANGLE/validationEGL.cpp
  src/libANGLE/validationEGL.h
  src/libANGLE/validationES.cpp
  src/libANGLE/validationES.h
  src/libANGLE/validationES1.cpp
  src/libANGLE/validationES1.h
  src/libANGLE/validationES2.cpp
  src/libANGLE/validationES2.h
  src/libANGLE/validationES3.cpp
  src/libANGLE/validationES3.h
  src/libANGLE/validationES31.cpp
  src/libANGLE/validationES31.h
  src/third_party/trace_event/trace_event.h
)


source_group("libANGLE"            FILES ${libangle_sources})

list (APPEND SRC_FILES ${libangle_sources})


if(APPLE)
set(libangle_metal_sources
  src/libANGLE/renderer/metal/BufferMtl.h
  src/libANGLE/renderer/metal/BufferMtl.mm
  src/libANGLE/renderer/metal/CompilerMtl.h
  src/libANGLE/renderer/metal/CompilerMtl.mm
  src/libANGLE/renderer/metal/ContextMtl.h
  src/libANGLE/renderer/metal/ContextMtl.mm
  src/libANGLE/renderer/metal/DisplayMtl.h
  src/libANGLE/renderer/metal/DisplayMtl_api.h
  src/libANGLE/renderer/metal/DisplayMtl.mm
  src/libANGLE/renderer/metal/ImageMtl.h
  src/libANGLE/renderer/metal/ImageMtl.mm
  src/libANGLE/renderer/metal/FrameBufferMtl.h
  src/libANGLE/renderer/metal/FrameBufferMtl.mm
  src/libANGLE/renderer/metal/ProgramMtl.h
  src/libANGLE/renderer/metal/ProgramMtl.mm
  src/libANGLE/renderer/metal/QueryMtl.h
  src/libANGLE/renderer/metal/QueryMtl.mm
  src/libANGLE/renderer/metal/RenderBufferMtl.h
  src/libANGLE/renderer/metal/RenderBufferMtl.mm
  src/libANGLE/renderer/metal/RenderTargetMtl.h
  src/libANGLE/renderer/metal/RenderTargetMtl.mm
  src/libANGLE/renderer/metal/TransformFeedbackMtl.h
  src/libANGLE/renderer/metal/TransformFeedbackMtl.mm
  src/libANGLE/renderer/metal/ShaderMtl.h
  src/libANGLE/renderer/metal/ShaderMtl.mm
  src/libANGLE/renderer/metal/SamplerMtl.h
  src/libANGLE/renderer/metal/SamplerMtl.mm
  src/libANGLE/renderer/metal/SemaphoreMtl.h
  src/libANGLE/renderer/metal/SemaphoreMtl.mm
  src/libANGLE/renderer/metal/SyncMtl.h
  src/libANGLE/renderer/metal/SyncMtl.mm
  src/libANGLE/renderer/metal/SurfaceMtl.h
  src/libANGLE/renderer/metal/SurfaceMtl.mm
  src/libANGLE/renderer/metal/TextureMtl.h
  src/libANGLE/renderer/metal/TextureMtl.mm
  src/libANGLE/renderer/metal/VertexArrayMtl.h
  src/libANGLE/renderer/metal/VertexArrayMtl.mm
  src/libANGLE/renderer/metal/mtl_buffer_pool.h
  src/libANGLE/renderer/metal/mtl_buffer_pool.mm
  src/libANGLE/renderer/metal/mtl_command_buffer.h
  src/libANGLE/renderer/metal/mtl_command_buffer.mm
  src/libANGLE/renderer/metal/mtl_common.h
  src/libANGLE/renderer/metal/mtl_common.mm
  src/libANGLE/renderer/metal/mtl_format_table_autogen.mm
  src/libANGLE/renderer/metal/mtl_format_utils.h
  src/libANGLE/renderer/metal/mtl_format_utils.mm
  src/libANGLE/renderer/metal/mtl_glslang_utils.h
  src/libANGLE/renderer/metal/mtl_glslang_utils.mm
  src/libANGLE/renderer/metal/mtl_occlusion_query_pool.h
  src/libANGLE/renderer/metal/mtl_occlusion_query_pool.mm
  src/libANGLE/renderer/metal/mtl_render_utils.h
  src/libANGLE/renderer/metal/mtl_render_utils.mm
  src/libANGLE/renderer/metal/mtl_resources.h
  src/libANGLE/renderer/metal/mtl_resources.mm
  src/libANGLE/renderer/metal/mtl_state_cache.h
  src/libANGLE/renderer/metal/mtl_state_cache.mm
  src/libANGLE/renderer/metal/mtl_utils.h
  src/libANGLE/renderer/metal/mtl_utils.mm
  src/libANGLE/renderer/metal/shaders/compiled/mtl_default_shaders.inc
)

source_group("libangle-Metal"            FILES ${libangle_metal_sources})
list (APPEND SRC_FILES ${libangle_metal_sources})

endif(APPLE)

set(libangle_gl_sources
  src/libANGLE/renderer/gl/BlitGL.cpp
  src/libANGLE/renderer/gl/BlitGL.h
  src/libANGLE/renderer/gl/BufferGL.cpp
  src/libANGLE/renderer/gl/BufferGL.h
  src/libANGLE/renderer/gl/ClearMultiviewGL.cpp
  src/libANGLE/renderer/gl/ClearMultiviewGL.h
  src/libANGLE/renderer/gl/CompilerGL.cpp
  src/libANGLE/renderer/gl/CompilerGL.h
  src/libANGLE/renderer/gl/ContextGL.cpp
  src/libANGLE/renderer/gl/ContextGL.h
  src/libANGLE/renderer/gl/DispatchTableGL_autogen.cpp
  src/libANGLE/renderer/gl/DispatchTableGL_autogen.h
  src/libANGLE/renderer/gl/DisplayGL.cpp
  src/libANGLE/renderer/gl/DisplayGL.h
  src/libANGLE/renderer/gl/FenceNVGL.cpp
  src/libANGLE/renderer/gl/FenceNVGL.h
  src/libANGLE/renderer/gl/FramebufferGL.cpp
  src/libANGLE/renderer/gl/FramebufferGL.h
  src/libANGLE/renderer/gl/FunctionsGL.cpp
  src/libANGLE/renderer/gl/FunctionsGL.h
  src/libANGLE/renderer/gl/ImageGL.cpp
  src/libANGLE/renderer/gl/ImageGL.h
  src/libANGLE/renderer/gl/MemoryObjectGL.cpp
  src/libANGLE/renderer/gl/MemoryObjectGL.h
  src/libANGLE/renderer/gl/PathGL.cpp
  src/libANGLE/renderer/gl/PathGL.h
  src/libANGLE/renderer/gl/ProgramGL.cpp
  src/libANGLE/renderer/gl/ProgramGL.h
  src/libANGLE/renderer/gl/ProgramPipelineGL.cpp
  src/libANGLE/renderer/gl/ProgramPipelineGL.h
  src/libANGLE/renderer/gl/QueryGL.cpp
  src/libANGLE/renderer/gl/QueryGL.h
  src/libANGLE/renderer/gl/RenderbufferGL.cpp
  src/libANGLE/renderer/gl/RenderbufferGL.h
  src/libANGLE/renderer/gl/RendererGL.cpp
  src/libANGLE/renderer/gl/RendererGL.h
  src/libANGLE/renderer/gl/SamplerGL.cpp
  src/libANGLE/renderer/gl/SamplerGL.h
  src/libANGLE/renderer/gl/SemaphoreGL.cpp
  src/libANGLE/renderer/gl/SemaphoreGL.h
  src/libANGLE/renderer/gl/ShaderGL.cpp
  src/libANGLE/renderer/gl/ShaderGL.h
  src/libANGLE/renderer/gl/StateManagerGL.cpp
  src/libANGLE/renderer/gl/StateManagerGL.h
  src/libANGLE/renderer/gl/SurfaceGL.cpp
  src/libANGLE/renderer/gl/SurfaceGL.h
  src/libANGLE/renderer/gl/SyncGL.cpp
  src/libANGLE/renderer/gl/SyncGL.h
  src/libANGLE/renderer/gl/TextureGL.cpp
  src/libANGLE/renderer/gl/TextureGL.h
  src/libANGLE/renderer/gl/TransformFeedbackGL.cpp
  src/libANGLE/renderer/gl/TransformFeedbackGL.h
  src/libANGLE/renderer/gl/VertexArrayGL.cpp
  src/libANGLE/renderer/gl/VertexArrayGL.h
  src/libANGLE/renderer/gl/formatutilsgl.cpp
  src/libANGLE/renderer/gl/formatutilsgl.h
  src/libANGLE/renderer/gl/functionsgl_enums.h
  src/libANGLE/renderer/gl/functionsgl_typedefs.h
  src/libANGLE/renderer/gl/null_functions.cpp
  src/libANGLE/renderer/gl/null_functions.h
  src/libANGLE/renderer/gl/renderergl_utils.cpp
  src/libANGLE/renderer/gl/renderergl_utils.h
)

if(APPLE)
  if(IOS OR TVOS)
    set(libangle_gl_window_sources
      src/libANGLE/renderer/gl/eagl/ContextEAGL.cpp
      src/libANGLE/renderer/gl/eagl/ContextEAGL.h
      src/libANGLE/renderer/gl/eagl/DeviceEAGL.cpp
      src/libANGLE/renderer/gl/eagl/DeviceEAGL.h
      src/libANGLE/renderer/gl/eagl/DisplayEAGL.h
      src/libANGLE/renderer/gl/eagl/DisplayEAGL.mm
      src/libANGLE/renderer/gl/eagl/EAGLUtils.h
      src/libANGLE/renderer/gl/eagl/EAGLUtils.mm
      src/libANGLE/renderer/gl/eagl/IOSurfaceSurfaceEAGL.h
      src/libANGLE/renderer/gl/eagl/IOSurfaceSurfaceEAGL.mm
      src/libANGLE/renderer/gl/eagl/PbufferSurfaceEAGL.cpp
      src/libANGLE/renderer/gl/eagl/PbufferSurfaceEAGL.h
      src/libANGLE/renderer/gl/eagl/RendererEAGL.cpp
      src/libANGLE/renderer/gl/eagl/RendererEAGL.h
      src/libANGLE/renderer/gl/eagl/WindowSurfaceEAGL.h
      src/libANGLE/renderer/gl/eagl/WindowSurfaceEAGL.mm
    )
  else(IOS OR TVOS)
    set(libangle_gl_window_sources
      src/libANGLE/renderer/gl/cgl/ContextCGL.cpp
      src/libANGLE/renderer/gl/cgl/ContextCGL.h
      src/libANGLE/renderer/gl/cgl/DeviceCGL.cpp
      src/libANGLE/renderer/gl/cgl/DeviceCGL.h
      src/libANGLE/renderer/gl/cgl/DisplayCGL.h
      src/libANGLE/renderer/gl/cgl/DisplayCGL.mm
      src/libANGLE/renderer/gl/cgl/IOSurfaceSurfaceCGL.h
      src/libANGLE/renderer/gl/cgl/IOSurfaceSurfaceCGL.mm
      src/libANGLE/renderer/gl/cgl/PbufferSurfaceCGL.h
      src/libANGLE/renderer/gl/cgl/PbufferSurfaceCGL.mm
      src/libANGLE/renderer/gl/cgl/RendererCGL.h
      src/libANGLE/renderer/gl/cgl/RendererCGL.mm
      src/libANGLE/renderer/gl/cgl/WindowSurfaceCGL.h
      src/libANGLE/renderer/gl/cgl/WindowSurfaceCGL.mm
    )
  endif(IOS OR TVOS)
endif(APPLE)

# Only enable OpenGL on iOS (don't do that on macOS for now)
if(IOS OR TVOS)
source_group("libangle-GL"            FILES ${libangle_gl_sources})
list (APPEND SRC_FILES ${libangle_gl_sources})

source_group("libangle-GL/window"  FILES ${libangle_gl_window_sources})
list (APPEND SRC_FILES ${libangle_gl_window_sources})

foreach (FILE ${libangle_gl_sources} ${libangle_gl_window_sources})
  set_property (SOURCE ${FILE} APPEND_STRING PROPERTY COMPILE_FLAGS
                " -DANGLE_ENABLE_OPENGL_NULL")
endforeach ()

endif(IOS OR TVOS)

# disable ARC
foreach (FILE ${libangle_metal_sources} ${libangle_gl_window_sources})
  set_property (SOURCE ${FILE} APPEND_STRING PROPERTY COMPILE_FLAGS
                " -fno-objc-arc -Wno-unguarded-availability -Wno-nullability-completeness")
endforeach ()

############################### MGLKit ######################################
if(APPLE)
set(libangle_mglkit_sources
  ios/xcode/MGLKit/MGLContext+Private.h
  ios/xcode/MGLKit/MGLContext.h
  ios/xcode/MGLKit/MGLContext.mm
  ios/xcode/MGLKit/MGLDisplay.h
  ios/xcode/MGLKit/MGLDisplay.mm
  ios/xcode/MGLKit/MGLKView+Private.h
  ios/xcode/MGLKit/MGLKView.h
  ios/xcode/MGLKit/MGLKView.mm
  ios/xcode/MGLKit/MGLKViewController+Mac.mm
  ios/xcode/MGLKit/MGLKViewController+Private.h
  ios/xcode/MGLKit/MGLKViewController+iOS.mm
  ios/xcode/MGLKit/MGLKViewController.h
  ios/xcode/MGLKit/MGLKViewController.mm
  ios/xcode/MGLKit/MGLKit.h
  ios/xcode/MGLKit/MGLKitPlatform.h
  ios/xcode/MGLKit/MGLLayer+Private.h
  ios/xcode/MGLKit/MGLLayer.h
  ios/xcode/MGLKit/MGLLayer.mm
)

# These files are intended to be included only (not as source file)
set_source_files_properties(
  ios/xcode/MGLKit/MGLKViewController+Mac.mm
  ios/xcode/MGLKit/MGLKViewController+iOS.mm
  PROPERTIES HEADER_FILE_ONLY TRUE)

source_group("libangle-MGLKit"  FILES ${libangle_mglkit_sources})
list (APPEND SRC_FILES ${libangle_mglkit_sources})

# These files were written with ARC enabled in mind
foreach (FILE ${libangle_mglkit_sources})
  set_property (SOURCE ${FILE} APPEND_STRING PROPERTY COMPILE_FLAGS
                " -fobjc-arc")
endforeach ()

endif(APPLE)

#############################################################################
set(SPIRV-Cross
  third_party/spirv-cross/src/spirv_cfg.cpp
  third_party/spirv-cross/src/spirv_cfg.hpp
  third_party/spirv-cross/src/spirv_common.hpp
  third_party/spirv-cross/src/spirv_cross_parsed_ir.cpp
  third_party/spirv-cross/src/spirv_cross_parsed_ir.hpp
  third_party/spirv-cross/src/spirv_cross.cpp
  third_party/spirv-cross/src/spirv_cross.hpp
  third_party/spirv-cross/src/spirv_glsl.cpp
  third_party/spirv-cross/src/spirv_glsl.hpp
  third_party/spirv-cross/src/spirv_msl.cpp
  third_party/spirv-cross/src/spirv_msl.hpp
  third_party/spirv-cross/src/spirv_parser.cpp
  third_party/spirv-cross/src/spirv_parser.hpp
  third_party/spirv-cross/src/spirv_reflect.cpp
  third_party/spirv-cross/src/spirv_reflect.hpp
)

source_group("SPIRV-Cross"            FILES ${SPIRV-Cross})
list (APPEND SRC_FILES ${SPIRV-Cross})



set (libglesv2_sources
  src/common/angleutils.h
  src/common/debug.h
  src/libGLESv2/entry_points_egl.cpp
  src/libGLESv2/entry_points_egl.h
  src/libGLESv2/entry_points_egl_ext.cpp
  src/libGLESv2/entry_points_egl_ext.h
  src/libGLESv2/entry_points_gles_1_0_autogen.cpp
  src/libGLESv2/entry_points_gles_1_0_autogen.h
  src/libGLESv2/entry_points_gles_2_0_autogen.cpp
  src/libGLESv2/entry_points_gles_2_0_autogen.h
  src/libGLESv2/entry_points_gles_3_0_autogen.cpp
  src/libGLESv2/entry_points_gles_3_0_autogen.h
  src/libGLESv2/entry_points_gles_3_1_autogen.cpp
  src/libGLESv2/entry_points_gles_3_1_autogen.h
  src/libGLESv2/entry_points_gles_ext_autogen.cpp
  src/libGLESv2/entry_points_gles_ext_autogen.h
  src/libGLESv2/global_state.cpp
  src/libGLESv2/global_state.h
  src/libGLESv2/libGLESv2_autogen.cpp
  src/libGLESv2/libGLESv2.rc
  src/libGLESv2/proc_table_egl.h
  src/libGLESv2/proc_table_egl_autogen.cpp
  src/libGLESv2/resource.h
)
source_group("libGLESv2"            FILES ${libglesv2_sources})
list (APPEND SRC_FILES ${libglesv2_sources})




set (libegl_sources
  src/libEGL/libEGL.cpp
  src/libEGL/resource.h
)
source_group("libEGL"            FILES ${libegl_sources})
list (APPEND SRC_FILES ${libegl_sources})



set (angle_translator_sources
  include/EGL/egl.h
  include/EGL/eglext.h
  include/EGL/eglplatform.h
  include/GLES2/gl2.h
  include/GLES2/gl2ext.h
  include/GLES2/gl2platform.h
  include/GLES3/gl3.h
  include/GLES3/gl3platform.h
  include/GLES3/gl31.h
  include/GLES3/gl32.h
  include/GLSLANG/ShaderLang.h
  include/GLSLANG/ShaderVars.h
  include/KHR/khrplatform.h
  include/angle_gl.h
  src/compiler/translator/BaseTypes.h
  src/compiler/translator/BuiltInFunctionEmulator.cpp
  src/compiler/translator/BuiltInFunctionEmulator.h
  src/compiler/translator/BuiltinsWorkaroundGLSL.cpp
  src/compiler/translator/CallDAG.cpp
  src/compiler/translator/CallDAG.h
  src/compiler/translator/CodeGen.cpp
  src/compiler/translator/CollectVariables.cpp
  src/compiler/translator/CollectVariables.h
  src/compiler/translator/Common.h
  src/compiler/translator/Compiler.cpp
  src/compiler/translator/Compiler.h
  src/compiler/translator/ConstantUnion.cpp
  src/compiler/translator/ConstantUnion.h
  src/compiler/translator/Declarator.cpp
  src/compiler/translator/Declarator.h
  src/compiler/translator/Diagnostics.cpp
  src/compiler/translator/Diagnostics.h
  src/compiler/translator/DirectiveHandler.cpp
  src/compiler/translator/DirectiveHandler.h
  src/compiler/translator/ExtensionBehavior.cpp
  src/compiler/translator/ExtensionBehavior.h
  src/compiler/translator/FlagStd140Structs.cpp
  src/compiler/translator/FlagStd140Structs.h
  src/compiler/translator/FunctionLookup.cpp
  src/compiler/translator/FunctionLookup.h
  src/compiler/translator/HashNames.cpp
  src/compiler/translator/HashNames.h
  src/compiler/translator/ImmutableString.h
  src/compiler/translator/ImmutableString_autogen.cpp
  src/compiler/translator/ImmutableStringBuilder.cpp
  src/compiler/translator/ImmutableStringBuilder.h
  src/compiler/translator/InfoSink.cpp
  src/compiler/translator/InfoSink.h
  src/compiler/translator/Initialize.cpp
  src/compiler/translator/Initialize.h
  src/compiler/translator/InitializeDll.cpp
  src/compiler/translator/InitializeDll.h
  src/compiler/translator/InitializeGlobals.h
  src/compiler/translator/IntermNode.h
  src/compiler/translator/IntermNode.cpp
  src/compiler/translator/IsASTDepthBelowLimit.cpp
  src/compiler/translator/IsASTDepthBelowLimit.h
  src/compiler/translator/Operator.cpp
  src/compiler/translator/Operator.h
  src/compiler/translator/OutputTree.cpp
  src/compiler/translator/OutputTree.h
  src/compiler/translator/ParseContext.cpp
  src/compiler/translator/ParseContext.h
  src/compiler/translator/PoolAlloc.cpp
  src/compiler/translator/PoolAlloc.h
  src/compiler/translator/Pragma.h
  src/compiler/translator/QualifierTypes.h
  src/compiler/translator/QualifierTypes.cpp
  src/compiler/translator/Severity.h
  src/compiler/translator/ShaderLang.cpp
  src/compiler/translator/ShaderVars.cpp
  src/compiler/translator/StaticType.h
  src/compiler/translator/Symbol.cpp
  src/compiler/translator/Symbol.h
  src/compiler/translator/SymbolTable.cpp
  src/compiler/translator/SymbolTable.h
  src/compiler/translator/SymbolTable_autogen.cpp
  src/compiler/translator/SymbolTable_autogen.h
  src/compiler/translator/SymbolUniqueId.cpp
  src/compiler/translator/SymbolUniqueId.h
  src/compiler/translator/Types.cpp
  src/compiler/translator/Types.h
  src/compiler/translator/ValidateGlobalInitializer.cpp
  src/compiler/translator/ValidateGlobalInitializer.h
  src/compiler/translator/ValidateLimitations.cpp
  src/compiler/translator/ValidateLimitations.h
  src/compiler/translator/ValidateMaxParameters.h
  src/compiler/translator/ValidateMaxParameters.cpp
  src/compiler/translator/ValidateOutputs.cpp
  src/compiler/translator/ValidateOutputs.h
  src/compiler/translator/ValidateSwitch.cpp
  src/compiler/translator/ValidateSwitch.h
  src/compiler/translator/ValidateVaryingLocations.cpp
  src/compiler/translator/ValidateVaryingLocations.h
  src/compiler/translator/VariablePacker.cpp
  src/compiler/translator/VariablePacker.h
  src/compiler/translator/blocklayout.cpp
  src/compiler/translator/blocklayout.h
  src/compiler/translator/glslang.h
  src/compiler/translator/glslang.l
  src/compiler/translator/glslang.y
  src/compiler/translator/glslang_lex.cpp
  src/compiler/translator/glslang_tab.cpp
  src/compiler/translator/glslang_tab.h
  src/compiler/translator/length_limits.h
  src/compiler/translator/util.cpp
  src/compiler/translator/util.h
  src/compiler/translator/tree_ops/AddAndTrueToLoopCondition.cpp
  src/compiler/translator/tree_ops/AddAndTrueToLoopCondition.h
  src/compiler/translator/tree_ops/BreakVariableAliasingInInnerLoops.cpp
  src/compiler/translator/tree_ops/BreakVariableAliasingInInnerLoops.h
  src/compiler/translator/tree_ops/ClampFragDepth.cpp
  src/compiler/translator/tree_ops/ClampFragDepth.h
  src/compiler/translator/tree_ops/ClampPointSize.cpp
  src/compiler/translator/tree_ops/ClampPointSize.h
  src/compiler/translator/tree_ops/DeclareAndInitBuiltinsForInstancedMultiview.h
  src/compiler/translator/tree_ops/DeclareAndInitBuiltinsForInstancedMultiview.cpp
  src/compiler/translator/tree_ops/DeferGlobalInitializers.cpp
  src/compiler/translator/tree_ops/DeferGlobalInitializers.h
  src/compiler/translator/tree_ops/EmulateGLFragColorBroadcast.cpp
  src/compiler/translator/tree_ops/EmulateGLFragColorBroadcast.h
  src/compiler/translator/tree_ops/EmulateMultiDrawShaderBuiltins.cpp
  src/compiler/translator/tree_ops/EmulateMultiDrawShaderBuiltins.h
  src/compiler/translator/tree_ops/EmulatePrecision.cpp
  src/compiler/translator/tree_ops/EmulatePrecision.h
  src/compiler/translator/tree_ops/ExpandIntegerPowExpressions.cpp
  src/compiler/translator/tree_ops/ExpandIntegerPowExpressions.h
  src/compiler/translator/tree_ops/FoldExpressions.cpp
  src/compiler/translator/tree_ops/FoldExpressions.h
  src/compiler/translator/tree_ops/InitializeVariables.cpp
  src/compiler/translator/tree_ops/InitializeVariables.h
  src/compiler/translator/tree_ops/NameEmbeddedUniformStructs.cpp
  src/compiler/translator/tree_ops/NameEmbeddedUniformStructs.h
  src/compiler/translator/tree_ops/NameNamelessUniformBuffers.cpp
  src/compiler/translator/tree_ops/PruneEmptyCases.cpp
  src/compiler/translator/tree_ops/PruneEmptyCases.h
  src/compiler/translator/tree_ops/PruneNoOps.cpp
  src/compiler/translator/tree_ops/PruneNoOps.h
  src/compiler/translator/tree_ops/RecordConstantPrecision.cpp
  src/compiler/translator/tree_ops/RecordConstantPrecision.h
  src/compiler/translator/tree_ops/RegenerateStructNames.cpp
  src/compiler/translator/tree_ops/RegenerateStructNames.h
  src/compiler/translator/tree_ops/RemoveArrayLengthMethod.cpp
  src/compiler/translator/tree_ops/RemoveArrayLengthMethod.h
  src/compiler/translator/tree_ops/RemoveInvariantDeclaration.cpp
  src/compiler/translator/tree_ops/RemoveInvariantDeclaration.h
  src/compiler/translator/tree_ops/RemovePow.cpp
  src/compiler/translator/tree_ops/RemovePow.h
  src/compiler/translator/tree_ops/RemoveUnreferencedVariables.cpp
  src/compiler/translator/tree_ops/RemoveUnreferencedVariables.h
  src/compiler/translator/tree_ops/RewriteAtomicFunctionExpressions.cpp
  src/compiler/translator/tree_ops/RewriteAtomicFunctionExpressions.h
  src/compiler/translator/tree_ops/RewriteCubeMapSamplersAs2DArray.cpp
  src/compiler/translator/tree_ops/RewriteDfdy.cpp
  src/compiler/translator/tree_ops/RewriteDfdy.h
  src/compiler/translator/tree_ops/RewriteDoWhile.cpp
  src/compiler/translator/tree_ops/RewriteDoWhile.h
  src/compiler/translator/tree_ops/RewriteRowMajorMatrices.cpp
  src/compiler/translator/tree_ops/RewriteStructSamplers.cpp
  src/compiler/translator/tree_ops/RewriteStructSamplers.h
  src/compiler/translator/tree_ops/RewriteRepeatedAssignToSwizzled.cpp
  src/compiler/translator/tree_ops/RewriteRepeatedAssignToSwizzled.h
  src/compiler/translator/tree_ops/RewriteTexelFetchOffset.cpp
  src/compiler/translator/tree_ops/RewriteTexelFetchOffset.h
  src/compiler/translator/tree_ops/RewriteUnaryMinusOperatorFloat.cpp
  src/compiler/translator/tree_ops/RewriteUnaryMinusOperatorFloat.h
  src/compiler/translator/tree_ops/RewriteUnaryMinusOperatorInt.cpp
  src/compiler/translator/tree_ops/RewriteUnaryMinusOperatorInt.h
  src/compiler/translator/tree_ops/ScalarizeVecAndMatConstructorArgs.cpp
  src/compiler/translator/tree_ops/ScalarizeVecAndMatConstructorArgs.h
  src/compiler/translator/tree_ops/SeparateDeclarations.cpp
  src/compiler/translator/tree_ops/SeparateDeclarations.h
  src/compiler/translator/tree_ops/SimplifyLoopConditions.cpp
  src/compiler/translator/tree_ops/SimplifyLoopConditions.h
  src/compiler/translator/tree_ops/SplitSequenceOperator.cpp
  src/compiler/translator/tree_ops/SplitSequenceOperator.h
  src/compiler/translator/tree_ops/UnfoldShortCircuitAST.cpp
  src/compiler/translator/tree_ops/UnfoldShortCircuitAST.h
  src/compiler/translator/tree_ops/UseInterfaceBlockFields.cpp
  src/compiler/translator/tree_ops/UseInterfaceBlockFields.h
  src/compiler/translator/tree_ops/VectorizeVectorScalarArithmetic.cpp
  src/compiler/translator/tree_ops/VectorizeVectorScalarArithmetic.h
  src/compiler/translator/tree_util/FindFunction.cpp
  src/compiler/translator/tree_util/FindFunction.h
  src/compiler/translator/tree_util/FindMain.cpp
  src/compiler/translator/tree_util/FindMain.h
  src/compiler/translator/tree_util/FindSymbolNode.cpp
  src/compiler/translator/tree_util/FindSymbolNode.h
  src/compiler/translator/tree_util/ReplaceClipDistanceVariable.cpp
  src/compiler/translator/tree_util/ReplaceClipDistanceVariable.h
  src/compiler/translator/tree_util/IntermNodePatternMatcher.cpp
  src/compiler/translator/tree_util/IntermNodePatternMatcher.h
  src/compiler/translator/tree_util/IntermNode_util.cpp
  src/compiler/translator/tree_util/IntermNode_util.h
  src/compiler/translator/tree_util/IntermTraverse.cpp
  src/compiler/translator/tree_util/IntermTraverse.h
  src/compiler/translator/tree_util/NodeSearch.h
  src/compiler/translator/tree_util/ReplaceShadowingVariables.cpp
  src/compiler/translator/tree_util/ReplaceVariable.cpp
  src/compiler/translator/tree_util/ReplaceVariable.h
  src/compiler/translator/tree_util/RunAtTheEndOfShader.cpp
  src/compiler/translator/tree_util/RunAtTheEndOfShader.h
  src/compiler/translator/tree_util/Visit.h
  src/third_party/compiler/ArrayBoundsClamper.cpp
  src/third_party/compiler/ArrayBoundsClamper.h
  src/compiler/translator/OutputESSL.cpp
  src/compiler/translator/OutputESSL.h
  src/compiler/translator/TranslatorESSL.cpp
  src/compiler/translator/TranslatorESSL.h
  src/compiler/translator/BuiltInFunctionEmulatorGLSL.cpp
  src/compiler/translator/BuiltInFunctionEmulatorGLSL.h
  src/compiler/translator/ExtensionGLSL.cpp
  src/compiler/translator/ExtensionGLSL.h
  src/compiler/translator/OutputGLSL.cpp
  src/compiler/translator/OutputGLSL.h
  src/compiler/translator/OutputGLSLBase.cpp
  src/compiler/translator/OutputGLSLBase.h
  src/compiler/translator/TranslatorGLSL.cpp
  src/compiler/translator/TranslatorGLSL.h
  src/compiler/translator/VersionGLSL.cpp
  src/compiler/translator/VersionGLSL.h
  src/compiler/translator/tree_ops/AddDefaultReturnStatements.cpp
  src/compiler/translator/tree_ops/AddDefaultReturnStatements.h
  src/compiler/translator/tree_ops/ArrayReturnValueToOutParameter.cpp
  src/compiler/translator/tree_ops/ArrayReturnValueToOutParameter.h
  src/compiler/translator/tree_ops/RemoveDynamicIndexing.cpp
  src/compiler/translator/tree_ops/RemoveDynamicIndexing.h
  src/compiler/translator/tree_ops/RemoveSwitchFallThrough.cpp
  src/compiler/translator/tree_ops/RemoveSwitchFallThrough.h
  src/compiler/translator/tree_ops/RewriteAtomicCounters.cpp
  src/compiler/translator/tree_ops/RewriteElseBlocks.cpp
  src/compiler/translator/tree_ops/RewriteElseBlocks.h
  src/compiler/translator/tree_ops/RewriteStructSamplersOld.cpp
  src/compiler/translator/tree_ops/SeparateArrayConstructorStatements.cpp
  src/compiler/translator/tree_ops/SeparateArrayConstructorStatements.h
  src/compiler/translator/tree_ops/SeparateArrayInitialization.cpp
  src/compiler/translator/tree_ops/SeparateArrayInitialization.h
  src/compiler/translator/tree_ops/SeparateExpressionsReturningArrays.cpp
  src/compiler/translator/tree_ops/SeparateExpressionsReturningArrays.h
  src/compiler/translator/tree_ops/UnfoldShortCircuitToIf.cpp
  src/compiler/translator/tree_ops/UnfoldShortCircuitToIf.h
  src/compiler/translator/tree_ops/WrapSwitchStatementsInBlocks.cpp
  src/compiler/translator/tree_ops/WrapSwitchStatementsInBlocks.h
  src/compiler/translator/OutputVulkanGLSL.cpp
  src/compiler/translator/OutputVulkanGLSL.h
  src/compiler/translator/TranslatorVulkan.cpp
  src/compiler/translator/TranslatorVulkan.h
  src/compiler/translator/TranslatorMetal.mm
  src/compiler/translator/ValidateAST.cpp
  src/compiler/translator/ValidateAST.h
  src/compiler/fuzz/translator_fuzzer.cpp
)
source_group("translator"            FILES ${angle_translator_sources})
list (APPEND SRC_FILES ${angle_translator_sources})


set (angle_preprocessor_sources
  src/compiler/preprocessor/DiagnosticsBase.cpp
  src/compiler/preprocessor/DiagnosticsBase.h
  src/compiler/preprocessor/DirectiveHandlerBase.cpp
  src/compiler/preprocessor/DirectiveHandlerBase.h
  src/compiler/preprocessor/DirectiveParser.cpp
  src/compiler/preprocessor/DirectiveParser.h
  src/compiler/preprocessor/ExpressionParser.cpp
  src/compiler/preprocessor/ExpressionParser.h
  src/compiler/preprocessor/ExpressionParser.y
  src/compiler/preprocessor/Input.cpp
  src/compiler/preprocessor/Input.h
  src/compiler/preprocessor/Lexer.cpp
  src/compiler/preprocessor/Lexer.h
  src/compiler/preprocessor/Macro.cpp
  src/compiler/preprocessor/Macro.h
  src/compiler/preprocessor/MacroExpander.cpp
  src/compiler/preprocessor/MacroExpander.h
  src/compiler/preprocessor/Preprocessor.cpp
  src/compiler/preprocessor/Preprocessor.h
  src/compiler/preprocessor/SourceLocation.h
  src/compiler/preprocessor/Token.cpp
  src/compiler/preprocessor/Token.h
  src/compiler/preprocessor/Tokenizer.cpp
  src/compiler/preprocessor/Tokenizer.h
  src/compiler/preprocessor/Tokenizer.l
  src/compiler/preprocessor/numeric_lex.h
)
source_group("preprocessor"            FILES ${angle_preprocessor_sources})
list (APPEND SRC_FILES ${angle_preprocessor_sources})



set(glslang
    third_party/glslang/src/OGLCompilersDLL/InitializeDll.cpp
    third_party/glslang/src/OGLCompilersDLL/InitializeDll.h
    third_party/glslang/src/SPIRV/GLSL.ext.KHR.h
    third_party/glslang/src/SPIRV/GLSL.std.450.h
    third_party/glslang/src/SPIRV/GlslangToSpv.cpp
    third_party/glslang/src/SPIRV/GlslangToSpv.h
    third_party/glslang/src/SPIRV/InReadableOrder.cpp
    third_party/glslang/src/SPIRV/Logger.cpp
    third_party/glslang/src/SPIRV/Logger.h
    third_party/glslang/src/SPIRV/SpvBuilder.cpp
    third_party/glslang/src/SPIRV/SpvBuilder.h
    third_party/glslang/src/SPIRV/SpvPostProcess.cpp
    third_party/glslang/src/SPIRV/bitutils.h
    third_party/glslang/src/SPIRV/disassemble.cpp
    third_party/glslang/src/SPIRV/disassemble.h
    third_party/glslang/src/SPIRV/doc.cpp
    third_party/glslang/src/SPIRV/doc.h
    third_party/glslang/src/SPIRV/hex_float.h
    third_party/glslang/src/SPIRV/spirv.hpp
    third_party/glslang/src/SPIRV/spvIR.h
    third_party/glslang/src/StandAlone/ResourceLimits.cpp
    third_party/glslang/src/StandAlone/ResourceLimits.h
    third_party/glslang/src/glslang/GenericCodeGen/CodeGen.cpp
    third_party/glslang/src/glslang/GenericCodeGen/Link.cpp
    third_party/glslang/src/glslang/Include/BaseTypes.h
    third_party/glslang/src/glslang/Include/Common.h
    third_party/glslang/src/glslang/Include/ConstantUnion.h
    third_party/glslang/src/glslang/Include/InfoSink.h
    third_party/glslang/src/glslang/Include/InitializeGlobals.h
    third_party/glslang/src/glslang/Include/PoolAlloc.h
    third_party/glslang/src/glslang/Include/ResourceLimits.h
    third_party/glslang/src/glslang/Include/ShHandle.h
    third_party/glslang/src/glslang/Include/Types.h
    third_party/glslang/src/glslang/Include/arrays.h
    third_party/glslang/src/glslang/Include/intermediate.h
    third_party/glslang/src/glslang/Include/revision.h
    third_party/glslang/src/glslang/MachineIndependent/Constant.cpp
    third_party/glslang/src/glslang/MachineIndependent/InfoSink.cpp
    third_party/glslang/src/glslang/MachineIndependent/Initialize.cpp
    third_party/glslang/src/glslang/MachineIndependent/Initialize.h
    third_party/glslang/src/glslang/MachineIndependent/IntermTraverse.cpp
    third_party/glslang/src/glslang/MachineIndependent/Intermediate.cpp
    third_party/glslang/src/glslang/MachineIndependent/LiveTraverser.h
    third_party/glslang/src/glslang/MachineIndependent/ParseContextBase.cpp
    third_party/glslang/src/glslang/MachineIndependent/ParseHelper.cpp
    third_party/glslang/src/glslang/MachineIndependent/ParseHelper.h
    third_party/glslang/src/glslang/MachineIndependent/PoolAlloc.cpp
    third_party/glslang/src/glslang/MachineIndependent/RemoveTree.cpp
    third_party/glslang/src/glslang/MachineIndependent/RemoveTree.h
    third_party/glslang/src/glslang/MachineIndependent/Scan.cpp
    third_party/glslang/src/glslang/MachineIndependent/Scan.h
    third_party/glslang/src/glslang/MachineIndependent/ScanContext.h
    third_party/glslang/src/glslang/MachineIndependent/ShaderLang.cpp
    third_party/glslang/src/glslang/MachineIndependent/SymbolTable.cpp
    third_party/glslang/src/glslang/MachineIndependent/SymbolTable.h
    third_party/glslang/src/glslang/MachineIndependent/Versions.cpp
    third_party/glslang/src/glslang/MachineIndependent/Versions.h
    third_party/glslang/src/glslang/MachineIndependent/attribute.cpp
    third_party/glslang/src/glslang/MachineIndependent/gl_types.h
    third_party/glslang/src/glslang/MachineIndependent/glslang_tab.cpp
    third_party/glslang/src/glslang/MachineIndependent/glslang_tab.cpp.h
    third_party/glslang/src/glslang/MachineIndependent/intermOut.cpp
    third_party/glslang/src/glslang/MachineIndependent/iomapper.cpp
    third_party/glslang/src/glslang/MachineIndependent/iomapper.h
    third_party/glslang/src/glslang/MachineIndependent/limits.cpp
    third_party/glslang/src/glslang/MachineIndependent/linkValidate.cpp
    third_party/glslang/src/glslang/MachineIndependent/localintermediate.h
    third_party/glslang/src/glslang/MachineIndependent/parseConst.cpp
    third_party/glslang/src/glslang/MachineIndependent/parseVersions.h
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/Pp.cpp
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpAtom.cpp
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpContext.cpp
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpContext.h
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpScanner.cpp
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpTokens.cpp
    third_party/glslang/src/glslang/MachineIndependent/preprocessor/PpTokens.h
    third_party/glslang/src/glslang/MachineIndependent/propagateNoContraction.cpp
    third_party/glslang/src/glslang/MachineIndependent/propagateNoContraction.h
    third_party/glslang/src/glslang/MachineIndependent/reflection.cpp
    third_party/glslang/src/glslang/MachineIndependent/reflection.h
    third_party/glslang/src/glslang/OSDependent/osinclude.h
    third_party/glslang/src/glslang/Public/ShaderLang.h
	)

if (WIN32)
	set (glslang ${glslang} third_party/glslang/src/glslang/OSDependent/Windows/ossource.cpp)
else()
	set (glslang ${glslang} third_party/glslang/src/glslang/OSDependent/Unix/ossource.cpp)
endif()

source_group("glslang"            FILES ${glslang})
list (APPEND SRC_FILES ${glslang})

# Auto generated files
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/angle-gen/id/commit.h
  COMMAND
    python ${CMAKE_CURRENT_SOURCE_DIR}/src/commit_id.py
    gen
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}/angle-gen/id/commit.h
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/.git/index
)

add_custom_target(libangle-autogen
  DEPENDS
  ${CMAKE_CURRENT_BINARY_DIR}/angle-gen/id/commit.h)

include_directories(
  ${CMAKE_CURRENT_BINARY_DIR}/angle-gen
)

# Setup target
add_library(${TARGET_NAME} STATIC ${SRC_FILES})

target_include_directories(${TARGET_NAME}
  PUBLIC
  include
  ios/xcode
)

target_include_directories(${TARGET_NAME}
  PRIVATE
  src
  src/common/third_party/base
  third_party/glslang/src
  third_party/spirv-tools/src
  third_party/spirv-tools/src/include
  third_party/spirv-headers/src/include
  third_party/spirv-cross/src
)

add_dependencies(${TARGET_NAME} libangle-autogen)
