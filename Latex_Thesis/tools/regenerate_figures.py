#!/usr/bin/env python3
"""Regenerate thesis figures from Stata-generated CSV/DTA outputs.

This script does not replace the Stata analysis. It takes the tabular outputs
created by HPV_thesis_merged.do and redraws publication-quality PNG figures for
the LaTeX thesis folder and the Stata output figure folder.
"""
from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pyreadstat

ROOT = Path(__file__).resolve().parents[2]
TABLE_DIR = ROOT / "HPV thesis" / "Output" / "tables"
FIG_LATEX = ROOT / "Latex_Thesis" / "Figures"
FIG_OUTPUT = ROOT / "HPV thesis" / "Output" / "figures"
DATA_CLEAN = ROOT / "HPV thesis" / "Output" / "intermediate" / "hpv_women_15_29_clean.dta"

COLORS = {
    "awareness": "#E69F00",
    "vaccination": "#009E73",
    "gap": "#CC79A7",
    "line": "#444444",
}
plt.rcParams.update({
    "figure.dpi": 180,
    "savefig.dpi": 300,
    "font.family": "DejaVu Sans",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.titleweight": "bold",
    "axes.grid": True,
    "grid.alpha": 0.22,
    "grid.linewidth": 0.8,
    "legend.frameon": False,
})


def save(fig: plt.Figure, name: str) -> None:
    for directory in (FIG_LATEX, FIG_OUTPUT):
        directory.mkdir(parents=True, exist_ok=True)
        fig.savefig(directory / f"{name}.png", bbox_inches="tight", facecolor="white")
    plt.close(fig)


def fmt_p(p: float) -> str:
    if pd.isna(p):
        return ""
    return "<0.001" if p < 0.001 else f"{p:.3f}"


def bars_two(var: str, name: str, title: str, width: float = 0.36) -> None:
    aw = pd.read_csv(TABLE_DIR / "table2_awareness_bivariate.csv")
    vac = pd.read_csv(TABLE_DIR / "table3_vaccination_bivariate.csv")
    aw = aw[aw["variable"].eq(var)].copy()
    vac = vac[vac["variable"].eq(var)].copy()
    labels = aw["category"].tolist()
    x = np.arange(len(labels))
    fig, ax = plt.subplots(figsize=(9.2, 5.2))
    for offset, data, color, label in [(-width/2, aw, COLORS["awareness"], "Heard of HPV vaccine"), (width/2, vac, COLORS["vaccination"], "Received HPV vaccine")]:
        y = data["pct"].to_numpy()
        yerr = np.vstack([y - data["lci"].to_numpy(), data["uci"].to_numpy() - y])
        ax.bar(x + offset, y, width, color=color, label=label, alpha=0.9)
        ax.errorbar(x + offset, y, yerr=yerr, fmt="none", ecolor="#333333", capsize=3, lw=1)
        for xi, yi in zip(x + offset, y):
            ax.text(xi, yi + 2.2, f"{yi:.1f}%", ha="center", va="bottom", fontsize=8)
    ax.set_title(title)
    ax.set_ylabel("Survey-weighted prevalence (%)")
    ax.set_ylim(0, max(92, aw["uci"].max() + 8, vac["uci"].max() + 8))
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=20 if max(map(len, labels)) > 12 else 0, ha="right" if max(map(len, labels)) > 12 else "center")
    ax.legend(loc="upper left", ncol=2)
    ax.text(0.01, -0.24, f"Design-based Pearson p-values: awareness {fmt_p(aw['pvalue'].iloc[0])}; vaccination {fmt_p(vac['pvalue'].iloc[0])}. Error bars show 95% CIs.", transform=ax.transAxes, fontsize=8)
    fig.tight_layout()
    save(fig, name)


def gap_bars(var: str, name: str, title: str) -> None:
    gap = pd.read_csv(TABLE_DIR / "table3b_gap_bivariate.csv")
    gap = gap[gap["variable"].eq(var)].copy()
    labels = gap["category"].tolist()
    x = np.arange(len(labels))
    y = gap["pct"].to_numpy()
    fig, ax = plt.subplots(figsize=(8.8, 5.0))
    ax.bar(x, y, color=COLORS["gap"], alpha=0.9, width=0.62)
    ax.errorbar(x, y, yerr=np.vstack([y-gap["lci"].to_numpy(), gap["uci"].to_numpy()-y]), fmt="none", ecolor="#333333", capsize=4, lw=1)
    for xi, yi in zip(x, y):
        ax.text(xi, yi + 1.1, f"{yi:.1f}%", ha="center", va="bottom", fontsize=8)
    ax.set_title(title)
    ax.set_ylabel("Aware but unvaccinated among aware women (%)")
    ax.set_ylim(0, 105)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=20 if max(map(len, labels)) > 12 else 0, ha="right" if max(map(len, labels)) > 12 else "center")
    ax.text(0.01, -0.22, f"Aware subpopulation; design-based Pearson p-value {fmt_p(gap['pvalue'].iloc[0])}. Error bars show 95% CIs.", transform=ax.transAxes, fontsize=8)
    fig.tight_layout()
    save(fig, name)


def concentration_curve() -> None:
    df, _ = pyreadstat.read_dta(DATA_CLEAN)
    df = df.dropna(subset=["ses", "wmweight", "ccp5_bin", "ccp6_bin"]).sort_values("ses")
    wt = df["wmweight"].to_numpy()
    x = np.cumsum(wt) / wt.sum()
    fig, ax = plt.subplots(figsize=(7.2, 6.0))
    for col, color, label in [("ccp5_bin", COLORS["awareness"], "Awareness"), ("ccp6_bin", COLORS["vaccination"], "Vaccination")]:
        ywt = df[col].to_numpy() * wt
        cy = np.cumsum(ywt) / ywt.sum()
        ax.plot(x, cy, lw=2.6, color=color, label=label)
    ax.plot([0, 1], [0, 1], ls="--", color=COLORS["line"], lw=1.6, label="Equality")
    ax.set_title("Concentration curves for HPV vaccine awareness and uptake")
    ax.set_xlabel("Cumulative share of women ranked by household wealth score")
    ax.set_ylabel("Cumulative share of outcome")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.legend(loc="upper left")
    ax.set_aspect("equal", adjustable="box")
    fig.tight_layout()
    save(fig, "fig7_concentration_curve")


def decomposition(outcome: str, name: str, title: str) -> None:
    df = pd.read_csv(TABLE_DIR / "table6_decomposition.csv")
    d = df[(df["outcome"].eq(outcome)) & (~df["variable"].eq("Residual"))].copy()
    d["abs"] = d["contribution"].abs()
    d = d.nlargest(10, "abs").sort_values("contribution")
    labels = [f"{r.variable_label} ({r.percentage:.1f}%)" for r in d.itertuples()]
    colors = ["#0072B2" if v >= 0 else "#D55E00" for v in d["contribution"]]
    fig, ax = plt.subplots(figsize=(9.8, 5.8))
    ax.barh(labels, d["contribution"], color=colors, alpha=0.88)
    ax.axvline(0, color="#333333", lw=1)
    ax.set_title(title)
    ax.set_xlabel("Contribution to Erreygers concentration index")
    for y, v in enumerate(d["contribution"]):
        ax.text(v + (0.002 if v >= 0 else -0.002), y, f"{v:.4f}", va="center", ha="left" if v >= 0 else "right", fontsize=8)
    ax.text(0.01, -0.15, "Positive values contribute to pro-rich concentration; negative values offset it or indicate pro-poor contribution.", transform=ax.transAxes, fontsize=8)
    fig.tight_layout()
    save(fig, name)


def main() -> None:
    bars_two("Wealth index quintiles", "fig1_awareness_vaccination_by_ses", "HPV awareness and vaccination by household wealth quintile")
    gap_bars("Wealth index quintiles", "fig2_gap_by_ses", "Awareness--vaccination gap by household wealth quintile")
    bars_two("Age", "fig3_awareness_vaccination_by_age", "HPV awareness and vaccination by age group")
    bars_two("Area", "fig4_awareness_vaccination_by_area", "HPV awareness and vaccination by residence")
    bars_two("Education group", "fig5_awareness_vaccination_by_edu", "HPV awareness and vaccination by education")
    bars_two("Ethnic minority", "fig6_awareness_vaccination_by_ethnicity", "HPV awareness and vaccination by ethnicity")
    concentration_curve()
    decomposition("ccp5_bin", "fig8_decomposition_awareness", "Top contributors to inequality in HPV vaccine awareness")
    decomposition("ccp6_bin", "fig9_decomposition_vaccination", "Top contributors to inequality in HPV vaccination")
    decomposition("gap", "fig10_decomposition_gap", "Top contributors to inequality in the awareness--vaccination gap")
    print("Regenerated thesis figures in", FIG_LATEX)


if __name__ == "__main__":
    main()
