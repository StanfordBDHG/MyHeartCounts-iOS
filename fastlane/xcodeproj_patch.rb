#
# This source file is part of the My Heart Counts iOS open-source project
#
# SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#

require "xcodeproj"

# Xcodeproj drops attributes it does not know when it writes a project back, and it does not know
# the traits Xcode records for a package reference or the destination it records for a copy files
# build phase. Fastlane opens and saves the project to set the bundle identifier and the build
# number, so a deployment silently removed the package traits and the destination of the phases
# that embed the watch app and the extensions. Declaring both keeps the round trip lossless.
#
# This can be removed once Xcodeproj knows the attributes itself.
module Xcodeproj
  class Project
    module Object
      class XCRemoteSwiftPackageReference < AbstractObject
        attribute :traits, Array
      end

      class PBXCopyFilesBuildPhase < AbstractBuildPhase
        attribute :dstSubfolder, String
      end
    end
  end
end
