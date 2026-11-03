"""Generate paper-ready scenario artifacts; no empirical measurements."""
import csv
import json
from dataclasses import asdict, replace
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Wedge
from simulation.geometry import Config, MODES, width, evaluate
from simulation.simulator import draw

OUT = Path(__file__).resolve().parent / 'generated'
DISTANCES = (.35, .40, .55, .60)


def table(name, headers, rows, caption):
    with (OUT / (name + '.csv')).open('w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    def escape(value):
        return str(value).replace('_', r'\_').replace('%', r'\%').replace('&', r'\&')
    lines = [r'\begin{table}[t]', r'\centering', r'\caption{' + caption + '}',
             r'\resizebox{\columnwidth}{!}{%',
             r'\begin{tabular}{' + 'l' * len(headers) + '}', r'\hline',
             ' & '.join(map(escape, headers)) + r' \\', r'\hline']
    lines += [' & '.join(map(escape, row)) + r' \\' for row in rows]
    lines += [r'\hline', r'\end{tabular}}', r'\end{table}']
    (OUT / (name + '.tex')).write_text('\n'.join(lines) + '\n')


def save(fig, name):
    for extension in ('pdf', 'png'):
        fig.savefig(OUT / f'{name}.{extension}', dpi=240, bbox_inches='tight')
    plt.close(fig)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    c = Config()
    (OUT / 'scenario.json').write_text(json.dumps(asdict(c), indent=2) + '\n')
    table('angles', ['Quantity', 'Total degrees', 'Provenance'], [
        ['Camera', 75, 'Illustrative midpoint of 70--80'],
        ['Privacy readability', 60, 'Illustrative assumption'],
        ['Bare screen readability', 160, 'Explicit scenario assumption; unmeasured'],
        ['Fisheye nominal optical', 180, 'Nominal; projection unknown'],
        ['Fisheye effective detection', 120, 'Explicit scenario; unmeasured'],
        ['Radar horizontal', 120, 'Reference scenario'],
        ['Radar vertical', 70, 'Supplied; unverified; not modeled in 2D']],
        'Assumed total angles, not device calibration.')
    rows = [[f'{d:.2f}', f'{width(d, c.camera_deg):.4f}',
             f'{width(d, c.privacy_deg):.4f}', f'{width(d, c.radar_deg):.4f}',
             f'{width(d, c.fisheye_deg):.4f}'] for d in DISTANCES]
    table('coverage_widths', ['Distance (m)', 'Camera (m)', 'Privacy (m)',
                             'Radar (m)', 'Effective fisheye sector (m)'], rows,
          'Calculated plane intersections at reference distances, not measurements. '
          'Radar distances are relative to radar; fisheye values use the 120 degree effective sector.')
    fig, ax = plt.subplots(figsize=(6, 3.6))
    for label, angle, style in [('Camera 75 deg', 75, '-o'), ('Privacy 60 deg', 60, '-s'),
                                ('Radar 120 deg', 120, '-^'),
                                ('Fisheye effective 120 deg', 120, '--x')]:
        ax.plot(DISTANCES, [width(d, angle) for d in DISTANCES], style, label=label)
    ax.set(xlabel='Distance from respective sensor/screen (m)',
           ylabel='Plane intersection width (m)', title='Illustrative angular geometry')
    ax.legend(fontsize=8)
    ax.grid(alpha=.25)
    save(fig, 'coverage_vs_distance')
    observers = [(.60, .40), (0, .80)]
    for mode in range(6):
        fig, ax = plt.subplots(figsize=(6.5, 5.2))
        draw(ax, c, mode, observers)
        save(fig, f'mode_{mode + 1}')
    fig, ax = plt.subplots(figsize=(6.5, 5.2))
    draw(ax, c, 1, [(.60, .40)])
    save(fig, 'safe_case')
    fig, axes = plt.subplots(1, 2, figsize=(11, 5))
    for ax, enabled in zip(axes, (False, True)):
        draw(ax, replace(c, optical_occlusion=enabled), 1, [(0, .8)])
        ax.set_title('75 deg camera / 60 deg readable\n' +
                     ('Body occlusion: residual RBU' if enabled else 'Ideal sectors: zero angular RBU'),
                     fontsize=11)
    fig.tight_layout()
    save(fig, 'angular_geometry')
    fig, ax = plt.subplots(figsize=(6.5, 5.5))
    draw(ax, c, 2, observers)
    ax.add_patch(Wedge((0, 0), c.range_m, 0, 180, fill=False,
                      edgecolor='gray', linestyle='--', label='Nominal optical 180 deg'))
    ax.set_title('Kenko REALPRO nominal 180 deg; projection unknown\n'
                 'Effective 120 deg: unmeasured scenario; sectors only', fontsize=11)
    ax.legend(loc='lower left', fontsize=7)
    save(fig, 'fisheye_geometry')
    fig, ax = plt.subplots(figsize=(6.5, 5.5))
    draw(ax, c, 4, observers)
    ax.set_title('Offset radar: 120 deg horizontal reference sector\n'
                 'Count > 1 triggers; no identity; radar occlusion OFF (optimistic)', fontsize=10)
    save(fig, 'radar_geometry')
    fig, axes = plt.subplots(3, 2, figsize=(12, 13))
    for mode, ax in enumerate(axes.flat):
        draw(ax, c, mode, observers)
        rows, trigger, _ = evaluate(c, mode, observers)
        ax.set_title(MODES[mode] + '\n' +
                     ('BREACH' if any(row['breach'] for row in rows) else 'SAFE (geometry)') +
                     (' | PROTECT TRIGGER' if trigger else ' | NO TRIGGER'), fontsize=10)
        ax.tick_params(labelsize=8)
    fig.suptitle('Illustrative scenarios, not measured performance; red shading = readable but undetected',
                 fontsize=12)
    fig.tight_layout(rect=(0, 0, 1, .97))
    sim_out = Path(__file__).resolve().parents[1] / 'simulation' / 'generated'
    sim_out.mkdir(parents=True, exist_ok=True)
    for extension in ('pdf', 'png'):
        fig.savefig(sim_out / f'scenarios.{extension}', dpi=240, bbox_inches='tight')
    plt.close(fig)
    comparison = []
    classifications = []
    for mode, name in enumerate(MODES):
        results, threat, targets = evaluate(c, mode, observers)
        comparison.append([name, '60' if mode % 2 else '160',
                           '120' if mode in (2, 3) else '75',
                           'count > 1' if mode in (4, 5) else 'none',
                           'yes' if c.optical_occlusion else 'no', 'yes' if mode >= 2 or mode % 2 else 'no'])
        for point, result in zip(observers, results):
            classifications.append([name, *point, *result.values(), threat, targets])
    table('mode_comparison', ['Mode', 'Readable deg', 'Optical deg', 'Radar rule',
                             'Optical occlusion', 'Extra hardware'], comparison,
          'Scenario configuration comparison. All modes are idealized geometry.')
    table('observer_classifications', ['Mode', 'x m', 'y m', 'Readable', 'Optical',
          'Radar', 'Detected', 'Readable but undetected', 'Breach', 'System threat', 'Radar targets'],
          classifications, 'Synthetic observer classifications with optical occlusion disabled; visible central faces are detected.')
    sensitivity = []
    angles = (70, 75, 80, 100, 120, 140, 160, 180, 200)
    # Colocated unobstructed angular model: difference of centered sectors.
    for angle in angles:
        sensitivity.append([angle, max(0, c.readable_deg-angle), max(0, 60-angle),
                            f'{width(.4, angle):.4f}' if angle < 180 else 'not finite'])
    table('angular_sensitivity', ['Effective optical deg', 'Bare RBU deg',
          'Privacy RBU deg', 'Plane width at 0.4 m'], sensitivity,
          'Ideal centered-sector sensitivity without occlusion. RBU denotes readable but undetected. '
          'No tangent width is evaluated at or above 180 degrees.')
    fig, ax = plt.subplots(figsize=(6, 3.4))
    ax.plot(angles, [max(0, c.readable_deg-a) for a in angles], '-o', label='Bare screen 160 deg (assumed)')
    ax.plot(angles, [max(0, 60-a) for a in angles], '-s', label='Privacy screen 60 deg')
    ax.set(xlabel='Assumed effective optical angle (degrees)',
           ylabel='Readable-but-undetected angle (degrees)',
           title='Ideal sectors only; no occlusion')
    ax.legend()
    save(fig, 'angular_sensitivity')
    example = width(.4, 75)
    (OUT / 'worked_example.tex').write_text(
        'Illustrative (not measured): at $d=0.40$ m and total camera angle '
        '$75^\\circ$, $W=2(0.40)\\tan(37.5^\\circ)='
        f'{example:.4f}' + '$ m.\n')
    (OUT / 'manifest.json').write_text(json.dumps({
        'provenance': 'All results are mathematical scenarios, not empirical data',
        'reference_distances_m': DISTANCES,
        'rbu': 'Readable sector minus active sensor visibility, conditional on unprotected content',
        'protection_failure': 'Readable observer with no system threat; distinct from RBU for radar',
        'shading': 'Hypothetical single observer plus designated user, sampled 111 by 111',
        'fisheye_projection': 'Unknown; angular sectors only; no image projection assumed',
        'width_formula': '2*d*tan(total_angle/2); radians internally; angle strictly below 180',
        'outputs': sorted(p.name for p in OUT.iterdir() if p.name != 'manifest.json')
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
