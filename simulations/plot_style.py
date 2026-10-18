"""Shared publication style for all figures (matplotlib skill 'publication' preset, adapted to the report).

Figures are sized at the report text width (160 mm) so fonts appear at their true size in the PDF.
"""
import matplotlib.pyplot as plt

TEXT_WIDTH = 6.3  # [in], A4 with 25 mm margins

# Okabe-Ito colorblind-safe palette
BLUE, ORANGE, GREEN, VERMILION, GREY, BLACK = "#0072B2", "#E69F00", "#009E73", "#D55E00", "#7F7F7F", "#000000"

plt.rcParams.update({
    # Figure
    "figure.figsize": (TEXT_WIDTH, 3.4),
    "figure.dpi": 100,
    "figure.constrained_layout.use": True,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.05,
    "savefig.facecolor": "white",
    # Font: same family as the report body (STIX Two)
    "font.family": "serif",
    "font.serif": ["STIX Two Text", "STIXGeneral", "DejaVu Serif"],
    "mathtext.fontset": "stix",
    "font.size": 10,
    "axes.labelsize": 10,
    "axes.titlesize": 10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 9,
    # Axes
    "axes.linewidth": 0.8,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "axes.grid.axis": "y",
    "axes.axisbelow": True,
    "grid.color": "#E5E5E5",
    "grid.linewidth": 0.6,
    "axes.prop_cycle": plt.cycler(color=[BLUE, ORANGE, GREEN, VERMILION, GREY]),
    # Ticks
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.major.size": 4,
    "ytick.major.size": 4,
    "xtick.major.width": 0.8,
    "ytick.major.width": 0.8,
    # Lines and legend
    "lines.linewidth": 1.8,
    "lines.markersize": 5,
    "legend.frameon": False,
})


def save(fig, path_without_ext):
    """Vector PDF for the report, 300 dpi PNG for quick viewing."""
    fig.savefig(path_without_ext + ".pdf")
    fig.savefig(path_without_ext + ".png")
    plt.close(fig)
