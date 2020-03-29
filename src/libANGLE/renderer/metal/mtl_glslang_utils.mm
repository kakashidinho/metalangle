//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangUtils: Wrapper for Khronos's glslang compiler.
//

#include "libANGLE/renderer/metal/mtl_glslang_utils.h"

#include <regex>

#include <spirv_msl.hpp>

#include "common/apple_platform_utils.h"
#include "compiler/translator/TranslatorMetal.h"
#include "libANGLE/renderer/glslang_wrapper_utils.h"

namespace rx
{
namespace mtl
{
namespace
{

constexpr uint32_t kMaxUBODiscreteBindingSlots = kMaxShaderBuffers - kUBOArgumentBufferBindingIndex;

constexpr uint32_t kGlslangTextureDescSet        = 0;
constexpr uint32_t kGlslangDefaultUniformDescSet = 1;
constexpr uint32_t kGlslangDriverUniformsDescSet = 2;
constexpr uint32_t kGlslangShaderResourceDescSet = 3;

constexpr char kShadowSamplerCompareModesVarName[] = "ANGLEShadowCompareModes";

angle::Result HandleError(ErrorHandler *context, GlslangError)
{
    ANGLE_MTL_TRY(context, false);
    return angle::Result::Stop;
}

GlslangSourceOptions CreateSourceOptions()
{
    GlslangSourceOptions options;
    // These are binding options passed to glslang. The actual binding might be changed later
    // by spirv-cross.
    options.uniformsAndXfbDescriptorSetIndex = kGlslangDefaultUniformDescSet;
    options.textureDescriptorSetIndex        = kGlslangTextureDescSet;
    options.driverUniformsDescriptorSetIndex = kGlslangDriverUniformsDescSet;
    options.shaderResourceDescriptorSetIndex = kGlslangShaderResourceDescSet;
    // NOTE(hqle): Unused for now, until we support XFB
    options.xfbBindingIndexStart = 1;

    static_assert(kDefaultUniformsBindingIndex != 0, "kDefaultUniformsBindingIndex must not be 0");
    static_assert(kDriverUniformsBindingIndex != 0, "kDriverUniformsBindingIndex must not be 0");

    return options;
}

spv::ExecutionModel ShaderTypeToSpvExecutionModel(gl::ShaderType shaderType)
{
    switch (shaderType)
    {
        case gl::ShaderType::Vertex:
            return spv::ExecutionModelVertex;
        case gl::ShaderType::Fragment:
            return spv::ExecutionModelFragment;
        default:
            UNREACHABLE();
            return spv::ExecutionModelMax;
    }
}

void BindBuffers(spirv_cross::CompilerMSL *compiler,
                 const spirv_cross::SmallVector<spirv_cross::Resource> &resources,
                 gl::ShaderType shaderType,
                 bool *argumentBufferUsed)
{
    auto &compilerMsl = *compiler;

    uint32_t totalUniformBufferSlots = 0;
    std::vector<spirv_cross::MSLResourceBinding> uniformBufferBindings;

    for (const spirv_cross::Resource &resource : resources)
    {
        spirv_cross::MSLResourceBinding resBinding;
        resBinding.stage = ShaderTypeToSpvExecutionModel(shaderType);

        if (compilerMsl.has_decoration(resource.id, spv::DecorationDescriptorSet))
        {
            resBinding.desc_set =
                compilerMsl.get_decoration(resource.id, spv::DecorationDescriptorSet);
        }

        if (!compilerMsl.has_decoration(resource.id, spv::DecorationBinding))
        {
            continue;
        }

        resBinding.binding = compilerMsl.get_decoration(resource.id, spv::DecorationBinding);

        uint32_t bindingPoint = 0;
        // NOTE(hqle): We use separate discrete binding point for now, in future, we should use
        // one argument buffer for each descriptor set.
        switch (resBinding.desc_set)
        {
            case kGlslangTextureDescSet:
                // Texture binding point is ignored. We let spirv-cross automatically assign it and
                // retrieve it later
                continue;
            case kGlslangDriverUniformsDescSet:
                bindingPoint = mtl::kDriverUniformsBindingIndex;
                break;
            case kGlslangDefaultUniformDescSet:
                // NOTE(hqle): Properly handle transform feedbacks binding.
                if (shaderType != gl::ShaderType::Vertex || resBinding.binding == 0)
                {
                    bindingPoint = mtl::kDefaultUniformsBindingIndex;
                }
                else
                {
                    continue;
                }
                break;
            case kGlslangShaderResourceDescSet:
            {
                const spirv_cross::SPIRType &type = compilerMsl.get_type_from_variable(resource.id);
                if (!type.array.empty())
                {
                    totalUniformBufferSlots += type.array[0];
                }
                else
                {
                    totalUniformBufferSlots++;
                }
                uniformBufferBindings.push_back(resBinding);
            }
                continue;
            default:
                // We don't support this descriptor set.
                continue;
        }

        resBinding.msl_buffer = bindingPoint;

        compilerMsl.add_msl_resource_binding(resBinding);
    }

    if (totalUniformBufferSlots > kMaxUBODiscreteBindingSlots)
    {
        // If shader more than kMaxUBODiscreteBindingSlots number of UBOs, encoder them all into an
        // argument buffer.
        *argumentBufferUsed = true;
        for (spirv_cross::MSLResourceBinding &resBinding : uniformBufferBindings)
        {
            // Translate to metal [[id(n)]]
            resBinding.msl_buffer = resBinding.binding;

            compilerMsl.add_msl_resource_binding(resBinding);
        }
    }
    else
    {
        *argumentBufferUsed = false;
        // Use discrete buffer binding slot for UBOs
        for (spirv_cross::MSLResourceBinding &resBinding : uniformBufferBindings)
        {
            // Translate to metal [[buffer(n)]]
            resBinding.msl_buffer = kUBOArgumentBufferBindingIndex + resBinding.binding;

            compilerMsl.add_msl_resource_binding(resBinding);
        }
    }
}

angle::Result GetAssignedSamplerBindings(
    const spirv_cross::CompilerMSL &compilerMsl,
    std::array<SamplerBinding, mtl::kMaxShaderSamplers> *bindings)
{
    for (const spirv_cross::Resource &resource : compilerMsl.get_shader_resources().sampled_images)
    {
        uint32_t descriptorSet = 0;
        if (compilerMsl.has_decoration(resource.id, spv::DecorationDescriptorSet))
        {
            descriptorSet = compilerMsl.get_decoration(resource.id, spv::DecorationDescriptorSet);
        }

        // We already assigned descriptor set 0 to textures. Just to double check.
        ASSERT(descriptorSet == kGlslangTextureDescSet);
        ASSERT(compilerMsl.has_decoration(resource.id, spv::DecorationBinding));

        uint32_t binding = compilerMsl.get_decoration(resource.id, spv::DecorationBinding);

        SamplerBinding &actualBinding = bindings->at(binding);
        actualBinding.textureBinding  = compilerMsl.get_automatic_msl_resource_binding(resource.id);
        actualBinding.samplerBinding =
            compilerMsl.get_automatic_msl_resource_binding_secondary(resource.id);
    }
    return angle::Result::Continue;
}

std::string PostProcessTranslatedMsl(bool hasDepthSampler, const std::string &translatedSource)
{
    std::string source;
    if (hasDepthSampler)
    {
        // Add ANGLEShadowCompareModes variable to main(), We need to add here because it is the
        // only way without modifying spirv-cross.
        std::regex mainDeclareRegex(
            R"(((vertex|fragment|kernel)\s+[_a-zA-Z0-9<>]+\s+main[^\(]*\())");
        std::string mainDeclareReplaceStr = std::string("$1constant uniform<uint> *") +
                                            kShadowSamplerCompareModesVarName + "[[buffer(" +
                                            Str(kShadowSamplerCompareModesBindingIndex) + ")]], ";
        source = std::regex_replace(translatedSource, mainDeclareRegex, mainDeclareReplaceStr);
    }
    else
    {
        source = translatedSource;
    }

    // Add function_constant attribute to gl_SampleMask.
    // Even though this varying is only used when ANGLECoverageMaskEnabled is true,
    // the spirv-cross doesn't assign function_constant attribute to it. Thus it won't be dead-code
    // removed when ANGLECoverageMaskEnabled=false.
    std::string sampleMaskReplaceStr = std::string("[[sample_mask, function_constant(") +
                                       sh::TranslatorMetal::GetCoverageMaskEnabledConstName() +
                                       ")]]";

    // This replaces "gl_SampleMask [[sample_mask]]"
    //          with "gl_SampleMask [[sample_mask, function_constant(ANGLECoverageMaskEnabled)]]"
    std::regex sampleMaskDeclareRegex(R"(\[\s*\[\s*sample_mask\s*\]\s*\])");
    return std::regex_replace(source, sampleMaskDeclareRegex, sampleMaskReplaceStr);
}

// Customized spirv-cross compiler
class SpirvToMslCompiler : public spirv_cross::CompilerMSL
{
  public:
    SpirvToMslCompiler(std::vector<uint32_t> &&spriv) : spirv_cross::CompilerMSL(spriv) {}

    std::string compileEx(gl::ShaderType shaderType, bool *hasArgumentBufferOut)
    {
        spirv_cross::CompilerMSL::Options compOpt;

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
        compOpt.platform = spirv_cross::CompilerMSL::Options::macOS;
#else
        compOpt.platform = spirv_cross::CompilerMSL::Options::iOS;
#endif

        if (ANGLE_APPLE_AVAILABLE_XCI(10.14, 13.0, 12))
        {
            // Use Metal 2.1
            compOpt.set_msl_version(2, 1);
        }
        else
        {
            // Always use at least Metal 2.0.
            compOpt.set_msl_version(2);
        }

        compOpt.pad_fragment_output_components = true;

        // Tell spirv-cross to map default & driver uniform blocks as we want
        spirv_cross::ShaderResources mslRes = spirv_cross::CompilerMSL::get_shader_resources();

        BindBuffers(this, mslRes.uniform_buffers, shaderType, hasArgumentBufferOut);

        if (*hasArgumentBufferOut)
        {
            // Enable argument buffer.
            compOpt.argument_buffers = true;

            // Force UBO argument buffer binding to start at kUBOArgumentBufferBindingIndex.
            spirv_cross::MSLResourceBinding argBufferBinding = {};
            argBufferBinding.stage    = ShaderTypeToSpvExecutionModel(shaderType);
            argBufferBinding.desc_set = kGlslangShaderResourceDescSet;
            argBufferBinding.binding =
                spirv_cross::kArgumentBufferBinding;  // spirv-cross built-in binding.
            argBufferBinding.msl_buffer = kUBOArgumentBufferBindingIndex;  // Actual binding.
            spirv_cross::CompilerMSL::add_msl_resource_binding(argBufferBinding);

            // Force discrete slot bindings for textures, default uniforms & driver uniforms
            // instead of using argument buffer.
            spirv_cross::CompilerMSL::add_discrete_descriptor_set(kGlslangTextureDescSet);
            spirv_cross::CompilerMSL::add_discrete_descriptor_set(kGlslangDefaultUniformDescSet);
            spirv_cross::CompilerMSL::add_discrete_descriptor_set(kGlslangDriverUniformsDescSet);
        }
        else
        {
            // Disable argument buffer generation for uniform buffers
            compOpt.argument_buffers = false;
        }

        spirv_cross::CompilerMSL::set_msl_options(compOpt);

        addBuiltInResources();
        analyzeShaderVariables();
        return PostProcessTranslatedMsl(mHasDepthSampler, spirv_cross::CompilerMSL::compile());
    }

  private:
    // Override CompilerMSL
    void emit_header() override
    {
        spirv_cross::CompilerMSL::emit_header();
        if (!mHasDepthSampler)
        {
            return;
        }
        // Work around code for these issues:
        // - spriv_cross always translates shadow texture's sampling to sample_compare() and doesn't
        // take into account GL_TEXTURE_COMPARE_MODE=GL_NONE.
        // - on macOS, explicit level of detail parameter is not supported in sample_compare().
        statement("enum class ANGLECompareMode : uint");
        statement("{");
        statement("    None = 0,");
        statement("    Less,");
        statement("    LessEqual,");
        statement("    Greater,");
        statement("    GreaterEqual,");
        statement("    Never,");
        statement("    Always,");
        statement("    Equal,");
        statement("    NotEqual,");
        statement("};");
        statement("");

        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEcompare(T depth, T dref, UniformOrUInt compareMode)");
        statement("{");
        statement("   ANGLECompareMode mode = static_cast<ANGLECompareMode>(compareMode);");
        statement("   switch (mode)");
        statement("   {");
        statement("        case ANGLECompareMode::Less:");
        statement("            return dref < depth;");
        statement("        case ANGLECompareMode::LessEqual:");
        statement("            return dref <= depth;");
        statement("        case ANGLECompareMode::Greater:");
        statement("            return dref > depth;");
        statement("        case ANGLECompareMode::GreaterEqual:");
        statement("            return dref >= depth;");
        statement("        case ANGLECompareMode::Never:");
        statement("            return 0;");
        statement("        case ANGLECompareMode::Always:");
        statement("            return 1;");
        statement("        case ANGLECompareMode::Equal:");
        statement("            return dref == depth;");
        statement("        case ANGLECompareMode::NotEqual:");
        statement("            return dref != depth;");
        statement("        default:");
        statement("            return 1;");
        statement("   }");
        statement("}");
        statement("");

        statement("// Wrapper functions for shadow texture functions");
        // 2D PCF sampling
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexturePCF(depth2d<T> texture, sampler s, float2 coord, float "
                  "compare_value, Opt options, int2 offset, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    float2 dims = float2(texture.get_width(), texture.get_height());");
        statement("    float2 imgCoord = coord * dims;");
        statement("    float2 texelSize = 1.0 / dims;");
        statement("    float2 weight = fract(imgCoord);");
        statement("    float tl = ANGLEcompare(texture.sample(s, coord, options, offset), "
                  "compare_value, shadowCompareMode);");
        statement("    float tr = ANGLEcompare(texture.sample(s, coord + float2(texelSize.x, 0.0), "
                  "options, offset), compare_value, shadowCompareMode);");
        statement("    float bl = ANGLEcompare(texture.sample(s, coord + float2(0.0, texelSize.y), "
                  "options, offset), compare_value, shadowCompareMode);");
        statement("    float br = ANGLEcompare(texture.sample(s, coord + texelSize, options, "
                  "offset), compare_value, shadowCompareMode);");
        statement("    float top = mix(tl, tr, weight.x);");
        statement("    float bottom = mix(bl, br, weight.x);");
        statement("    return mix(top, bottom, weight.y);");
        statement("}");
        statement("");

        // Cube PCF sampling
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexturePCF(depthcube<T> texture, sampler s, float3 coord, float "
                  "compare_value, Opt options, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    // NOTE(hqle): to implement");
        statement("    return ANGLEcompare(texture.sample(s, coord, options), compare_value, "
                  "shadowCompareMode);");
        statement("}");
        statement("");

        // 2D array PCF sampling
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement(
            "inline T ANGLEtexturePCF(depth2d_array<T> texture, sampler s, float2 coord, uint "
            "array, float compare_value, Opt options, int2 offset, UniformOrUInt "
            "shadowCompareMode)");
        statement("{");
        statement("    float2 dims = float2(texture.get_width(), texture.get_height());");
        statement("    float2 imgCoord = coord * dims;");
        statement("    float2 texelSize = 1.0 / dims;");
        statement("    float2 weight = fract(imgCoord);");
        statement("    float tl = ANGLEcompare(texture.sample(s, coord, array, options, offset), "
                  "compare_value, shadowCompareMode);");
        statement("    float tr = ANGLEcompare(texture.sample(s, coord + float2(texelSize.x, 0.0), "
                  "array, options, offset), compare_value, shadowCompareMode);");
        statement("    float bl = ANGLEcompare(texture.sample(s, coord + float2(0.0, texelSize.y), "
                  "array, options, offset), compare_value, shadowCompareMode);");
        statement("    float br = ANGLEcompare(texture.sample(s, coord + texelSize, options, "
                  "offset), array, compare_value, shadowCompareMode);");
        statement("    float top = mix(tl, tr, weight.x);");
        statement("    float bottom = mix(bl, br, weight.x);");
        statement("    return mix(top, bottom, weight.y);");
        statement("}");
        statement("");

        // 2D texture's sample_compare() wrapper
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtextureCompare(depth2d<T> texture, sampler s, float2 coord, float "
                  "compare_value, Opt options, int2 offset, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("#ifdef __METAL_MACOS__");
        statement("    return ANGLEtexturePCF(texture, s, coord, compare_value, options, offset, "
                  "shadowCompareMode);");
        statement("#else");
        statement("    return texture.sample_compare(s, coord, compare_value, options, offset);");
        statement("#endif");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtextureCompare(depth2d<T> texture, sampler s, float2 coord, float "
                  "compare_value, Opt options, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtextureCompare(texture, s, coord, compare_value, options, "
                  "int2(0), shadowCompareMode);");
        statement("}");
        statement("");

        // Cube texture's sample_compare() wrapper
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement(
            "inline T ANGLEtextureCompare(depthcube<T> texture, sampler s, float3 coord, float "
            "compare_value, Opt options, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("#ifdef __METAL_MACOS__");
        statement("    return ANGLEtexturePCF(texture, s, coord, compare_value, options, "
                  "shadowCompareMode);");
        statement("#else");
        statement("    return texture.sample_compare(s, coord, compare_value, options);");
        statement("#endif");
        statement("}");
        statement("");

        // 2D array texture's sample_compare() wrapper
        statement("// Wrapper functions for shadow texture functions");
        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtextureCompare(depth2d_array<T> texture, sampler s, float2 coord, "
                  "uint array, float compare_value, Opt options, int2 offset, UniformOrUInt "
                  "shadowCompareMode)");
        statement("{");
        statement("#ifdef __METAL_MACOS__");
        statement("    return ANGLEtexturePCF(texture, s, coord, array, compare_value, options, "
                  "offset, shadowCompareMode);");
        statement("#else");
        statement(
            "    return texture.sample_compare(s, coord, array, compare_value, options, offset);");
        statement("#endif");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtextureCompare(depth2d_array<T> texture, sampler s, float2 coord, "
                  "uint array, float compare_value, Opt options, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtextureCompare(texture, s, coord, array, compare_value, "
                  "options, int2(0), shadowCompareMode);");
        statement("}");
        statement("");

        // 2D texture's generic sampling function
        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d<T> texture, sampler s, float2 coord, int2 offset, "
                  "float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return texture.sample_compare(s, coord, compare_value, offset);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord, offset);");
        statement("    }");
        statement("}");
        statement("");

        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d<T> texture, sampler s, float2 coord, float "
                  "compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtexture(texture, s, coord, int2(0), compare_value, "
                  "shadowCompareMode);");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d<T> texture, sampler s, float2 coord, Opt options, "
                  "int2 offset, float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return ANGLEtextureCompare(texture, s, coord, compare_value, options, "
                  "offset, shadowCompareMode);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord, options, offset);");
        statement("    }");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d<T> texture, sampler s, float2 coord, Opt options, "
                  "float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtexture(texture, s, coord, options, int2(0), compare_value, "
                  "shadowCompareMode);");
        statement("}");
        statement("");

        // Cube texture's generic sampling function
        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depthcube<T> texture, sampler s, float3 coord, float "
                  "compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return texture.sample_compare(s, coord, compare_value);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord);");
        statement("    }");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depthcube<T> texture, sampler s, float2 coord, Opt "
                  "options, float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return ANGLEtextureCompare(texture, s, coord, compare_value, options, "
                  "shadowCompareMode);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord, options);");
        statement("    }");
        statement("}");
        statement("");

        // 2D array texture's generic sampling function
        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d_array<T> texture, sampler s, float2 coord, uint "
                  "array, int2 offset, "
                  "float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return texture.sample_compare(s, coord, array, compare_value, offset);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord, array, offset);");
        statement("    }");
        statement("}");
        statement("");

        statement("template <typename T, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d_array<T> texture, sampler s, float2 coord, uint "
                  "array, float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtexture(texture, s, coord, array, int2(0), compare_value, "
                  "shadowCompareMode);");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d_array<T> texture, sampler s, float2 coord, uint "
                  "array, Opt options, int2 offset, "
                  "float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    if (shadowCompareMode)");
        statement("    {");
        statement("        return ANGLEtextureCompare(texture, s, coord, array, compare_value, "
                  "options, offset, shadowCompareMode);");
        statement("    }");
        statement("    else");
        statement("    {");
        statement("        return texture.sample(s, coord, array, options, offset);");
        statement("    }");
        statement("}");
        statement("");

        statement("template <typename T, typename Opt, typename UniformOrUInt>");
        statement("inline T ANGLEtexture(depth2d_array<T> texture, sampler s, float2 coord, uint "
                  "array, Opt options, float compare_value, UniformOrUInt shadowCompareMode)");
        statement("{");
        statement("    return ANGLEtexture(texture, s, coord, array, options, int2(0), "
                  "compare_value, shadowCompareMode);");
        statement("}");
        statement("");
    }

    std::string to_function_name(spirv_cross::VariableID img,
                                 const spirv_cross::SPIRType &imgType,
                                 bool isFetch,
                                 bool isGather,
                                 bool isProj,
                                 bool hasArrayOffsets,
                                 bool hasOffset,
                                 bool hasGrad,
                                 bool hasDref,
                                 uint32_t lod,
                                 uint32_t minLod) override
    {
        if (!hasDref)
        {
            return spirv_cross::CompilerMSL::to_function_name(img, imgType, isFetch, isGather,
                                                              isProj, hasArrayOffsets, hasOffset,
                                                              hasGrad, hasDref, lod, minLod);
        }

        // Use custom ANGLEtexture function instead of using built-in sample_compare()
        return "ANGLEtexture";
    }

    std::string to_function_args(spirv_cross::VariableID img,
                                 const spirv_cross::SPIRType &imgType,
                                 bool isFetch,
                                 bool isGather,
                                 bool isProj,
                                 uint32_t coord,
                                 uint32_t coordComponents,
                                 uint32_t dref,
                                 uint32_t gradX,
                                 uint32_t gradY,
                                 uint32_t lod,
                                 uint32_t coffset,
                                 uint32_t offset,
                                 uint32_t bias,
                                 uint32_t comp,
                                 uint32_t sample,
                                 uint32_t minlod,
                                 bool *pForward) override
    {
        bool forward;
        std::string argsWithoutDref = spirv_cross::CompilerMSL::to_function_args(
            img, imgType, isFetch, isGather, isProj, coord, coordComponents, 0, gradX, gradY, lod,
            coffset, offset, bias, comp, sample, minlod, &forward);

        if (!dref)
        {
            if (pForward)
            {
                *pForward = forward;
            }
            return argsWithoutDref;
        }
        // Convert to arguments to ANGLEtexture.
        std::string args = to_expression(img);
        args += ", ";
        args += argsWithoutDref;
        args += ", ";

        forward                               = forward && should_forward(dref);
        const spirv_cross::SPIRType &drefType = expression_type(dref);
        std::string drefExpr;
        uint32_t altCoordComponent = 0;
        switch (imgType.image.dim)
        {
            case spv::Dim2D:
                altCoordComponent = 2;
                break;
            case spv::Dim3D:
            case spv::DimCube:
                altCoordComponent = 3;
                break;
            default:
                UNREACHABLE();
                break;
        }
        if (isProj)
            drefExpr = spirv_cross::join(to_enclosed_expression(dref), " / ",
                                         to_extract_component_expression(coord, altCoordComponent));
        else
            drefExpr = to_expression(dref);

        if (drefType.basetype == spirv_cross::SPIRType::Half)
            drefExpr = convert_to_f32(drefExpr, 1);

        args += drefExpr;
        args += ", ";
        args += toShadowCompareModeExpression(img);

        if (pForward)
        {
            *pForward = forward;
        }

        return args;
    }

    // Additional functions
    void addBuiltInResources()
    {
        uint32_t varId = build_constant_uint_array_pointer();
        set_name(varId, kShadowSamplerCompareModesVarName);
        // This should never match anything.
        set_decoration(varId, spv::DecorationDescriptorSet, kShadowSamplerCompareModesBindingIndex);
        set_decoration(varId, spv::DecorationBinding, 0);
        set_extended_decoration(varId, spirv_cross::SPIRVCrossDecorationResourceIndexPrimary, 0);
        mANGLEShadowCompareModesVarId = varId;
    }

    void analyzeShaderVariables()
    {
        ir.for_each_typed_id<spirv_cross::SPIRVariable>([this](uint32_t,
                                                               spirv_cross::SPIRVariable &var) {
            auto &type     = get_variable_data_type(var);
            uint32_t varId = var.self;

            if (var.storage == spv::StorageClassUniformConstant && !is_hidden_variable(var))
            {
                if (is_sampled_image_type(type) && type.image.depth)
                {
                    mHasDepthSampler = true;

                    auto &entry_func = this->get<spirv_cross::SPIRFunction>(ir.default_entry_point);
                    entry_func.fixup_hooks_in.push_back([this, &type, &var, varId]() {
                        bool isArrayType = !type.array.empty();

                        statement("constant uniform<uint>", isArrayType ? "* " : "& ",
                                  toShadowCompareModeExpression(varId),
                                  isArrayType ? " = &" : " = ",
                                  to_name(mANGLEShadowCompareModesVarId), "[",
                                  spirv_cross::convert_to_string(
                                      get_metal_resource_index(var, spirv_cross::SPIRType::Image)),
                                  "];");
                    });
                }
            }
        });
    }

    std::string toShadowCompareModeExpression(uint32_t id)
    {
        constexpr char kCompareModeSuffix[] = "_CompMode";
        auto *combined                      = maybe_get<spirv_cross::SPIRCombinedImageSampler>(id);

        std::string expr = to_expression(combined ? combined->image : spirv_cross::VariableID(id));
        auto index       = expr.find_first_of('[');

        if (index == std::string::npos)
            return expr + kCompareModeSuffix;
        else
        {
            auto imageExpr = expr.substr(0, index);
            auto arrayExpr = expr.substr(index);
            return imageExpr + kCompareModeSuffix + arrayExpr;
        }
    }

    uint32_t mANGLEShadowCompareModesVarId = 0;
    bool mHasDepthSampler                  = false;
};

}  // namespace

void GlslangGetShaderSource(const gl::ProgramState &programState,
                            const gl::ProgramLinkedResources &resources,
                            gl::ShaderMap<std::string> *shaderSourcesOut)
{
    rx::GlslangGetShaderSource(CreateSourceOptions(), false, programState, resources,
                               shaderSourcesOut);
}

angle::Result GlslangGetShaderSpirvCode(ErrorHandler *context,
                                        const gl::Caps &glCaps,
                                        bool enableLineRasterEmulation,
                                        const gl::ShaderMap<std::string> &shaderSources,
                                        gl::ShaderMap<std::vector<uint32_t>> *shaderCodeOut)
{
    return rx::GlslangGetShaderSpirvCode(
        [context](GlslangError error) { return HandleError(context, error); }, glCaps,
        enableLineRasterEmulation, shaderSources, shaderCodeOut);
}

angle::Result SpirvCodeToMsl(ErrorHandler *context,
                             gl::ShaderMap<std::vector<uint32_t>> *sprivShaderCode,
                             gl::ShaderMap<TranslatedShaderInfo> *mslShaderInfoOut,
                             gl::ShaderMap<std::string> *mslCodeOut)
{
    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        std::vector<uint32_t> &sprivCode = sprivShaderCode->at(shaderType);
        SpirvToMslCompiler compilerMsl(std::move(sprivCode));

        // NOTE(hqle): spirv-cross uses exceptions to report error, what should we do here
        // in case of error?
        std::string translatedMsl =
            compilerMsl.compileEx(shaderType, &mslShaderInfoOut->at(shaderType).hasArgumentBuffer);
        if (translatedMsl.size() == 0)
        {
            ANGLE_MTL_CHECK(context, false, GL_INVALID_OPERATION);
        }

        // Retrieve automatic texture slot assignments
        ANGLE_TRY(GetAssignedSamplerBindings(
            compilerMsl, &mslShaderInfoOut->at(shaderType).actualSamplerBindings));

        mslCodeOut->at(shaderType) = std::move(translatedMsl);
    }  // for (gl::ShaderType shaderType

    return angle::Result::Continue;
}

uint MslGetShaderShadowCompareMode(GLenum mode, GLenum func)
{
    // See SpirvToMslCompiler::emit_header()
    if (mode == GL_NONE)
    {
        return 0;
    }
    else
    {
        switch (func)
        {
            case GL_LESS:
                return 1;
            case GL_LEQUAL:
                return 2;
            case GL_GREATER:
                return 3;
            case GL_GEQUAL:
                return 4;
            case GL_NEVER:
                return 5;
            case GL_ALWAYS:
                return 6;
            case GL_EQUAL:
                return 7;
            case GL_NOTEQUAL:
                return 8;
            default:
                UNREACHABLE();
                return 1;
        }
    }
}

}  // namespace mtl
}  // namespace rx
