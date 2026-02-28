#!/usr/bin/env ruby
# Generates Fluister.xcodeproj for xcodebuild CLI builds
# This avoids needing to open Xcode UI

require 'fileutils'

REPO_ROOT = File.expand_path('..', __dir__)
PROJECT_DIR = File.join(REPO_ROOT, 'Fluister.xcodeproj')
PBXPROJ = File.join(PROJECT_DIR, 'project.pbxproj')

FileUtils.mkdir_p(PROJECT_DIR)

# Collect all Swift source files
source_dir = File.join(REPO_ROOT, 'WhisperFlow', 'Sources')
swift_files = Dir.glob(File.join(source_dir, '**', '*.swift')).sort

# Generate deterministic UUIDs based on file path
def make_id(seed)
  require 'digest'
  Digest::MD5.hexdigest(seed).upcase[0, 24]
end

# Group structure
groups = {}
file_refs = {}
build_files = {}

swift_files.each do |f|
  rel = f.sub("#{source_dir}/", '')
  dir = File.dirname(rel)
  name = File.basename(rel)

  file_id = make_id("fileref_#{rel}")
  build_id = make_id("buildfile_#{rel}")

  file_refs[rel] = { id: file_id, name: name, path: "WhisperFlow/Sources/#{rel}" }
  build_files[rel] = { id: build_id, file_ref: file_id }

  groups[dir] ||= []
  groups[dir] << file_id
end

# Add bridging header
bridging_id = make_id("fileref_bridging")
file_refs["bridging"] = { id: bridging_id, name: "WhisperFlow-Bridging-Header.h", path: "WhisperFlow/Sources/App/WhisperFlow-Bridging-Header.h" }

# Add Info.plist
plist_id = make_id("fileref_infoplist")
file_refs["infoplist"] = { id: plist_id, name: "Info.plist", path: "WhisperFlow/Info.plist" }

# Fixed IDs for project structure
ROOT_GROUP_ID = make_id("root_group")
MAIN_GROUP_ID = make_id("main_group")
SOURCES_GROUP_ID = make_id("sources_group")
PROJECT_ID = make_id("project")
TARGET_ID = make_id("target_app")
BUILD_PHASE_SOURCES_ID = make_id("build_phase_sources")
BUILD_PHASE_FRAMEWORKS_ID = make_id("build_phase_frameworks")
BUILD_PHASE_RESOURCES_ID = make_id("build_phase_resources")
DEBUG_CONFIG_ID = make_id("debug_config")
RELEASE_CONFIG_ID = make_id("release_config")
TARGET_DEBUG_ID = make_id("target_debug")
TARGET_RELEASE_ID = make_id("target_release")
CONFIG_LIST_ID = make_id("config_list")
TARGET_CONFIG_LIST_ID = make_id("target_config_list")
PRODUCTS_GROUP_ID = make_id("products_group")
APP_PRODUCT_ID = make_id("app_product")

# Test target IDs
TEST_TARGET_ID = make_id("target_tests")
TEST_BUILD_PHASE_SOURCES_ID = make_id("test_build_phase_sources")
TEST_BUILD_PHASE_FRAMEWORKS_ID = make_id("test_build_phase_frameworks")
TEST_DEBUG_ID = make_id("test_debug_config")
TEST_RELEASE_ID = make_id("test_release_config")
TEST_CONFIG_LIST_ID = make_id("test_config_list")
TEST_PRODUCT_ID = make_id("test_product")
TEST_DEPENDENCY_ID = make_id("test_dependency")
TEST_PROXY_ID = make_id("test_proxy")

# Collect test files
test_dir = File.join(REPO_ROOT, 'WhisperFlowTests')
test_files = Dir.glob(File.join(test_dir, '**', '*.swift')).sort

test_file_refs = {}
test_build_files = {}

test_files.each do |f|
  rel = f.sub("#{REPO_ROOT}/", '')
  name = File.basename(rel)
  file_id = make_id("fileref_test_#{rel}")
  build_id = make_id("buildfile_test_#{rel}")

  test_file_refs[rel] = { id: file_id, name: name, path: rel }
  test_build_files[rel] = { id: build_id, file_ref: file_id }
end

TEST_GROUP_ID = make_id("test_group")

# Sub-group IDs
subgroup_ids = {}
groups.each_key do |dir|
  subgroup_ids[dir] = make_id("group_#{dir}")
end

pbxproj_content = <<~PBXPROJ
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
#{build_files.map { |rel, bf| "\t\t#{bf[:id]} /* #{File.basename(rel)} */ = {isa = PBXBuildFile; fileRef = #{bf[:file_ref]}; };" }.join("\n")}
#{test_build_files.map { |rel, bf| "\t\t#{bf[:id]} /* #{File.basename(rel)} */ = {isa = PBXBuildFile; fileRef = #{bf[:file_ref]}; };" }.join("\n")}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		#{TEST_PROXY_ID} = {
			isa = PBXContainerItemProxy;
			containerPortal = #{PROJECT_ID};
			proxyType = 1;
			remoteGlobalIDString = #{TARGET_ID};
			remoteInfo = Fluister;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		#{APP_PRODUCT_ID} /* Fluister.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Fluister.app; sourceTree = BUILT_PRODUCTS_DIR; };
		#{TEST_PRODUCT_ID} /* FluisterTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = FluisterTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
#{file_refs.map { |rel, fr| "\t\t#{fr[:id]} /* #{fr[:name]} */ = {isa = PBXFileReference; lastKnownFileType = #{fr[:name].end_with?('.swift') ? 'sourcecode.swift' : fr[:name].end_with?('.h') ? 'sourcecode.c.h' : 'text.plist.xml'}; path = \"#{fr[:path]}\"; sourceTree = SOURCE_ROOT; };" }.join("\n")}
#{test_file_refs.map { |rel, fr| "\t\t#{fr[:id]} /* #{fr[:name]} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"#{fr[:path]}\"; sourceTree = SOURCE_ROOT; };" }.join("\n")}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		#{BUILD_PHASE_FRAMEWORKS_ID} = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
		#{TEST_BUILD_PHASE_FRAMEWORKS_ID} = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		#{ROOT_GROUP_ID} = {
			isa = PBXGroup;
			children = (
				#{SOURCES_GROUP_ID},
				#{TEST_GROUP_ID},
				#{PRODUCTS_GROUP_ID},
			);
			sourceTree = "<group>";
		};
		#{PRODUCTS_GROUP_ID} = {
			isa = PBXGroup;
			children = (
				#{APP_PRODUCT_ID},
				#{TEST_PRODUCT_ID},
			);
			name = Products;
			sourceTree = "<group>";
		};
		#{SOURCES_GROUP_ID} = {
			isa = PBXGroup;
			children = (
#{subgroup_ids.map { |dir, id| "\t\t\t\t#{id}," }.join("\n")}
				#{plist_id},
			);
			name = Sources;
			sourceTree = "<group>";
		};
#{subgroup_ids.map { |dir, id|
  children = groups[dir].map { |fid| "\t\t\t\t#{fid}," }.join("\n")
  "\t\t#{id} = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n#{children}\n\t\t\t);\n\t\t\tname = \"#{dir}\";\n\t\t\tsourceTree = \"<group>\";\n\t\t};"
}.join("\n")}
		#{TEST_GROUP_ID} = {
			isa = PBXGroup;
			children = (
#{test_file_refs.map { |rel, fr| "\t\t\t\t#{fr[:id]}," }.join("\n")}
			);
			name = FluisterTests;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		#{TARGET_ID} = {
			isa = PBXNativeTarget;
			buildConfigurationList = #{TARGET_CONFIG_LIST_ID};
			buildPhases = (
				#{BUILD_PHASE_SOURCES_ID},
				#{BUILD_PHASE_FRAMEWORKS_ID},
				#{BUILD_PHASE_RESOURCES_ID},
			);
			buildRules = ();
			dependencies = ();
			name = Fluister;
			productName = Fluister;
			productReference = #{APP_PRODUCT_ID};
			productType = "com.apple.product-type.application";
		};
		#{TEST_TARGET_ID} = {
			isa = PBXNativeTarget;
			buildConfigurationList = #{TEST_CONFIG_LIST_ID};
			buildPhases = (
				#{TEST_BUILD_PHASE_SOURCES_ID},
				#{TEST_BUILD_PHASE_FRAMEWORKS_ID},
			);
			buildRules = ();
			dependencies = (
				#{TEST_DEPENDENCY_ID},
			);
			name = FluisterTests;
			productName = FluisterTests;
			productReference = #{TEST_PRODUCT_ID};
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		#{PROJECT_ID} = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1620;
				LastUpgradeCheck = 1620;
			};
			buildConfigurationList = #{CONFIG_LIST_ID};
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (en, Base);
			mainGroup = #{ROOT_GROUP_ID};
			productRefGroup = #{PRODUCTS_GROUP_ID};
			projectDirPath = "";
			projectRoot = "";
			targets = (
				#{TARGET_ID},
				#{TEST_TARGET_ID},
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		#{BUILD_PHASE_RESOURCES_ID} = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		#{BUILD_PHASE_SOURCES_ID} = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
#{build_files.map { |rel, bf| "\t\t\t\t#{bf[:id]}," }.join("\n")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		#{TEST_BUILD_PHASE_SOURCES_ID} = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
#{test_build_files.map { |rel, bf| "\t\t\t\t#{bf[:id]}," }.join("\n")}
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		#{TEST_DEPENDENCY_ID} = {
			isa = PBXTargetDependency;
			target = #{TARGET_ID};
			targetProxy = #{TEST_PROXY_ID};
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		#{DEBUG_CONFIG_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		#{RELEASE_CONFIG_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		#{TARGET_DEBUG_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = WhisperFlow/Info.plist;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "Fluister needs microphone access to record your dictation for local transcription.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fluister.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "WhisperFlow/Sources/App/WhisperFlow-Bridging-Header.h";
				SWIFT_VERSION = 5.0;
				SWIFT_STRICT_CONCURRENCY = minimal;
			};
			name = Debug;
		};
		#{TARGET_RELEASE_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = WhisperFlow/Info.plist;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "Fluister needs microphone access to record your dictation for local transcription.";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fluister.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = "WhisperFlow/Sources/App/WhisperFlow-Bridging-Header.h";
				SWIFT_VERSION = 5.0;
				SWIFT_STRICT_CONCURRENCY = minimal;
			};
			name = Release;
		};
		#{TEST_DEBUG_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fluister.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				SWIFT_STRICT_CONCURRENCY = minimal;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Fluister.app/Contents/MacOS/Fluister";
			};
			name = Debug;
		};
		#{TEST_RELEASE_ID} = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.fluister.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				SWIFT_STRICT_CONCURRENCY = minimal;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Fluister.app/Contents/MacOS/Fluister";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		#{CONFIG_LIST_ID} = {
			isa = XCConfigurationList;
			buildConfigurations = (
				#{DEBUG_CONFIG_ID},
				#{RELEASE_CONFIG_ID},
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		#{TARGET_CONFIG_LIST_ID} = {
			isa = XCConfigurationList;
			buildConfigurations = (
				#{TARGET_DEBUG_ID},
				#{TARGET_RELEASE_ID},
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		#{TEST_CONFIG_LIST_ID} = {
			isa = XCConfigurationList;
			buildConfigurations = (
				#{TEST_DEBUG_ID},
				#{TEST_RELEASE_ID},
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = #{PROJECT_ID};
}
PBXPROJ

File.write(PBXPROJ, pbxproj_content)
puts "Generated #{PBXPROJ}"
puts "Swift files: #{swift_files.length}"
puts "Test files: #{test_files.length}"
