"""Check whether this patch was committed after the pinned source revision."""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def run_git(tree, *args, data=None):
    return subprocess.run(['git', '-C', str(tree), *args], input=data,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout


def main():
    source, tree, manifest, patch = map(Path, sys.argv[1:])
    project_path = tree.resolve().relative_to(source.resolve()).as_posix()
    projects = ET.parse(manifest).getroot().findall('project')
    baseline = next((p.get('revision') for p in projects
                     if p.get('path', p.get('name')) == project_path), None)
    if baseline is None or not re.fullmatch(r'[0-9a-f]{40}', baseline):
        raise ValueError(f'No pinned source revision for {project_path}')
    ancestor = subprocess.run(['git', '-C', str(tree), 'merge-base', '--is-ancestor', baseline, 'HEAD'])
    if ancestor.returncode == 1:
        return 1
    ancestor.check_returncode()
    desired = run_git(tree, 'patch-id', '--stable', data=patch.read_bytes()).split()
    if not desired:
        raise ValueError(f'No diff in {patch}')
    changes = run_git(tree, 'log', '--format=medium', '--no-renames', '--patch', f'{baseline}..HEAD')
    recorded = run_git(tree, 'patch-id', '--stable', data=changes)
    return 0 if any(line.split()[0] == desired[0] for line in recorded.splitlines()) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError, ET.ParseError) as error:
        print(f'Patch history check failed: {error}', file=sys.stderr)
        sys.exit(2)
