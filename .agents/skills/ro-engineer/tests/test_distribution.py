"""Exercise distribution boundaries, reference failures, and canonical-byte parity."""
from pathlib import Path
import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from validate import validate

# Avoid the reserved keyword/module name ambiguity for package.py.
spec = importlib.util.spec_from_file_location('skill_package', ROOT / 'scripts/package.py')
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)


class DistributionTests(unittest.TestCase):
    def setUp(self):
        # Keep fixtures within the checkout, including on restricted Windows hosts.
        fixture_parent = ROOT / 'dist'
        fixture_parent.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix='test-', dir=fixture_parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'ro-engineer'
        shutil.copytree(ROOT, self.root, ignore=shutil.ignore_patterns('.git', 'dist', '__pycache__'))

    def test_packages_preserve_canonical_bytes_and_exclude_repository_noise(self):
        (self.root / 'promo').mkdir()
        (self.root / 'promo/private.md').write_text('DO NOT PACKAGE')
        (self.root / '.mcp.json').write_text('{"secret": "not a connector"}')
        artifacts = packaging.build(self.root)
        _, files = validate(self.root)
        with zipfile.ZipFile(artifacts[0]) as skill, zipfile.ZipFile(artifacts[1]) as plugin:
            self.assertEqual(len(skill.namelist()), len(files))
            self.assertEqual(len(plugin.namelist()), len(files) + 3)
            for path in files:
                relative = path.relative_to(self.root).as_posix()
                self.assertEqual(skill.read('ro-engineer/' + relative), path.read_bytes())
                self.assertEqual(plugin.read('skills/ro-engineer/' + relative), path.read_bytes())
            self.assertNotIn('skills', json.loads(plugin.read('plugin.json')))
            self.assertTrue(all('\\' not in p and not p.startswith('/') for p in plugin.namelist()))
            # Extract and validate resource links in the actual plugin payload.
            extracted = Path(self.temp.name) / 'extracted'
            plugin.extractall(extracted)
            from validate import local_links
            for path in extracted.rglob('*.md'):
                skill_root = extracted / 'skills/ro-engineer'
                local_links(path, skill_root if path.is_relative_to(skill_root) else extracted)
            from validate import skill_metadata
            self.assertEqual(skill_metadata(skill_root / 'SKILL.md')['name'], 'ro-engineer')

    def test_build_is_reproducible(self):
        first = [p.read_bytes() for p in packaging.build(self.root)]
        second = [p.read_bytes() for p in packaging.build(self.root)]
        self.assertEqual(first, second)

    def test_broken_reference_blocks_build(self):
        with (self.root / 'SKILL.md').open('a') as stream:
            stream.write('\n[missing](references/missing.md)\n')
        with self.assertRaisesRegex(ValueError, 'Broken link'):
            packaging.build(self.root)

    def test_version_mismatch_blocks_build(self):
        path = self.root / 'packaging/openai-plugin.json'
        data = json.loads(path.read_text())
        data['version'] = '9.9.9'
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'version mismatch'):
            packaging.build(self.root)

    def test_reference_escape_blocks_build(self):
        with (self.root / 'SKILL.md').open('a') as stream:
            stream.write('\n[escape](../outside.md)\n')
        with self.assertRaisesRegex(ValueError, 'escapes root'):
            packaging.build(self.root)

    def test_unexpected_runtime_file_blocks_build(self):
        (self.root / 'references/credentials.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'Unexpected resource'):
            packaging.build(self.root)


if __name__ == '__main__':
    unittest.main()
