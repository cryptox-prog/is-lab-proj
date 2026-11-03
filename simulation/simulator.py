"""Run from repository root: python -m simulation.simulator."""
import argparse
import json
from pathlib import Path
import matplotlib.pyplot as plt
from matplotlib.patches import Wedge, Circle
from matplotlib.widgets import RadioButtons, CheckButtons
from .geometry import Config, MODES, evaluate, user_position


def draw(ax, c, mode, observers, shade=True):
    ax.clear()
    r = c.range_m
    if shade:
        import numpy as np
        # Grid classifies a hypothetical extra observer alongside the user.
        grid = np.linspace(-r, r, 111)
        mask = np.array([[evaluate(c, mode, [(x, y)])[0][0]
                          ['readable_but_undetected'] for x in grid] for y in grid])
        ax.contourf(grid, grid, mask, levels=[0.5, 1.5], colors=['#edaaaa'], alpha=.6)
    def cone(origin, heading, angle, color, label):
        ax.add_patch(Wedge(origin, r, 90-heading-angle/2, 90-heading+angle/2,
                           fill=False, edgecolor=color, label=label))
    cone((0, 0), c.orientation_deg, c.privacy_deg if mode % 2 else c.readable_deg,
         'green', 'Readable sector')
    cone((0, 0), c.orientation_deg, c.fisheye_deg if mode in (2, 3) else c.camera_deg,
         'blue', 'Effective optical sector')
    if mode in (4, 5):
        cone((c.radar_x, c.radar_y), c.radar_orientation_deg, c.radar_deg,
             'purple', 'Radar sector')
        ax.plot(c.radar_x, c.radar_y, 'ms', label='Radar')
    ax.plot(0, 0, 'ks', label='Phone')
    ax.add_patch(Circle(user_position(c), c.body_radius, color='gray', label='User'))
    rows, threat, count = evaluate(c, mode, observers)
    breach = any(row['breach'] for row in rows)
    for i, (point, row) in enumerate(zip(observers, rows)):
        color = 'red' if row['readable_but_undetected'] or row['breach'] else ('orange' if row['detected'] else 'green')
        ax.add_patch(Circle(point, c.body_radius, color=color))
        ax.text(point[0]+.1, point[1], str(i+1))
    ax.set(xlim=(-r-0.8, r+0.3), ylim=(-r*.45, r+.3), aspect='equal',
           xlabel='x (m)', ylabel='y (m)',
           title=f'{MODES[mode]} | {"BREACH" if breach else "SAFE (geometry)"} | '
                 f'{"PROTECT TRIGGER" if threat else "NO TRIGGER"}\n'
                 f'Illustrative geometry; radar targets: {count}\n'
                 f'2D body occlusion: {"ON (opaque circles)" if c.optical_occlusion else "OFF (faces visible)"}')
    ax.legend(loc='lower left', fontsize=7)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path)
    parser.add_argument('--mode', type=int, choices=range(6), default=0)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--backend', choices=('WebAgg', 'TkAgg', 'QtAgg', 'Agg'))
    args = parser.parse_args()
    if args.backend:
        plt.switch_backend(args.backend)
    elif not args.output and plt.get_backend().lower() == 'agg':
        plt.switch_backend('WebAgg')
    data = json.loads(args.config.read_text()) if args.config else {}
    observers = [tuple(p) for p in data.pop('observers', [[.6, .4], [0, .8]])]
    c = Config(**data)
    fig, ax = plt.subplots(figsize=(9, 7))
    mode = [args.mode]
    def redraw():
        draw(ax, c, mode[0], observers)
        fig.canvas.draw_idle()
    if args.output:
        redraw()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(args.output, dpi=220)
        return
    fig.subplots_adjust(right=.70, bottom=.15)
    radio = RadioButtons(fig.add_axes([.72, .52, .27, .4]), MODES, active=args.mode)
    radio.on_clicked(lambda label: (mode.__setitem__(0, MODES.index(label)), redraw()))
    occlusion = CheckButtons(fig.add_axes([.72, .42, .27, .07]),
                            ['Body occlusion (2D)'], [c.optical_occlusion])
    def toggle_occlusion(_):
        c.optical_occlusion = bool(occlusion.get_status()[0])
        redraw()
    occlusion.on_clicked(toggle_occlusion)
    selected = [None]
    def click(event):
        if event.inaxes != ax or event.xdata is None:
            return
        point = (event.xdata, event.ydata)
        near = next((i for i, p in enumerate(observers)
                     if (p[0]-point[0])**2+(p[1]-point[1])**2 < .025), None)
        if event.button == 3:
            if near is not None:
                observers.pop(near)
        elif near is not None:
            selected[0] = near
        else:
            observers.append(point)
        redraw()
    def move(event):
        if selected[0] is not None and event.inaxes == ax and event.xdata is not None:
            observers[selected[0]] = (event.xdata, event.ydata)
            redraw()
    fig.canvas.mpl_connect('button_press_event', click)
    fig.canvas.mpl_connect('motion_notify_event', move)
    fig.canvas.mpl_connect('button_release_event', lambda e: selected.__setitem__(0, None))
    fig.text(.72, .30, 'Click: add; drag: move\nRight click: delete\nRed shading: readable\nbut undetected\nOrange: detected', fontsize=9)
    redraw()
    plt.show()


if __name__ == '__main__':
    main()
