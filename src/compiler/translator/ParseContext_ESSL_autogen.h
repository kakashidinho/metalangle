// GENERATED FILE - DO NOT EDIT.
// Generated by gen_builtin_symbols.py using data from builtin_variables.json and
// builtin_function_declarations.txt.
//
// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ParseContext_ESSL_autogen.h:
//   Helpers for built-in related checks.

#ifndef COMPILER_TRANSLATOR_PARSECONTEXT_AUTOGEN_H_
#define COMPILER_TRANSLATOR_PARSECONTEXT_AUTOGEN_H_

namespace sh
{

namespace BuiltInGroup
{

bool isTextureOffsetNoBias(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3018 && id <= 3087;
}
bool isTextureOffsetBias(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3088 && id <= 3107;
}
bool isTextureGatherOffset(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3145 && id <= 3158;
}
bool isTextureGather(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3121 && id <= 3158;
}
bool isAtomicMemory(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3175 && id <= 3192;
}
bool isImageLoad(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3217 && id <= 3228;
}
bool isImageStore(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3229 && id <= 3240;
}
bool isImage(const TFunction *func)
{
    int id = func->uniqueId().get();
    return id >= 3193 && id <= 3240;
}

}  // namespace BuiltInGroup

}  // namespace sh

#endif  // COMPILER_TRANSLATOR_PARSECONTEXT_AUTOGEN_H_
