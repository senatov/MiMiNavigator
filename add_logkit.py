#!/usr/bin/env python3
# add_logkit.py — adds LogKit local package to MiMiNavigator.xcodeproj/project.pbxproj

PBXPROJ = "/Users/senat/Develop/MiMiNavigator/MiMiNavigator.xcodeproj/project.pbxproj"

UUID_REF  = "AA000001AA000001AA000001"
UUID_PROD = "AA000002AA000002AA000002"
UUID_FILE = "AA000003AA000003AA000003"

with open(PBXPROJ, "r", encoding="utf-8") as f:
    src = f.read()

# 1. XCLocalSwiftPackageReference
ref_entry = f'\t\t{UUID_REF} /* XCLocalSwiftPackageReference "Packages/LogKit" */ = {{\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = Packages/LogKit;\n\t\t}};\n'
if UUID_REF not in src:
    src = src.replace(
        "/* End XCLocalSwiftPackageReference section */",
        ref_entry + "\t\t/* End XCLocalSwiftPackageReference section */"
    )
    print("+ XCLocalSwiftPackageReference")

# 2. XCSwiftPackageProductDependency
prod_entry = (f'\t\t{UUID_PROD} /* LogKit */ = {{\n'
              f'\t\t\tisa = XCSwiftPackageProductDependency;\n'
              f'\t\t\tpackage = {UUID_REF} /* XCLocalSwiftPackageReference "Packages/LogKit" */;\n'
              f'\t\t\tproductName = LogKit;\n'
              f'\t\t}};\n')
if UUID_PROD not in src:
    if "End XCSwiftPackageProductDependency section" in src:
        src = src.replace(
            "/* End XCSwiftPackageProductDependency section */",
            prod_entry + "\t\t/* End XCSwiftPackageProductDependency section */"
        )
    else:
        src = src.replace(
            "/* Begin XCLocalSwiftPackageReference section */",
            "/* Begin XCSwiftPackageProductDependency section */\n"
            + prod_entry
            + "\t\t/* End XCSwiftPackageProductDependency section */\n\n\t\t/* Begin XCLocalSwiftPackageReference section */"
        )
    print("+ XCSwiftPackageProductDependency")

# 3. packageProductDependencies in PBXNativeTarget
dep_line = f'\t\t\t\t{UUID_PROD} /* LogKit */,\n'
if dep_line not in src:
    src = src.replace(
        '\t\t\t\t52D4533F441E4D78BD910304 /* NetworkKit */,\n\t\t\t);',
        f'\t\t\t\t52D4533F441E4D78BD910304 /* NetworkKit */,\n{dep_line}\t\t\t);'
    )
    print("+ packageProductDependencies")

# 4. PBXBuildFile
build_line = f'\t\t{UUID_FILE} /* LogKit in Frameworks */ = {{isa = PBXBuildFile; productRef = {UUID_PROD} /* LogKit */; }};\n'
if UUID_FILE not in src:
    src = src.replace(
        "FF82030CE1584192AE6E4DEA /* NetworkKit in Frameworks */ = {isa = PBXBuildFile; productRef = 52D4533F441E4D78BD910304 /* NetworkKit */; };",
        "FF82030CE1584192AE6E4DEA /* NetworkKit in Frameworks */ = {isa = PBXBuildFile; productRef = 52D4533F441E4D78BD910304 /* NetworkKit */; };\n\t\t" + build_line.strip()
    )
    print("+ PBXBuildFile")

# 5. Frameworks build phase
fw_ref = "FF82030CE1584192AE6E4DEA /* NetworkKit in Frameworks */,"
fw_new = f'{fw_ref}\n\t\t\t\t{UUID_FILE} /* LogKit in Frameworks */,'
if UUID_FILE + " /* LogKit in Frameworks */" not in src:
    src = src.replace(fw_ref, fw_new)
    print("+ Frameworks build phase")

# 6. PBXProject local package references list
proj_anchor = '9727CDA52F477FF400C4E234 /* XCLocalSwiftPackageReference "Packages/NetworkKit" */,'
proj_new    = proj_anchor + f'\n\t\t\t\t{UUID_REF} /* XCLocalSwiftPackageReference "Packages/LogKit" */,'
if UUID_REF + " /* XCLocalSwiftPackageReference" not in src.split("packageReferences")[1][:500] if "packageReferences" in src else True:
    src = src.replace(proj_anchor, proj_new, 1)
    print("+ PBXProject packageReferences")

with open(PBXPROJ, "w", encoding="utf-8") as f:
    f.write(src)

print("Done.")
