#!/usr/bin/env python3
"""
Plot opacity tables similarly to opacity_table.pro, with modifications:
- Outputs both transparent PNG and transparent PDF
- Visualizes kR (Rosseland), kP (Planck), and dust side-by-side

Inputs expected in current directory:
- opacity.in: text header (nitt, nidd, topmin/topmax, dopmin/dopmax[, depletion])
- kR.dat, kP.dat, dust.dat: Fortran unformatted big-endian float64 arrays (nitt x nidd)
- temp_fe_op.data: text with single value for vertical marker

Optional overlays (skipped if files not found or not readable):
- ../OPCD_3.3/border.data (OP border; columns: T, rho_min, rho_max)
- ../Ferguson/border.data (FERGUSON border; columns: idx, T, rho_min, rho_max)
"""

from __future__ import annotations

import struct
from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from mpl_toolkits.axes_grid1.inset_locator import inset_axes


def read_input_dat(path: Path) -> Tuple[int, int, float, float, float, float, float, float]:
    """Read input.dat with log10 ranges: tmp_min tmp_max dtmp rho_min rho_max drho

    Returns: (nitt, nidd, ltmin, ltmax, dlt, lrmin, lrmax, dlr)
    """
    tokens = []
    with path.open("r") as f:
        for line in f:
            parts = line.strip().split()
            for p in parts:
                try:
                    tokens.append(float(p))
                except Exception:
                    pass
    if len(tokens) < 6:
        raise ValueError("input.dat must contain at least 6 numbers: tmp_min tmp_max dtmp rho_min rho_max drho (log10 units)")
    ltmin, ltmax, dlt, lrmin, lrmax, dlr = tokens[:6]
    # Compute counts consistent with Fortran logic
    nitt = int((ltmax - ltmin) / dlt) + 1
    nidd = int((lrmax - lrmin) / dlr) + 1
    return nitt, nidd, ltmin, ltmax, dlt, lrmin, lrmax, dlr


def read_fortran_unformatted_matrix(
    path: Path, nitt: int, nidd: int, dtype: np.dtype = np.dtype(">f8")
) -> np.ndarray:
    """Read a single-record Fortran unformatted array of shape (nitt, nidd).

    Assumes big-endian 64-bit floats as written by gfortran with -fconvert=big-endian
    and a single WRITE of the full array (adds 4-byte record markers around payload).
    """
    with path.open("rb") as f:
        # Leading record marker (4 bytes, big-endian int32)
        head = f.read(4)
        if len(head) != 4:
            raise ValueError(f"{path}: unexpected EOF reading record header")
        (nbytes,) = struct.unpack(">i", head)
        expected = dtype.itemsize * nitt * nidd
        if nbytes != expected:
            raise ValueError(
                f"{path}: record size {nbytes} != expected {expected} for ({nitt}x{nidd})"
            )
        buf = f.read(nbytes)
        if len(buf) != nbytes:
            raise ValueError(f"{path}: unexpected EOF reading payload")
        tail = f.read(4)
        if len(tail) != 4:
            raise ValueError(f"{path}: unexpected EOF reading record trailer")
        (nbytes2,) = struct.unpack(">i", tail)
        if nbytes2 != nbytes:
            raise ValueError(f"{path}: trailer size {nbytes2} != header {nbytes}")

    arr = np.frombuffer(buf, dtype=dtype, count=nitt * nidd)
    # Shape as Fortran (temperature, density)
    arr = np.reshape(arr, (nitt, nidd), order="F")
    return arr


def try_read_border(path: Path, has_index_col: bool = False):
    """Try reading a border file; returns (T, rho_min, rho_max) or None on failure.

    These files start with a line containing the row count.
    OP file: T, rho_min, rho_max
    Ferguson file: idx, T, rho_min, rho_max
    """
    try:
        with path.open("r") as f:
            header = f.readline().strip()
            try:
                n = int(header)
            except Exception:
                n = None
        data = np.loadtxt(path, skiprows=1 if n is not None else 0, max_rows=n)
        if data.ndim == 1:
            data = data[None, :]
        if has_index_col:
            T = data[:, 1]
            rho_min = data[:, 2]
            rho_max = data[:, 3]
        else:
            T = data[:, 0]
            rho_min = data[:, 1]
            rho_max = data[:, 2]
        return T, rho_min, rho_max
    except Exception:
        return None


def compute_sublimation_line(dust: np.ndarray, topmin: float, topmax: float, dopmin: float, dopmax: float):
    """Compute (tsubl, dsubl) as in opacity_table.pro (last T where dust==1 per density)."""
    nitt, nidd = dust.shape
    tsubl = np.full(nidd, np.nan)
    dsubl = np.linspace(dopmin, dopmax, nidd)
    for j in range(nidd):
        # search from high temp to low temp
        idx = None
        for i in range(nitt - 1, -1, -1):
            if dust[i, j] >= 0.5:
                idx = i
                break
        if idx is not None:
            tsubl[j] = topmin + (topmax - topmin) * (idx / (nitt - 1))
    return tsubl, dsubl


def imshow_with_colorbar(ax, img, extent, cmap, vmin=None, vmax=None, tick_size=8,
                         cbar_width="3%", cbar_offset=1.02):
    """Draw imshow and attach a right-hand colorbar sized to axis height.

    Returns the image and colorbar objects.
    """
    im = ax.imshow(
        img,
        origin="lower",
        extent=extent,
        cmap=cmap,
        vmin=vmin,
        vmax=vmax,
        interpolation="nearest",
        aspect="auto",
    )
    cax = inset_axes(
        ax,
        width=cbar_width,
        height="100%",
        loc="lower left",
        bbox_to_anchor=(cbar_offset, 0.0, 1, 1),
        bbox_transform=ax.transAxes,
        borderpad=0,
    )
    cbar = ax.figure.colorbar(im, cax=cax)
    cbar.ax.tick_params(labelsize=tick_size)
    cbar.set_label("")
    return im, cbar


def set_axes_box_aspect(ax, ratio: float, x_span: float, y_span: float):
    """Set per-axes box aspect with fallback for older Matplotlib.

    ratio is height/width; x_span and y_span are data spans for fallback aspect.
    """
    try:
        ax.set_box_aspect(ratio)
    except Exception:
        ax.set_aspect((y_span / x_span) * (1 / ratio), adjustable="box")


def add_overlays(ax, tsubl, dsubl, t_ferguson_max, op_border, fe_border):
    """Add sublimation line, Ferguson vertical line, and OP/FERGUSON domain borders."""
    ax.plot(tsubl, dsubl, color="white", linewidth=2, linestyle="--", alpha=0.9)
    if t_ferguson_max is not None:
        ax.axvline(t_ferguson_max, color="white", linewidth=2, linestyle=":", alpha=0.9)
    if op_border is not None:
        T, rho_min, rho_max = op_border
        ax.plot(T, rho_min, color="white", linewidth=1, linestyle="--")
        ax.plot(T, rho_max, color="white", linewidth=1, linestyle="--")
    if fe_border is not None:
        T, rho_min, rho_max = fe_border
        ax.plot(T, rho_min, color="white", linewidth=1, linestyle="--")
        ax.plot(T, rho_max, color="white", linewidth=1, linestyle="--")


def main():
    root = Path(".")
    header_path = root / "input.dat"
    nitt, nidd, ltmin, ltmax, dlt, lrmin, lrmax, dlr = read_input_dat(header_path)

    kr = read_fortran_unformatted_matrix(root / "kR.dat", nitt, nidd)
    kp = read_fortran_unformatted_matrix(root / "kP.dat", nitt, nidd)
    dust = read_fortran_unformatted_matrix(root / "dust.dat", nitt, nidd)

    # Convert opacities to log10; keep raw for slice plot, and clipped for images
    value_min, value_max = -6.0, 7.0
    with np.errstate(divide="ignore", invalid="ignore"):
        lkr_raw = np.log10(kr)
        lkp_raw = np.log10(kp)
    lkr = np.clip(lkr_raw, value_min, value_max)
    lkp = np.clip(lkp_raw, value_min, value_max)

    # Axes are log10 ranges directly read from input.dat

    # Optional overlays
    t_ferguson_max = None
    tf_path = root / "temp_fe_op.data"
    if tf_path.exists():
        try:
            t_ferguson_max = float(tf_path.read_text().strip().split()[0])
        except Exception:
            t_ferguson_max = None

    op_border = try_read_border(Path("../OPCD_3.3/border.data"), has_index_col=False)
    fe_border = try_read_border(Path("../Ferguson/border.data"), has_index_col=True)

    # Sublimation line from dust
    tsubl, dsubl = compute_sublimation_line(dust, ltmin, ltmax, lrmin, lrmax)

    # Prepare plotting: three panels (kR, kP, dust) with space between them
    fig, axes = plt.subplots(1, 3, figsize=(12, 3))
    fig.patch.set_alpha(0.0)
    for ax in axes:
        ax.set_facecolor((1, 1, 1, 0))
        # Ensure each subplot keeps a 3:4 (height:width) ratio
        try:
            ax.set_box_aspect(3/4)
        except Exception:
            # Fallback for older Matplotlib: approximate via set_aspect
            ax.set_aspect((lrmax - lrmin) / (ltmax - ltmin) * (4/3), adjustable="box")

    # Set extent to exactly the data range (no extra padding)
    extent = [ltmin, ltmax, lrmin, lrmax]
    # Use origin='lower' and transpose to align axes (T on x, rho on y)
    im0, cbar0 = imshow_with_colorbar(axes[0], lkr.T, extent, cmap="viridis", vmin=value_min, vmax=value_max, tick_size=8, cbar_width="3%", cbar_offset=1.02)
    axes[0].set_title(r"log $\kappa_R$ (cm$^2$ g$^{-1}$)")
    axes[0].set_xlabel(r"log T (K)")
    axes[0].set_ylabel(r"log $\rho$ (g cm$^{-3}$)")

    im1, cbar1 = imshow_with_colorbar(axes[1], lkp.T, extent, cmap="viridis", vmin=value_min, vmax=value_max, tick_size=8, cbar_width="3%", cbar_offset=1.02)
    axes[1].set_title(r"log $\kappa_P$ (cm$^2$ g$^{-1}$)")
    axes[1].set_xlabel(r"log T (K)")
    axes[1].set_ylabel(r"log $\rho$ (g cm$^{-3}$)")

    im2, cbar2 = imshow_with_colorbar(axes[2], dust.T, extent, cmap="binary", vmin=0.0, vmax=1.0, tick_size=8, cbar_width="3%", cbar_offset=1.02)
    # Ensure axes limits match data range exactly
    for ax in axes:
        ax.set_xlim(ltmin, ltmax)
        ax.set_ylim(lrmin, lrmax)
    axes[2].set_title("dust (0 no, 1 yes)")
    axes[2].set_xlabel(r"log T (K)")
    axes[2].set_ylabel(r"log $\rho$ (g cm$^{-3}$)")
    cax2 = inset_axes(axes[2], width="3%", height="100%", loc='lower left',
                      bbox_to_anchor=(1.02, 0., 1, 1), bbox_transform=axes[2].transAxes, borderpad=0)
    cbar2 = fig.colorbar(im2, cax=cax2)
    cbar2.ax.tick_params(labelsize=8)
    # Remove colorbar labels (no text)
    for cb in (cbar0, cbar1, cbar2):
        cb.set_label("")

    # Overlays: sublimation line and domain borders
    for ax in axes:
        add_overlays(ax, tsubl, dsubl, t_ferguson_max, op_border, fe_border)

    # Fixed text annotations to match IDL script
    # Positions are in log10 units
    axes[0].text(2.5, -12, 'Semonov', color='white', fontsize=10, rotation=90)
    axes[0].text(3.2, -15, 'Ferguson', color='white', fontsize=10, rotation=90, va='bottom')
    axes[0].text(4.5, -10, 'OP', color='white', fontsize=10)
    axes[1].text(2.5, -12, 'Semonov', color='white', fontsize=10, rotation=90)
    axes[1].text(3.2, -15, 'Ferguson', color='white', fontsize=10, rotation=90, va='bottom')
    axes[1].text(4.5, -10, 'OP', color='white', fontsize=10)

    # Reduce top/bottom whitespace and widen spacing between subplots
    # Increase right margin to avoid clipping colorbar tick labels on the last panel
    fig.subplots_adjust(top=0.97, bottom=0.12, left=0.08, right=0.90, wspace=0.45)
    # Save with transparent background
    out_prefix = "opacity_table"
    fig.savefig(f"{out_prefix}.png", dpi=300, transparent=True)
    fig.savefig(f"{out_prefix}.pdf", transparent=True)
    print(f"Saved {out_prefix}.png and {out_prefix}.pdf with transparent backgrounds.")

    # ------------------------------------------------------------------
    # Slice plot (transparent PDF), matching IDL's slice.eps behavior
    # ------------------------------------------------------------------
    # density slice in log10 units
    d_slice = -6.0
    # build axes arrays in log10 units
    t_log = np.linspace(ltmin, ltmax, nitt)
    # find first j where density >= d_slice
    j_slice = 0
    for j in range(nidd):
        d = lrmin + (lrmax - lrmin) * (j / (nidd - 1))
        j_slice = j
        if d >= d_slice:
            break

    fig2, ax = plt.subplots(figsize=(6, 4.5))
    fig2.patch.set_alpha(0.0)
    ax.set_facecolor((1, 1, 1, 0))

    # base axes and ranges as in IDL
    ax.set_xlim(2.7, 6.0)
    ax.set_ylim(-3.0, 6.0)
    ax.set_xlabel(r"log T (K)")
    ax.set_ylabel(r"log $\kappa$ (cm$^2$ g$^{-1}$)")

    # plot Planck (gray) and Rosseland (default) means at the slice
    ax.plot(t_log, lkp_raw[:, j_slice], color="gray", linewidth=2.5)
    ax.plot(t_log, lkr_raw[:, j_slice], color="C0", linewidth=2.5)

    # additional guide lines from IDL script
    ax.plot([3.75, 4.10], [1.0, 1.0 + 9.0 * (4.10 - 3.75)], linestyle="--", color="k", linewidth=2)
    ax.plot([4.50, 5.30], [4.0, 4.0 - 3.5 * (5.30 - 4.50)], linestyle="--", color="k", linewidth=2)

    # annotate slice density
    ax.text(0.02, 0.02, f"log $\\rho$ = {d_slice}", transform=ax.transAxes)

    fig2.savefig("slice.pdf", transparent=True)
    print("Saved slice.pdf (transparent).")


if __name__ == "__main__":
    main()
