# TensorFlow Text Patches Directory

## 🧹 **CLEAN SLATE APPROACH - NO PATCHES USED**

This directory is **intentionally empty** as part of our successful **clean slate strategy** for building TensorFlow Text 2.18.1.

## 📋 **Historical Context**

### **Original Patch Complexity (ABANDONED)**

The original recipe maintained **6+ patches** with significant maintenance burden:

1. `0001-adjust-tf-version-range.patch` - TensorFlow version compatibility
2. `0002-make-other-minor-adjustments.patch` - Build configuration tweaks
3. `0003-do-not-check-for-bazel-version.patch` - Bazel version workarounds
4. `0004-skip-pull-tf-dependencies.patch` - Dependency management
5. `0005-fix-broken-text-filters.patch` - Text processing fixes
6. `0006-clean-up-after-bazel-temp-files.patch` - Build cleanup

### **Problems with Patch-Based Approach**

❌ **Compilation Errors**: Patches caused missing headers and BUILD file issues
❌ **Maintenance Overhead**: Each TensorFlow Text update required patch updates
❌ **Patch Corruption**: Format errors and duplicate content in patch files
❌ **Dependency Conflicts**: Complex interactions between patches
❌ **Debug Difficulty**: Multi-layered issues hard to isolate and fix

## ✅ **Clean Slate Solution**

### **Strategy Decision**

**User Direction**: "Let's try a clean slate approach"
**Implementation**: Remove all patches, simplify build configuration
**Result**: **IMMEDIATE SUCCESS** - compilation errors eliminated

### **Key Success Factors**

1. **Minimal Configuration**: Reduced `build.sh` from 247 lines to ~54 lines
2. **Environment Control**: Proper conda toolchain integration
3. **ABI Compatibility**: Strategic compiler flags for libabseil integration
4. **Resource Management**: Bazel resource limits prevent build failures
5. **No Patches Required**: TensorFlow Text 2.18.1 builds cleanly without modifications

## 🎯 **Build Philosophy**

> **"Simplicity over Complexity"**
>
> Rather than maintaining complex patches to work around issues, we:
> - Use proper build configuration
> - Leverage conda's toolchain integration
> - Apply strategic compiler flags
> - Focus on resource management

## 📊 **Comparison Results**

| **Approach** | **Lines of Code** | **Patches** | **Build Success** | **Maintenance** |
|--------------|-------------------|-------------|-------------------|-----------------|
| **Original** | 247 lines | 6+ patches | ❌ Failures | 🔴 High |
| **Clean Slate** | 54 lines | 0 patches | ✅ Success | 🟢 Low |

## 🔄 **Future Patch Strategy**

**If patches become necessary in future versions:**

1. **Minimal Scope**: Apply smallest possible changes
2. **Single Purpose**: One issue per patch file
3. **Clear Documentation**: Explain rationale and alternatives
4. **Upstream First**: Consider contributing fixes to TensorFlow Text
5. **Regular Review**: Remove patches when upstream fixes are available

## 📝 **Patch Creation Guidelines**

**Only create patches when:**
- ✅ Build configuration cannot solve the issue
- ✅ Upstream fix is not available/practical
- ✅ Issue affects package functionality significantly
- ✅ Alternative approaches have been exhausted

**Patch naming convention:**
```
NNNN-brief-description.patch
```

**Required documentation:**
- Clear commit message explaining the problem
- Reference to upstream issue (if applicable)
- Explanation of why build configuration cannot solve it
- Plan for patch removal in future versions

## 🎉 **Success Story**

The **clean slate approach** transformed this recipe from:
- ❌ Complex, failing build with maintenance overhead
- ✅ Simple, successful build with minimal maintenance

**Bottom Line**: Sometimes the best patch is no patch at all.
