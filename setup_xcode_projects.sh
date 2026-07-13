#!/bin/bash
# Script to create Xcode projects for vrOS

set -e

VR_OS_ROOT="/Users/jd/Programming/repos/vrOS"

echo "=== Creating Xcode projects for vrOS ==="
echo ""

# Create macOS project
echo "1. Creating macOS Sender project..."
cd "$VR_OS_ROOT/macOSSender"

# Create a new Xcode project using xcodebuild's project template
# We'll use a simpler approach - copy a known good template

cat > create_macos_project.py << 'PYEOF'
#!/usr/bin/env python3
import os
import sys
import subprocess

# Create a fresh macOS project
os.chdir("/Users/jd/Programming/repos/vrOS/macOSSender")

# Use xcodebuild to create a basic project
# First, let's check what's available
result = subprocess.run(["xcodebuild", "-version"], capture_output=True, text=True)
print(f"Xcode version: {result.stdout.strip()}")

# Create project using a simple approach - copy template
# We'll use the project template that xcodebuild provides
os.makedirs("vrOSSender.xcodeproj", exist_ok=True)

# The simplest valid project.pbxproj
project_content = '''// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		F1 /* App.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2 /* App.swift */; };
		F3 /* StreamController.swift in Sources */ = {isa = PBXBuildFile; fileRef = F4 /* StreamController.swift */; };
		F5 /* VideoEncoder.swift in Sources */ = {isa = PBXBuildFile; fileRef = F6 /* VideoEncoder.swift */; };
		F7 /* USBServer.swift in Sources */ = {isa = PBXBuildFile; fileRef = F8 /* USBServer.swift */; };
		F9 /* USBPacket.swift in Sources */ = {isa = PBXBuildFile; fileRef = F10 /* USBPacket.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		F2 /* App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; };
		F4 /* StreamController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StreamController.swift; sourceTree = "<group>"; };
		F6 /* VideoEncoder.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VideoEncoder.swift; sourceTree = "<group>"; };
		F8 /* USBServer.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBServer.swift; sourceTree = "<group>"; };
		F10 /* USBPacket.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBPacket.swift; sourceTree = "<group>"; };
		F11 /* vrOSSender.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = vrOSSender.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		F12 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		F13 = {
			isa = PBXGroup;
			children = (
				F2 /* App.swift */,
				F14 /* Controller */,
				F15 /* Encoder */,
				F16 /* Networking */,
				F17 /* Shared */,
			);
			path = vrOSSender;
			sourceTree = "<group>";
		};
		F14 = {
			isa = PBXGroup;
			children = (
				F18 /* StreamController.swift */,
			);
			path = Controller;
			sourceTree = "<group>";
		};
		F15 = {
			isa = PBXGroup;
			children = (
				F19 /* VideoEncoder.swift */,
			);
			path = Encoder;
			sourceTree = "<group>";
		};
		F16 = {
			isa = PBXGroup;
			children = (
				F20 /* USBServer.swift */,
			);
			path = Networking;
			sourceTree = "<group>";
		};
		F17 = {
			isa = PBXGroup;
			children = (
				F10 /* USBPacket.swift */,
			);
			path = Shared;
			sourceTree = "<group>";
		};
		F0 = {
			isa = PBXGroup;
			children = (
				F13 /* vrOSSender */,
				F11 /* vrOSSender.app */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		F21 = {
			isa = PBXNativeTarget;
			buildConfigurationList = F22 /* Build configuration list for PBXNativeTarget "vrOSSender" */;
			buildPhases = (
				F23 /* Sources */,
				F24 /* Frameworks */,
				F25 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = vrOSSender;
			productName = vrOSSender;
			productReference = F11 /* vrOSSender.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		F26 = {
			isa = PBXProject;
			attributes = {
				LastSwiftMigration = 1000;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					F21 = {
						CreatedOnToolsVersion = 15.0;
						DevelopmentTeam = "";
						ProvisioningStyle = Automatic;
					};
				};
			};
			buildConfigurationList = F27 /* Build configuration list for PBXProject "vrOSSender" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = F0;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				F21 /* vrOSSender */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		F25 = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		F23 = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				F1 /* App.swift in Sources */,
				F3 /* StreamController.swift in Sources */,
				F5 /* VideoEncoder.swift in Sources */,
				F7 /* USBServer.swift in Sources */,
				F9 /* USBPacket.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		F27 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATION = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				INFOPLIST_FILE = vrOSSender/Info.plist;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.vros.sender;
				PRODUCT_NAME = $(TARGET_NAME);
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		F28 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATION = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				INFOPLIST_FILE = vrOSSender/Info.plist;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.vros.sender;
				PRODUCT_NAME = $(TARGET_NAME);
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		F22 = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F27 /* Debug */,
				F28 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
		F29 = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F27 /* Debug */,
				F28 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = F0 /* Project object */;
}
'''

with open("vrOSSender.xcodeproj/project.pbxproj", "w") as f:
    f.write(project_content)

print("macOS project created")
PYEOF

python3 create_macos_project.py

# Create iOS project
echo "2. Creating iOS Receiver project..."
cd "$VR_OS_ROOT/iOSReceiver"

cat > create_ios_project.py << 'PYEOF'
#!/usr/bin/env python3
import os

os.chdir("/Users/jd/Programming/repos/vrOS/iOSReceiver")
os.makedirs("vrOSReceiver.xcodeproj", exist_ok=True)

project_content = '''// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		G1 /* App.swift in Sources */ = {isa = PBXBuildFile; fileRef = G2 /* App.swift */; };
		G3 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = G4 /* ContentView.swift */; };
		G5 /* VideoDecoder.swift in Sources */ = {isa = PBXBuildFile; fileRef = G6 /* VideoDecoder.swift */; };
		G7 /* USBClient.swift in Sources */ = {isa = PBXBuildFile; fileRef = G8 /* USBClient.swift */; };
		G9 /* MetalRenderer.swift in Sources */ = {isa = PBXBuildFile; fileRef = G10 /* MetalRenderer.swift */; };
		G11 /* Shaders.metal in Sources */ = {isa = PBXBuildFile; fileRef = G12 /* Shaders.metal */; };
		G13 /* USBPacket.swift in Sources */ = {isa = PBXBuildFile; fileRef = G14 /* USBPacket.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		G2 /* App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; };
		G4 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		G6 /* VideoDecoder.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VideoDecoder.swift; sourceTree = "<group>"; };
		G8 /* USBClient.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBClient.swift; sourceTree = "<group>"; };
		G10 /* MetalRenderer.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MetalRenderer.swift; sourceTree = "<group>"; };
		G12 /* Shaders.metal */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.metal; path = Shaders.metal; sourceTree = "<group>"; };
		G14 /* USBPacket.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBPacket.swift; sourceTree = "<group>"; };
		G15 /* vrOSReceiver.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = vrOSReceiver.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		G16 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		G17 = {
			isa = PBXGroup;
			children = (
				G2 /* App.swift */,
				G4 /* ContentView.swift */,
				G6 /* VideoDecoder.swift */,
				G8 /* USBClient.swift */,
				G10 /* MetalRenderer.swift */,
				G12 /* Shaders.metal */,
				G14 /* USBPacket.swift */,
			);
			sourceTree = "<group>";
		};
		G0 = {
			isa = PBXGroup;
			children = (
				G17 /* vrOSReceiver */,
				G15 /* vrOSReceiver.app */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		G18 = {
			isa = PBXNativeTarget;
			buildConfigurationList = G19 /* Build configuration list for PBXNativeTarget "vrOSReceiver" */;
			buildPhases = (
				G16 /* Frameworks */,
				G20 /* Resources */,
				G21 /* Sources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = vrOSReceiver;
			productName = vrOSReceiver;
			productReference = G15 /* vrOSReceiver.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		G22 = {
			isa = PBXProject;
			attributes = {
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					G18 = {
						CreatedOnToolsVersion = 15.0;
						DevelopmentTeam = "";
						ProvisioningStyle = Automatic;
					};
				};
			};
			buildConfigurationList = G23 /* Build configuration list for PBXProject "vrOSReceiver" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = G17;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				G18 /* vrOSReceiver */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		G20 = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		G21 = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				G1 /* App.swift in Sources */,
				G3 /* ContentView.swift in Sources */,
				G5 /* VideoDecoder.swift in Sources */,
				G7 /* USBClient.swift in Sources */,
				G9 /* MetalRenderer.swift in Sources */,
				G11 /* Shaders.metal in Sources */,
				G13 /* USBPacket.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		G24 = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATION = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				INFOPLIST_FILE = vrOSReceiver/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		G25 = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATION = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				INFOPLIST_FILE = vrOSReceiver/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		G26 = {
			isa = XCConfigurationList;
			buildConfigurations = (
				G24 /* Debug */,
				G25 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
		G27 = {
			isa = XCConfigurationList;
			buildConfigurations = (
				G24 /* Debug */,
				G25 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = G0 /* Project object */;
}
'''

with open("vrOSReceiver.xcodeproj/project.pbxproj", "w") as f:
    f.write(project_content)

print("iOS project created")
PYEOF

python3 create_ios_project.py

echo ""
echo "=== Projects created ==="
echo ""
echo "To build and run:"
echo ""
echo "macOS Sender:"
echo "  cd $VR_OS_ROOT/macOSSender"
echo "  xcodebuild -project vrOSSender.xcodeproj -scheme vrOSSender -destination 'platform=macOS'"
echo ""
echo "iOS Receiver:"
echo "  cd $VR_OS_ROOT/iOSReceiver"
echo "  xcodebuild -project vrOSReceiver.xcodeproj -scheme vrOSReceiver -destination 'platform=iOS,name=Your iPhone'"
echo ""
echo "Then open the .xcodeproj files in Xcode to run on device."