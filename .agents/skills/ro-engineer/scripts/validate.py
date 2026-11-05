"""Repository-specific skill, reference, and manifest checks; standard library only."""
from pathlib import Path
import json
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SKILL_DIRS = ('references', 'workflows', 'templates', 'agents')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def skill_files(root):
    """An allowlist: never include repository metadata, promo, or build outputs."""
    files = [root / 'SKILL.md', root / 'LICENSE']
    for directory in SKILL_DIRS:
        base = root / directory
        require(base.is_dir() and not base.is_symlink(), f'Invalid directory: {base}')
        # These resources are deliberately flat; new nested layouts need review.
        for path in sorted(base.iterdir()):
            require(not path.is_symlink(), f'Symlink excluded: {path}')
            require(path.is_file(), f'Unexpected resource directory: {path}')
            suffix = '.yaml' if directory == 'agents' else '.md'
            require(path.suffix == suffix, f'Unexpected resource: {path}')
            files.append(path)
    for path in files:
        require(path.is_file() and not path.is_symlink(), f'Missing/unsafe file: {path}')
        require(path.resolve().is_relative_to(root.resolve()), f'Escaped source root: {path}')
    return files


def skill_metadata(path):
    text = path.read_text(encoding='utf-8')
    require(text.startswith('---\n'), f'Missing frontmatter: {path}')
    parts = text.split('---\n', 2)
    require(len(parts) == 3, f'Unclosed frontmatter: {path}')
    # Canonical source intentionally uses only these two scalar YAML fields.
    # This validates our restricted format, not arbitrary YAML.
    rows = parts[1].strip().splitlines()
    require(len(rows) == 2, 'Expected only portable name/description metadata')
    data = {}
    for row in rows:
        key, value = row.split(': ', 1)
        require(key not in data, f'Duplicate metadata: {key}')
        data[key] = json.loads(value) if value.startswith('"') else value
    require(set(data) == {'name', 'description'}, 'Missing/unsupported skill metadata')
    require(re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', data['name']) is not None,
            'Invalid skill name')
    require(len(data['name']) <= 64, 'Skill name too long')
    require(isinstance(data['description'], str) and 0 < len(data['description']) <= 1024,
            'Invalid description')
    require(path.parent.name == data['name'], 'Skill folder/name mismatch')
    return data


def local_links(path, root):
    text = path.read_text(encoding='utf-8')
    for raw in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text):
        target = raw.strip().strip('<>')
        url = urlsplit(target)
        if url.scheme or target.startswith('#'):
            continue
        target = unquote(url.path)
        resolved = (path.parent / target).resolve()
        require(resolved.is_relative_to(root.resolve()), f'Link escapes root: {path}: {raw}')
        require(resolved.exists(), f'Broken link: {path}: {raw}')
    # Legacy inline reference names may be relative to their topic or repository.
    for target in re.findall(r'`([\w./-]+\.md)`', text):
        options = [path.parent / target, root / target, root / 'references' / target]
        require(any(p.is_file() and p.resolve().is_relative_to(root.resolve()) for p in options),
                f'Broken inline reference: {path}: {target}')


def validate(root=ROOT):
    root = Path(root)
    files = skill_files(root)
    metadata = skill_metadata(root / 'SKILL.md')
    for path in files:
        if path.suffix == '.md':
            local_links(path, root)
    for path in [root / 'README.md', *(root / 'docs').glob('*.md')]:
        local_links(path, root)
    claude = json.loads((root / '.claude-plugin/plugin.json').read_text())
    market = json.loads((root / '.claude-plugin/marketplace.json').read_text())
    portable = json.loads((root / 'packaging/openai-plugin.json').read_text())
    require(claude['name'] == portable['name'] == metadata['name'], 'Manifest name mismatch')
    require(claude['version'] == portable['version'], 'Manifest version mismatch')
    version = portable['version']
    require(re.fullmatch(r'\d+\.\d+\.\d+', version) is not None, 'Invalid release version')
    require(f'## v{version} ' in (root / 'CHANGELOG.md').read_text(), 'Missing changelog version')
    require(claude['skills'] == './', 'Claude must discover canonical root skill')
    require(len(market['plugins']) == 1 and market['plugins'][0]['source'] == './'
            and market['plugins'][0]['name'] == metadata['name'], 'Invalid marketplace source')
    require(portable['$schema'] == 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json',
            'Unexpected portable schema')
    allowed = {'$schema', 'name', 'version', 'description', 'author', 'homepage',
               'repository', 'license', 'keywords'}
    require(set(portable) <= allowed, 'Unsupported portable manifest fields')
    require(all(isinstance(portable[k], str) for k in allowed - {'author', 'keywords'}),
            'Invalid portable manifest scalar')
    require(isinstance(portable['author'], dict)
            and set(portable['author']) <= {'name', 'email', 'url'}
            and all(isinstance(v, str) for v in portable['author'].values()), 'Invalid author')
    require(isinstance(portable['keywords'], list)
            and all(isinstance(v, str) for v in portable['keywords']), 'Invalid keywords')
    ui = (root / 'agents/openai.yaml').read_text()
    require(re.fullmatch(r'interface:\n  display_name: "[^"\n]+"\n'
                         r'  short_description: "[^"\n]{25,64}"\n', ui) is not None,
            'Invalid minimal OpenAI display metadata')
    return version, files


if __name__ == '__main__':
    version, files = validate()
    print(f'Validated v{version}: {len(files)} skill files, local references, metadata, manifests')
