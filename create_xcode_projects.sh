#!/bin/bash
# Create Xcode projects for vrOS

cd /Users/jd/Programming/repos/vrOS

# Create macOS Sender project
cat > macOSSender/vrOSSender.xcodeproj/project.pbxproj << 'PROJEOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		F1 /* App.swift in Sources */ = {isa = PBXBuildFile; fileRef = F2 /* App.swift */; };
		F3 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = F4 /* ContentView.swift */; };
		F5 /* StreamController.swift in Sources */ = {isa = PBXBuildFile; fileRef = F6 /* StreamController.swift */; };
		F7 /* VideoEncoder.swift in Sources */ = {isa = PBXBuildFile; fileRef = F8 /* VideoEncoder.swift */; };
		F9 /* USBServer.swift in Sources */ = {isa = PBXBuildFile; fileRef = F10 /* USBServer.swift */; };
		F11 /* USBPacket.swift in Sources */ = {isa = PBXBuildFile; fileRef = F12 /* USBPacket.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		F2 /* App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; };
		F4 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		F6 /* StreamController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StreamController.swift; sourceTree = "<group>"; };
		F8 /* VideoEncoder.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VideoEncoder.swift; sourceTree = "<group>"; };
		F10 /* USBServer.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBServer.swift; sourceTree = "<group>"; };
		F12 /* USBPacket.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = USBPacket.swift; sourceTree = "<group>"; };
		F13 /* vrOSSender.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = vrOSSender.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		F14 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		F15 = {
			isa = PBXGroup;
			children = (
				F2 /* App.swift */,
				F4 /* ContentView.swift */,
				F16 /* Controller */,
				F19 /* Encoder */,
				F22 /* Networking */,
				F25 /* Shared */,
			);
			path = vrOSSender;
			sourceTree = "<group>";
		};
		F16 /* Controller */ = {
			isa = PBXGroup;
			children = (
				F6 /* StreamController.swift */,
			);
			path = Controller;
			sourceTree = "<group>";
		};
		F19 /* Encoder */ = {
			isa = PBXGroup;
			children = (
				F8 /* VideoEncoder.swift */,
			);
			path = Encoder;
			sourceTree = "<group>";
		};
		F22 /* Networking */ = {
			isa = PBXGroup;
			children = (
				F10 /* USBServer.swift */,
			);
			path = Networking;
			sourceTree = "<group>";
		};
		F25 /* Shared */ = {
			isa = PBXGroup;
			children = (
				F12 /* USBPacket.swift */,
			);
			path = Shared;
			sourceTree = "<group>";
		};
		F0 = {
			isa = PBXGroup;
			children = (
				F15 /* vrOSSender */,
				F13 /* vrOSSender.app */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		F26 /* vrOSSender */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = F29 /* Build configuration list for PBXNativeTarget "vrOSSender" */;
			buildPhases = (
				F27 /* Sources */,
				F14 /* Frameworks */,
				F28 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = vrOSSender;
			productName = vrOSSender;
			productReference = F13 /* vrOSSender.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		F0 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastSwiftMigration = 1000;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					F26 = {
						CreatedOnToolsVersion = 15.0;
						DevelopmentTeam = "";
						ProvisioningStyle = Automatic;
					};
				};
			};
			buildConfigurationList = F30 /* Build configuration list for PBXProject "vrOSSender" */;
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
				F26 /* vrOSSender */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		F28 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		F27 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				F1 /* App.swift in Sources */,
				F3 /* ContentView.swift in Sources */,
				F5 /* StreamController.swift in Sources */,
				F7 /* VideoEncoder.swift in Sources */,
				F9 /* USBServer.swift in Sources */,
				F11 /* USBPacket.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		F31 /* Debug */ = {
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
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		F32 /* Release */ = {
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
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		F29 /* Build configuration list for PBXNativeTarget "vrOSSender" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F31 /* Debug */,
				F32 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
		F30 /* Build configuration list for PBXProject "vrOSSender" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F31 /* Debug */,
				F32 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = F0 /* Project object */;
}
PROJEOF

# Create iOS Receiver project
cat > iOSReceiver/vrOSReceiver.xcodeproj/project.pbxproj << 'PROJEOF'
// !$*UTF8*$!
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
		G18 /* vrOSReceiver */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = G21 /* Build configuration list for PBXNativeTarget "vrOSReceiver" */;
			buildPhases = (
				G16 /* Frameworks */,
				G19 /* Resources */,
				G20 /* Sources */,
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
		G0 /* Project object */ = {
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
			buildConfigurationList = G22 /* Build configuration list for PBXProject "vrOSReceiver" */;
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
		G19 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		G20 /* Sources */ = {
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
		G23 /* Debug */ = {
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
		G24 /* Release */ = {
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
		G21 /* Build configuration list for PBXNativeTarget "vrOSReceiver" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				G23 /* Debug */,
				G24 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
		G22 /* Build configuration list for PBXProject "vrOSReceiver" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				G23 /* Debug */,
				G24 /* Release */,
			);
			defaultConfigurationIsRelease = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = G0 /* Project object */;
}
PROJEOF

echo "Xcode projects created successfully"