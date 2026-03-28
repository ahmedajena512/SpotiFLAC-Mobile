import re
import os

with open('ios/Runner.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 1. Add File Reference if not present
if 'Gobackend.xcframework' not in content:
    # Find PBXFileReference section
    file_ref_match = re.search(r'/\* Begin PBXFileReference section \*/\n', content)
    if file_ref_match:
        ref_line = 'AndroidManifest.xml'7F1A2B3C4D5E6F7A8B9C0D1E /* Gobackend.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = Gobackend.xcframework; path = Frameworks/Gobackend.xcframework; sourceTree = "<group>"; };\n'
        content = content[:file_ref_match.end()] + ref_line + content[file_ref_match.end():]

# 2. Add to Frameworks group
# Look for the "Custom" group or just the main group
group_match = re.search(r'/\* Custom \*/ = \{\s+isa = PBXGroup;\s+children = \(', content)
if not group_match:
    group_match = re.search(r'/\* Frameworks \*/ = \{\s+isa = PBXGroup;\s+children = \(', content)

if group_match and '7F1A2B3C4D5E6F7A8B9C0D1E' not in content[group_match.start():group_match.start()+500]:
    content = content[:group_match.end()] + '\n7F1A2B3C4D5E6F7A8B9C0D1E /* Gobackend.xcframework */,' + content[group_match.end():]

# 3. Add to Frameworks Build Phase
build_phase_match = re.search(r'/\* Begin PBXFrameworksBuildPhase section \*/\n.*?files = \(', content, re.DOTALL)
if build_phase_match and '7F1A2B3C4D5E6F7A8B9C0D1E' not in content[build_phase_match.start():build_phase_match.start()+1000]:
    build_file_id = '7F1A2B3C4D5E6F7A8B9C0D1F'
    # Add to PBXBuildFile section
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/\n', content)
    if build_file_section:
        build_file_line = '' + build_file_id + ' /* Gobackend.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = 7F1A2B3C4D5E6F7A8B9C0D1E /* Gobackend.xcframework */; };\n'
        content = content[:build_file_section.end()] + build_file_line + content[build_file_section.end():]
    
    # Add to build phase files list
    files_list_match = re.search(r'/\* Begin PBXFrameworksBuildPhase section \*/\n.*?files = \(', content, re.DOTALL)
    if files_list_match:
        content = content[:files_list_match.end()] + '\n' + build_file_id + ' /* Gobackend.xcframework in Frameworks */,' + content[files_list_match.end():]

with open('ios/Runner.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
