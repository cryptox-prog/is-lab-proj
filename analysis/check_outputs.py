"""Check regenerated numerical tables and artifact completeness."""
import csv
import json
import math
from dataclasses import asdict
from pathlib import Path
from simulation.geometry import Config, MODES, evaluate, width
from .generate import DISTANCES, OUT


def read(name):
    with (OUT / f'{name}.csv').open(newline='') as stream:
        return list(csv.DictReader(stream))


def main():
    c = Config()
    assert json.loads((OUT / 'scenario.json').read_text()) == asdict(c)
    widths = read('coverage_widths')
    assert len(widths) == len(DISTANCES)
    for row, d in zip(widths, DISTANCES):
        assert float(row['Distance (m)']) == d
        for key, angle in [('Camera (m)', c.camera_deg), ('Privacy (m)', c.privacy_deg),
                           ('Radar (m)', c.radar_deg),
                           ('Effective fisheye sector (m)', c.fisheye_deg)]:
            assert math.isclose(float(row[key]), width(d, angle), abs_tol=.000051)
    for row in read('angular_sensitivity'):
        angle = float(row['Effective optical deg'])
        assert float(row['Bare RBU deg']) == max(0, c.readable_deg-angle)
        assert float(row['Privacy RBU deg']) == max(0, c.privacy_deg-angle)
        if angle >= 180:
            assert row['Plane width at 0.4 m'] == 'not finite'
        else:
            assert math.isclose(float(row['Plane width at 0.4 m']), width(.4, angle), abs_tol=.000051)
    classifications = read('observer_classifications')
    assert len(classifications) == 12
    for mode, name in enumerate(MODES):
        exported = [row for row in classifications if row['Mode'] == name]
        points = [(float(row['x m']), float(row['y m'])) for row in exported]
        rows, trigger, targets = evaluate(c, mode, points)
        keys = [('Readable', 'readable'), ('Optical', 'optical'), ('Radar', 'radar'),
                ('Detected', 'detected'), ('Readable but undetected', 'readable_but_undetected'),
                ('Breach', 'breach')]
        for actual, expected in zip(exported, rows):
            for column, field in keys:
                assert actual[column] == str(expected[field])
            assert actual['System threat'] == str(trigger)
            assert int(actual['Radar targets']) == targets
    angles = read('angles')
    assert [float(row['Total degrees']) for row in angles] == [
        c.camera_deg, c.privacy_deg, c.readable_deg, c.fisheye_nominal_deg,
        c.fisheye_deg, c.radar_deg, c.radar_vertical_deg]
    comparison = read('mode_comparison')
    assert len(comparison) == 6
    for mode, row in enumerate(comparison):
        assert row['Mode'] == MODES[mode]
        assert float(row['Readable deg']) == (c.privacy_deg if mode % 2 else c.readable_deg)
        assert float(row['Optical deg']) == (c.fisheye_deg if mode in (2, 3) else c.camera_deg)
        assert row['Radar rule'] == ('count > 1' if mode >= 4 else 'none')
    for name in ('angles', 'coverage_widths', 'mode_comparison',
                 'observer_classifications', 'angular_sensitivity'):
        tex = (OUT / f'{name}.tex').read_text()
        assert r'\begin{table}' in tex and r'\end{table}' in tex
    for name in ('coverage_vs_distance', 'angular_sensitivity', 'safe_case',
                 'angular_geometry', 'fisheye_geometry', 'radar_geometry',
                 *(f'mode_{i}' for i in range(1, 7))):
        assert (OUT / f'{name}.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
        assert (OUT / f'{name}.pdf').read_bytes().startswith(b'%PDF')
    manifest = json.loads((OUT / 'manifest.json').read_text())
    assert manifest['outputs'] == sorted(p.name for p in OUT.iterdir() if p.name != 'manifest.json')
    combined = Path(__file__).resolve().parents[1] / 'simulation' / 'generated'
    assert (combined / 'scenarios.pdf').read_bytes().startswith(b'%PDF')
    assert (combined / 'scenarios.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
    print('PASS: numerical tables, all six mode classifications, scenario, LaTeX snippets, and 26 figure files')


if __name__ == '__main__':
    main()
