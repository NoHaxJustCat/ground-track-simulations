import calendar
from datetime import datetime, timedelta

import matplotlib.pyplot as plt
import numpy as np

from Ground_track_utilities import *

# ============================== INPUTS ==============================
# Orbit
keplerian_state = [6890000,         # semi_major axis [m]
                   0.010,           # eccentricity
                   52 * np.pi / 180,   # inclination [rad]
                   0.0,             # argument_of_periapsis [rad]
                   0 * np.pi / 180, # longitude_of_ascending_node [rad]
                   0.0]             # true anomaly [rad]

# Spacecraft
reference_area = 0.02725090             # [m^2]
drag_coefficient = 2.2
radiation_pressure_coefficient = 1.2
satellite_mass = 2.2                    # [kg]

# Simulation window (year, month, day, hour, minute, second)
start_date = (2028, 1, 1, 0, 0, 0.0)
end_date = (2028, 3, 1, 0, 0, 0.0)

# Ground station (default: Delft) and visibility condition
observer_latitude_deg = 52.0
observer_longitude_deg = 4.4
min_elevation_deg = 10.0                # visible if elevation >= this

# Output
output_png = os.path.join(OUTPUT_DIR, "ground_track_calendar.png")
show_plot = True
# ====================================================================

J2000 = datetime(2000, 1, 1, 12, 0, 0)


def passes_per_day(starts, ends):
    """Returns {date: (number of passes starting that day, total visible seconds that day)}."""
    stats = {}
    for s, e in zip(starts, ends):
        t0, t1 = J2000 + timedelta(seconds=s), J2000 + timedelta(seconds=e)
        day = t0.date()
        n, tot = stats.get(day, (0, 0.0))
        stats[day] = (n + 1, tot)
        # split the pass across midnight so durations land on the right day
        while t0 < t1:
            midnight = datetime.combine(t0.date() + timedelta(days=1), datetime.min.time())
            seg_end = min(t1, midnight)
            n, tot = stats.get(t0.date(), (0, 0.0))
            stats[t0.date()] = (n, tot + (seg_end - t0).total_seconds())
            t0 = seg_end
    return stats


def plot_calendar(values, title, cbar_label, cmap, fname=None):
    """values: {date: number}. One calendar grid per month."""
    days = sorted(values)
    months = sorted({(d.year, d.month) for d in days})
    start, end = datetime(*start_date[:3]).date(), datetime(*end_date[:3]).date()
    vmax = max(values.values(), default=1) or 1

    ncols = min(3, len(months))
    nrows = int(np.ceil(len(months) / ncols))
    fig, axes = plt.subplots(nrows, ncols, figsize=(5.5 * ncols, 4.3 * nrows), squeeze=False)

    for ax, (y, m) in zip(axes.flat, months):
        grid = np.full((6, 7), np.nan)
        for r, week in enumerate(calendar.monthcalendar(y, m)):
            for c, dom in enumerate(week):
                if dom and start <= datetime(y, m, dom).date() <= end:
                    grid[r, c] = values.get(datetime(y, m, dom).date(), 0)
        im = ax.imshow(grid, cmap=cmap, vmin=0, vmax=vmax)
        for r, week in enumerate(calendar.monthcalendar(y, m)):
            for c, dom in enumerate(week):
                if dom and not np.isnan(grid[r, c]):
                    fg = "white" if grid[r, c] > 0.6 * vmax else "black"
                    ax.text(c, r - 0.28, dom, ha="center", va="center", fontsize=7, color=fg, alpha=0.7)
                    ax.text(c, r + 0.1, f"{grid[r, c]:.0f}", ha="center", va="center", fontsize=10, weight="bold", color=fg)
        ax.set_title(f"{calendar.month_name[m]} {y}")
        ax.set_xticks(range(7), list(calendar.day_abbr))
        ax.set_yticks([])
        ax.tick_params(length=0)
    for ax in list(axes.flat)[len(months):]:
        ax.axis("off")

    fig.colorbar(im, ax=axes, shrink=0.8, label=cbar_label)
    fig.suptitle(title)
    return fig


if __name__ == "__main__":
    time, elevation, _ = run_analysis(keplerian_state=keplerian_state,
                                    reference_area=reference_area,
                                    drag_coefficient=drag_coefficient,
                                    radiation_pressure_coefficient=radiation_pressure_coefficient,
                                    satellite_mass=satellite_mass,
                                    start_date=start_date,
                                    end_date=end_date,
                                    sim_id=1,
                                    observer_latitude_deg=observer_latitude_deg,
                                    observer_longitude_deg=observer_longitude_deg,
                                    min_elevation_deg=min_elevation_deg)

    stats = passes_per_day(*find_passes(time, elevation, min_elevation_deg))
    # fill days without passes with zeros across the whole window
    day, last = datetime(*start_date[:3]).date(), datetime(*end_date[:3]).date()
    while day <= last:
        stats.setdefault(day, (0, 0.0))
        day += timedelta(days=1)

    counts = {d: v[0] for d, v in stats.items()}
    minutes = {d: v[1] / 60 for d, v in stats.items()}

    stem = output_png.rsplit(".", 1)[0]
    fig1 = plot_calendar(counts, "Passes per day", "passes", "Blues")
    fig1.savefig(f"{stem}_count.png", dpi=200)
    fig2 = plot_calendar(minutes, "Total pass duration per day [min]", "minutes", "Oranges")
    fig2.savefig(f"{stem}_duration.png", dpi=200)
    if show_plot:
        plt.show()
