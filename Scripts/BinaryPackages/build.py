#!/usr/bin/env python3
"""Build private modules as separate static XCFrameworks; never publish sources."""
import hashlib
import json
import os
import stat
import pathlib
import plistlib
import shutil
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'binary-packages'
WORK = OUT / 'work'
KITS = sorted(p.name for p in (ROOT / 'Packages').iterdir() if (p / 'Package.swift').exists())


def run(*args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def prepare():
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    targets = []
    graph = {}
    for kit in KITS:
        package = json.loads(run('swift', 'package', '--package-path', str(ROOT / 'Packages' / kit), 'dump-package'))
        target = next(t for t in package['targets'] if t['name'] == kit)
        dependencies = []
        names = []
        for dep in target['dependencies']:
            if 'product' in dep:
                name, package_name = dep['product'][:2]
            else:
                name = dep['byName'][0]
                package_name = name
            names.append(name)
            if name in KITS:
                dependencies.append(json.dumps(name))
            else:
                dependencies.append(f'.product(name: "{name}", package: "{package_name}")')
        graph[kit] = names
        shutil.copytree(ROOT / 'Packages' / kit / 'Sources' / kit, WORK / 'Sources' / kit)
        targets.append(f'.target(name: "{kit}", dependencies: [{", ".join(dependencies)}], swiftSettings: [.unsafeFlags(["-enable-library-evolution", "-emit-module-interface"])])')
    manifest = '''// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "MiMiKitsDistribution", platforms: [.macOS(.v26)],
products: [%s], dependencies: [
.package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", exact: "2.1.1"),
.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")
], targets: [%s])
''' % (', '.join(f'.library(name: "{k}", targets: ["{k}"])' for k in KITS), ',\n'.join(targets))
    (WORK / 'Package.swift').write_text(manifest)
    (OUT / 'dependencies.json').write_text(json.dumps(graph, indent=2) + '\n')


def package():
    products = pathlib.Path(run('swift', 'build', '--build-system', 'native', '-c', 'release', '--arch', 'arm64', '--show-bin-path', cwd=WORK))
    artifacts = OUT / 'artifacts'
    artifacts.mkdir(exist_ok=True)
    for kit in KITS:
        framework = OUT / 'frameworks' / f'{kit}.framework'
        if framework.exists():
            shutil.rmtree(framework)
        version = framework / 'Versions' / 'A'
        modules = version / 'Modules' / f'{kit}.swiftmodule'
        modules.mkdir(parents=True)
        objects = sorted((products / f'{kit}.build').glob('*.o'))
        if not objects:
            raise RuntimeError(f'No object files for {kit}')
        run('xcrun', 'libtool', '-static', '-o', str(version / kit), *map(str, objects))
        interface = products / f'{kit}.build' / f'{kit}.swiftinterface'
        if not interface.exists():
            interface = products / 'Modules' / f'{kit}.swiftinterface'
        shutil.copy2(interface, modules / 'arm64-apple-macos.swiftinterface')
        info = dict(CFBundleIdentifier=f'com.senatov.MiMiKits.{kit}', CFBundleName=kit,
                    CFBundleExecutable=kit, CFBundlePackageType='FMWK', CFBundleVersion='1',
                    CFBundleShortVersionString='1.0', MinimumOSVersion='26.0')
        resources = version / 'Resources'
        resources.mkdir()
        (resources / 'Info.plist').write_bytes(plistlib.dumps(info))
        (framework / 'Versions' / 'Current').symlink_to('A')
        for name in (kit, 'Modules', 'Resources'):
            (framework / name).symlink_to(f'Versions/Current/{name}')
        xcframework = artifacts / f'{kit}.xcframework'
        if xcframework.exists():
            shutil.rmtree(xcframework)
        run('xcodebuild', '-create-xcframework', '-framework', str(framework), '-output', str(xcframework))
        with zipfile.ZipFile(artifacts / f'{kit}.xcframework.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for entry in sorted(xcframework.rglob('*')):
                if entry.is_symlink():
                    link = zipfile.ZipInfo(entry.relative_to(artifacts).as_posix())
                    link.create_system = 3
                    link.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(link, os.readlink(entry))
                elif entry.is_file():
                    archive.write(entry, entry.relative_to(artifacts))
    digest = hashlib.sha256()
    for source in sorted((WORK / 'Sources').rglob('*.swift')):
        digest.update(str(source.relative_to(WORK)).encode())
        digest.update(source.read_bytes())
    archive_digest = hashlib.sha256()
    for archive in sorted(artifacts.glob('*.xcframework.zip')):
        archive_digest.update(archive.name.encode())
        archive_digest.update(archive.read_bytes())
    metadata = dict(releaseID=archive_digest.hexdigest()[:16], sourceDigest=digest.hexdigest(), sourceRevision=run('git', '-C', str(ROOT / 'Packages'), 'rev-parse', 'HEAD'),
                    swift=run('swift', '--version'), architecture='arm64', modules=KITS)
    (artifacts / 'build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')


if __name__ == '__main__':
    if sys.argv[1:] == ['prepare']:
        prepare()
    elif sys.argv[1:] == ['package']:
        package()
    else:
        raise SystemExit('Usage: build.py prepare|package')
