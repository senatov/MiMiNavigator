#!/usr/bin/env python3
"""Generate public SPM wrappers or a source-free local verification checkout."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'binary-packages'
EXTERNAL = {
    'SwiftyBeaver': ('https://github.com/SwiftyBeaver/SwiftyBeaver', '2.1.1', 'SwiftyBeaver'),
    'GRDB': ('https://github.com/groue/GRDB.swift.git', '7.11.1', 'GRDB.swift'),
}


def configure(destination, local):
    graph = json.loads((OUT / 'dependencies.json').read_text())
    revision = json.loads((OUT / 'artifacts' / 'build-info.json').read_text())['releaseID']
    tag = 'kits-' + revision
    for kit, dependencies in graph.items():
        folder = destination / 'BinaryPackages' / kit
        folder.mkdir(parents=True, exist_ok=True)
        packages = []
        products = [f'"{kit}"']
        for dependency in dependencies:
            if dependency in graph:
                packages.append(f'.package(path: "../{dependency}")')
                package_name = dependency
            else:
                url, version, package_name = EXTERNAL[dependency]
                packages.append(f'.package(url: "{url}", exact: "{version}")')
            products.append(f'.product(name: "{dependency}", package: "{package_name}")')
        if local:
            subprocess.run(['ditto', '-x', '-k', str(OUT / 'artifacts' / f'{kit}.xcframework.zip'), str(folder)], check=True)
            binary = f'.binaryTarget(name: "{kit}", path: "{kit}.xcframework")'
        else:
            checksum = hashlib.sha256((OUT / 'artifacts' / f'{kit}.xcframework.zip').read_bytes()).hexdigest()
            url = f'https://github.com/senatov/MiMiNavigator/releases/download/{tag}/{kit}.xcframework.zip'
            binary = f'.binaryTarget(name: "{kit}", url: "{url}", checksum: "{checksum}")'
        manifest = '''// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "%s",
    platforms: [.macOS(.v26)],
    products: [.library(name: "%s", targets: ["%sDependencies"])],
    dependencies: [%s],
    targets: [
        %s,
        .target(name: "%sDependencies", dependencies: [%s])
    ]
)
''' % (kit, kit, kit, ', '.join(packages), binary, kit, ', '.join(products))
        (folder / 'Package.swift').write_text(manifest)
        shutil.copy2(ROOT / 'BinaryPackages' / 'LICENSE.md', folder / 'LICENSE.md')
        sources = folder / 'Sources' / f'{kit}Dependencies'
        sources.mkdir(parents=True, exist_ok=True)
        (sources / 'Dependencies.swift').write_text('// This target connects the binary module to its link dependencies.\n')
    project = destination / 'MiMiNavigator.xcodeproj' / 'project.pbxproj'
    text = project.read_text()
    text = re.sub(r'(?<!Binary)Packages/(' + '|'.join(graph) + r')\b', r'BinaryPackages/\1', text)
    project.write_text(text)
    return tag


def verification_checkout():
    destination = OUT / 'verification'
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir()
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    for name in tracked:
        source = ROOT / name
        if not name or name == '.gitmodules' or name.startswith(('Packages/', 'BinaryPackages/')) or not source.is_file():
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    if (destination / 'Packages').exists():
        raise RuntimeError('Private Packages must not exist in the verification checkout')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', action='store_true', help='Stage public manifests without switching the working project')
    parser.add_argument('--verify', action='store_true', help='Create a source-free checkout with local artifacts')
    args = parser.parse_args()
    if args.stage and args.verify:
        parser.error('--stage and --verify are mutually exclusive')
    destination = verification_checkout() if args.verify else ROOT
    if args.stage:
        destination = OUT / 'public-staging'
        project = destination / 'MiMiNavigator.xcodeproj'
        project.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'MiMiNavigator.xcodeproj' / 'project.pbxproj', project / 'project.pbxproj')
    tag = configure(destination, args.verify)
    print(f'Configured {destination}; release tag: {tag}')
