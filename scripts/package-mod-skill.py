"""Build a portable pbz-mod-dev skill ZIP from a PBZModLoader checkout."""

import argparse
from pathlib import Path
from subprocess import check_output
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
SKILL = Path('templates/skills/pbz-mod-dev')
TEMPLATE = Path('templates/ts-mod')


def tracked_files(directory):
    paths = check_output(['git', 'ls-files', '-z', '--', directory.as_posix()], cwd=ROOT)
    return (Path(path) for path in paths.decode('utf-8').split('\0') if path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/skills/pbz-mod-dev.zip')
    output = parser.parse_args().output
    skill_entries = ('SKILL.md', 'agents/openai.yaml', 'scripts/new-mod.cjs',
                     'references/game-api.md', 'references/installation.md')
    files = {SKILL / entry: Path(entry) for entry in skill_entries}
    files.update({file: Path('assets/ts-mod') / file.relative_to(TEMPLATE)
                  for file in tracked_files(TEMPLATE)})
    if TEMPLATE / 'vendor/game-api/index.d.ts' not in files:
        parser.error('The checkout must include the template and its tracked SDK.')
    for file in files:
        if not (ROOT / file).is_file():
            parser.error(f'Missing source: {file}')

    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, 'x', ZIP_DEFLATED) as archive:
        for file, entry in files.items():
            archive.write(ROOT / file, (Path('pbz-mod-dev') / entry).as_posix())
    print(output.resolve())


if __name__ == '__main__':
    main()
