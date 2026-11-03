"""Generate the paper-only architecture figure, showing evidence boundaries."""
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

out = Path(__file__).parent / 'figures'
out.mkdir(exist_ok=True)
fig, ax = plt.subplots(figsize=(7, 3.7))
ax.set(xlim=(0, 10), ylim=(0, 6))
ax.axis('off')
nodes = [
    (0.2, 4.0, 'Front camera\nLocal face count', False),
    (0.2, 2.2, 'Orientation\nNative sensor stream', False),
    (0.2, 0.4, 'External radar\nProposed target count', True),
    (3.7, 2.2, 'Privacy policy\nReauthorization latch', False),
    (3.7, 4.0, 'Owner verification / PIN\nDevice validation pending', False),
    (7.1, 3.5, 'Sensitive pixel gate\nHide on protection', False),
    (7.1, 1.3, 'AES-256-GCM vault\nSession-only content', False),
]
for x, y, label, pending in nodes:
    ax.add_patch(Rectangle((x, y), 2.7, 1.1, facecolor='#f0f3f3',
                           edgecolor='#333333', linestyle='--' if pending else '-'))
    ax.text(x+1.35, y+0.55, label, ha='center', va='center', fontsize=9)
for start, end in [((2.9,4.55),(3.7,2.9)), ((2.9,2.75),(3.7,2.75)),
                   ((2.9,0.95),(3.7,2.5)), ((5.05,4),(5.05,3.3)),
                   ((6.4,2.9),(7.1,4.05)), ((6.4,2.6),(7.1,1.85))]:
    ax.annotate('', xy=end, xytext=start, arrowprops={'arrowstyle':'->','lw':1.1})
fig.tight_layout(pad=0.2)
fig.savefig(out/'architecture.pdf', bbox_inches='tight')
fig.savefig(out/'architecture.png', dpi=220, bbox_inches='tight')
