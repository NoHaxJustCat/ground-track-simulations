import json
import os

import matplotlib.pyplot as plt
import numpy as np
from scipy import stats

from Ground_track_utilities import OUTPUT_DIR, propagate_elevation, find_passes

# ============================== INPUTS ==============================
# Orbit and spacecraft: same as Ground_track_calendar.py
keplerian_state = [6890000, 0.010, 52 * np.pi / 180, 0.0, 0.0, 0.0]
reference_area = 0.02725090             # [m^2]
drag_coefficient = 2.2
radiation_pressure_coefficient = 1.2
satellite_mass = 2.2                    # [kg]

# One full year: ~1900 passes, and covers all RAAN/ground-track phasings
start_date = (2028, 1, 1, 0, 0, 0.0)
end_date = (2029, 1, 1, 0, 0, 0.0)
step_size = 10.0                        # [s], durations agree with 2 s steps to < 0.2 s

# Ground station (Delft)
observer_latitude_deg = 52.0
observer_longitude_deg = 4.4
min_elevation_deg = 10.0                # baseline mask, as in DVS Data Budget
other_elevations_deg = [5.0, 15.0, 20.0]
min_pass_duration_s = 120.0             # passes shorter than this are not scheduled (own assumption, not in data budget)

# Link budget (inputs/Link Budget Da Vinci Cubesat.xlsx, cell C21 of each sheet)
downlink_rate = 9600.0                  # [bit/s] UHF, BPSK
uplink_rate = 2400.0                    # [bit/s] VHF, FSK
# Data budget (inputs/DVS_Data_Budget.pdf)
f_eff = 0.8                             # usable fraction of each pass
ber = 1e-5                              # TRXVU ICD
# name: (payload bytes, total frame bytes, share of time)
downlink_scenarios = {
    "Telemetry only": [(30, 60, 1.0)],
    "Payload only": [(64, 88, 1.0)],
    "Mixed 25/75": [(30, 60, 0.25), (64, 88, 0.75)],
}
uplink_scenarios = {
    "Code / picture chunks": [(64, 95, 1.0)],
    "Full-size frames": [(193, 218, 1.0)],
}
# ====================================================================


def effective_rate(rate, frames):
    """Useful bytes/s: rate x payload efficiency x frame success probability, time-weighted over frame types."""
    return sum(w * rate / 8 * p / tot * (1 - ber) ** (8 * tot) for p, tot, w in frames)


def plot_distribution(values, bins, xlabel, unit, label, fname):
    """Histogram (as density) with fitted normal distribution."""
    mu, sigma = values.mean(), values.std(ddof=1)
    fig, ax = plt.subplots(figsize=(6.4, 3.6))
    ax.hist(values, bins=bins, density=True,
            color="#2a78d6", alpha=0.75, edgecolor="white", linewidth=1, label=label)
    x = np.linspace(bins[0], bins[-1], 400)
    ax.plot(x, stats.norm.pdf(x, mu, sigma), color="#0b0b0b", lw=2, label="Normal fit")
    ax.axvline(mu, color="#52514e", lw=1, ls="--")
    ax.text(0.02, 0.95, f"$\\mu$ = {mu:.2f} {unit}\n$\\sigma$ = {sigma:.2f} {unit}\nN = {len(values)}",
            transform=ax.transAxes, va="top", fontsize=9, color="#52514e")
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Probability density")
    ax.set_xlim(bins[0], bins[-1])
    ax.set_ylim(0, ax.get_ylim()[1] * 1.15)  # headroom for legend
    ax.legend(frameon=False, fontsize=9, loc="upper right")
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    ax.grid(axis="y", color="#e5e4e0", lw=0.6)
    ax.set_axisbelow(True)
    fig.tight_layout()
    fig.savefig(fname + ".pdf")
    fig.savefig(fname + ".png", dpi=200)


if __name__ == "__main__":
    # the propagation takes a few minutes: cache it, delete the file to re-propagate
    cache = os.path.join(OUTPUT_DIR, "elevation_history.npz")
    if os.path.isfile(cache):
        time, elevation, altitude = np.load(cache).values()
    else:
        time, elevation, altitude = propagate_elevation(keplerian_state=keplerian_state,
                                                        reference_area=reference_area,
                                                        drag_coefficient=drag_coefficient,
                                                        radiation_pressure_coefficient=radiation_pressure_coefficient,
                                                        satellite_mass=satellite_mass,
                                                        start_date=start_date,
                                                        end_date=end_date,
                                                        observer_latitude_deg=observer_latitude_deg,
                                                        observer_longitude_deg=observer_longitude_deg,
                                                        step_size=step_size)
        np.savez(cache, time=time, elevation=elevation, altitude=altitude)
    days = round((time[-1] - time[0]) / 86400)

    def summary(min_el):
        """Pass statistics; passes shorter than min_pass_duration_s are dropped. Daily values per UTC day of pass start."""
        s, e = find_passes(time, elevation, min_el)
        d = e - s
        keep = d >= min_pass_duration_s
        s, d = s[keep], d[keep]
        day = ((s - time[0]) // 86400).astype(int)
        per_day = np.bincount(day, minlength=days)
        contact_per_day = np.bincount(day, weights=d, minlength=days)
        return {"min_elevation_deg": min_el, "n_passes": len(d), "n_too_short": int((~keep).sum()),
                "passes_per_day": len(d) / days,
                "mean_s": d.mean(), "std_s": d.std(ddof=1), "min_s": d.min(), "max_s": d.max(),
                "median_s": np.median(d), "p10_s": np.percentile(d, 10), "p90_s": np.percentile(d, 90),
                "passes_per_day_std": per_day.std(ddof=1), "passes_per_day_min": per_day.min(),
                "passes_per_day_max": per_day.max(),
                "contact_s_per_day": contact_per_day.mean(), "contact_s_per_day_std": contact_per_day.std(ddof=1),
                "contact_s_per_day_p10": np.percentile(contact_per_day, 10),
                "contact_s_per_day_min": contact_per_day.min(), "contact_s_per_day_max": contact_per_day.max(),
                }, d, per_day, contact_per_day

    base, durations, per_day, contact_per_day = summary(min_elevation_deg)
    plot_distribution(durations / 60, np.arange(0, 9.01, 0.25), "Pass duration [min]", "min", "Simulated passes",
                      os.path.join(OUTPUT_DIR, "pass_duration_distribution"))
    plot_distribution(per_day, np.arange(per_day.min() - 2.5, per_day.max() + 2.5), "Passes per day", "", "Simulated days",
                      os.path.join(OUTPUT_DIR, "passes_per_day_distribution"))
    plot_distribution(contact_per_day / 60, np.arange(10 * (contact_per_day.min() // 600) - 10, contact_per_day.max() / 60 + 6, 2), "Total pass duration per day [min]",
                      "min", "Simulated days", os.path.join(OUTPUT_DIR, "contact_per_day_distribution"))

    def budget(rate, scenarios):
        out = []
        for name, frames in scenarios.items():
            r = effective_rate(rate, frames)
            out.append({"name": name, "rate_Bps": r,
                        "per_pass_mean_KB": r * base["mean_s"] * f_eff / 1024,
                        "per_pass_p10_KB": r * base["p10_s"] * f_eff / 1024,
                        "per_pass_p90_KB": r * base["p90_s"] * f_eff / 1024,
                        "per_day_MB": r * base["contact_s_per_day"] * f_eff / 1024 ** 2,
                        "per_day_p10_MB": r * base["contact_s_per_day_p10"] * f_eff / 1024 ** 2})
        return out

    results = {
        "sim": {"start": "2028-01-01", "end": "2029-01-01", "days": days, "step_s": step_size,
                "alt_start_km": altitude[0] / 1e3, "alt_end_km": altitude[-1] / 1e3,
                "alt_min_km": altitude.min() / 1e3, "alt_max_km": altitude.max() / 1e3},
        "passes": base,
        "elevation_sweep": [summary(m)[0] for m in sorted([min_elevation_deg] + other_elevations_deg)],
        "inputs": {"downlink_rate": downlink_rate, "uplink_rate": uplink_rate, "f_eff": f_eff, "ber": ber,
                   "min_pass_duration_s": min_pass_duration_s},
        "downlink": budget(downlink_rate, downlink_scenarios),
        "uplink": budget(uplink_rate, uplink_scenarios),
    }
    with open(os.path.join(OUTPUT_DIR, "results.json"), "w") as f:
        json.dump(results, f, indent=2, default=float)
    print(json.dumps(results["passes"], indent=2, default=float))
