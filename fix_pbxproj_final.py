import re
import sys

with open('ios/Runner.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Remove EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64;
content = re.sub(r'EXCLUDED_ARCHS\[sdk=iphonesimulator\*\] = [^;]+;', '', content)

# Ensure SUPPORTED_PLATFORMS includes iphonesimulator
content = content.replace('SUPPORTED_PLATFORMS = iphoneos;', 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";')

# Ensure IPHONEOS_DEPLOYMENT_TARGET is 15.0
content = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', content)

with open('ios/Runner.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
