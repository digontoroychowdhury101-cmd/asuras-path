"""Build reproducible standalone-skill and portable OpenAI plugin archives."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import zipfile
from validate import ROOT, require, validate


def write_zip(path, entries):
    require(len(entries) == len({n.casefold() for n in entries}), 'Case-colliding paths')
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            posix = PurePosixPath(name)
            require('\\' not in name and not posix.is_absolute() and '..' not in posix.parts,
                    f'Unsafe ZIP path: {name}')
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    verify_zip(path, entries)


def verify_zip(path, expected):
    with zipfile.ZipFile(path) as archive:
        require(len(archive.namelist()) == len(expected)
                and set(archive.namelist()) == set(expected), f'Wrong package contents: {path}')
        require(archive.testzip() is None, f'Corrupt ZIP: {path}')
        for name, data in expected.items():
            require(archive.read(name) == data, f'Package byte mismatch: {name}')


def build(root=ROOT, output=None):
    root = Path(root)
    version, files = validate(root)
    output = Path(output) if output else root / 'dist'
    output.mkdir(parents=True, exist_ok=True)
    canonical = {p.relative_to(root).as_posix(): p.read_bytes() for p in files}
    skill = {f'ro-engineer/{name}': data for name, data in canonical.items()}
    plugin = {f'skills/ro-engineer/{name}': data for name, data in canonical.items()}
    plugin['plugin.json'] = (root / 'packaging/openai-plugin.json').read_bytes()
    plugin['LICENSE'] = (root / 'LICENSE').read_bytes()
    plugin['README.md'] = (
        '# Ro-Engineer\n\n'
        f'Version {version}. Project-aware Roblox/Luau engineering and optional gameplay design.\n\n'
        'See [the skill](skills/ro-engineer/SKILL.md) and [license](LICENSE).\n'
        'This package supplies instructions and references, not MCP connections or Studio access.\n'
        'Installation requires a supported host and permissions. Live import/discovery must be tested.\n'
        'Documentation: https://github.com/excaldev/ro-engineer\n'
    ).encode()
    artifacts = []
    for kind, entries in [('skill', skill), ('openai-plugin', plugin)]:
        path = output / f'ro-engineer-{kind}-v{version}.zip'
        require(not path.is_symlink(), f'Output is a symlink: {path}')
        write_zip(path, entries)
        artifacts.append(path)
    checksums = output / 'SHA256SUMS.txt'
    require(not checksums.is_symlink(), 'Checksum output is a symlink')
    checksums.write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n'
                                for p in artifacts), encoding='utf-8', newline='\n')
    return artifacts


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='Output directory (default: dist)')
    args = parser.parse_args()
    for artifact in build(output=args.output):
        print(artifact)
