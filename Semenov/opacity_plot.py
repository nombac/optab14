#!/usr/bin/env python3
"""
Python port of IDL script opacity.pro

Reads Fortran unformatted (big-endian) binaries:
  - semenov_ros.data (Rosseland-mean opacity)
  - semenov_pla.data (Planck-mean opacity)

and produces side-by-side plots saved as opacity.png and opacity.eps.

Usage:
  python3 opacity_plot.py [--ros FILE] [--pla FILE] [--out-prefix NAME]

Notes:
  - Assumes 4-byte record markers (classic F77). If your files were written
    with 8-byte markers, run with --marker-bytes 8
  - Values are assumed to already be log10-scaled, matching opacity.pro
"""

import os
import struct
import argparse
import numpy as np
import matplotlib.pyplot as plt


def _read_record_be_f77(f, marker_bytes=4):
    """Read one Fortran unformatted record (big-endian) and return its payload.

    Parameters
    ----------
    f : file-like
        Opened binary file handle.
    marker_bytes : int
        Size of the record marker in bytes (4 or 8).

    Returns
    -------
    bytes
        Raw payload bytes of the record.
    """
    marker_fmt = ">i" if marker_bytes == 4 else ">q"
    header = f.read(marker_bytes)
    if len(header) != marker_bytes:
        raise EOFError("Unexpected EOF while reading record header.")
    (nbytes,) = struct.unpack(marker_fmt, header)
    payload = f.read(nbytes)
    if len(payload) != nbytes:
        raise EOFError("Unexpected EOF while reading record payload.")
    trailer = f.read(marker_bytes)
    if len(trailer) != marker_bytes:
        raise EOFError("Unexpected EOF while reading record trailer.")
    (nbytes2,) = struct.unpack(marker_fmt, trailer)
    if nbytes2 != nbytes:
        raise ValueError(f"Record length mismatch: {nbytes} vs {nbytes2}")
    return payload


def read_opacity_file(path, marker_bytes=4):
    """Read Semenov opacity Fortran binary (big-endian).

    Returns
    -------
    t : ndarray shape (nt,)
    d : ndarray shape (nd,)
    data : ndarray shape (nt, nd)
    """
    with open(path, "rb") as f:
        # First record: nt, nd (int32 big-endian)
        rec = _read_record_be_f77(f, marker_bytes=marker_bytes)
        ints = np.frombuffer(rec, dtype=">i4")
        if ints.size < 2:
            raise ValueError("First record must contain nt and nd.")
        nt, nd = int(ints[0]), int(ints[1])

        # Second record: t(nt), d(nd), data(nt*nd) as float64 big-endian
        rec2 = _read_record_be_f77(f, marker_bytes=marker_bytes)
        need = nt + nd + nt * nd
        arr = np.frombuffer(rec2, dtype=">f8", count=need)
        if arr.size != need:
            raise ValueError(
                f"Second record size mismatch: expected {need}, got {arr.size}"
            )
        t = np.array(arr[:nt], dtype=np.float64)
        d = np.array(arr[nt : nt + nd], dtype=np.float64)
        data = np.array(arr[nt + nd :], dtype=np.float64).reshape((nt, nd), order="F")
        return t, d, data


def plot_panel(ax, t, d, data, title, vmin=-6.0, vmax=7.0, cmap="turbo"):
    # Ensure X axis corresponds to T and Y axis to rho.
    # In NumPy/matplotlib, imshow expects array shape (ny, nx). Our data is
    # shaped (nt, nd). IDL treated first dim as X, second as Y. To match
    # "X=T, Y=rho" semantics, transpose to (nd, nt) and use extent=(t_range, d_range).
    extent = (
        float(np.min(t)),
        float(np.max(t)),
        float(np.min(d)),
        float(np.max(d)),
    )
    im = ax.imshow(
        data.T,
        origin="lower",
        interpolation="nearest",
        extent=extent,
        aspect="auto",
        cmap=cmap,
        vmin=vmin,
        vmax=vmax,
    )
    ax.set_xlabel("log (T / K)")
    ax.set_ylabel(r"log ($\rho$ / g cm$^{-3}$)")
    ax.set_title(title)
    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label(title)
    return im


def main():
    parser = argparse.ArgumentParser(
        description="Plot Semenov opacity (Python port of opacity.pro)."
    )
    parser.add_argument("--ros", default="semenov_ros.data", help="Rosseland-mean data file")
    parser.add_argument("--pla", default="semenov_pla.data", help="Planck-mean data file")
    parser.add_argument("--out-prefix", default="opacity", help="Output filename prefix")
    parser.add_argument("--vmin", type=float, default=-6.0, help="Color scale min")
    parser.add_argument("--vmax", type=float, default=7.0, help="Color scale max")
    parser.add_argument(
        "--cmap", default="turbo", help="Matplotlib colormap name (e.g., turbo, viridis)"
    )
    parser.add_argument(
        "--marker-bytes",
        type=int,
        default=4,
        choices=(4, 8),
        help="Fortran record marker size in bytes (4 or 8).",
    )
    args = parser.parse_args()

    if not os.path.exists(args.ros):
        raise FileNotFoundError(f"Not found: {args.ros}")
    if not os.path.exists(args.pla):
        raise FileNotFoundError(f"Not found: {args.pla}")

    # Read datasets
    t_r, d_r, ros = read_opacity_file(args.ros, marker_bytes=args.marker_bytes)
    t_p, d_p, pla = read_opacity_file(args.pla, marker_bytes=args.marker_bytes)

    # Sanity check: grids should match
    if not (np.allclose(t_r, t_p) and np.allclose(d_r, d_p)):
        print(
            "Warning: t/d grids differ between ROS and PLA; using ROS grid for extent."
        )

    # Make figure similar to IDL layout
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), constrained_layout=True)

    title_ros = r"log ($\kappa_R$ / cm$^2$ g$^{-1}$)"
    title_pla = r"log ($\kappa_P$ / cm$^2$ g$^{-1}$)"

    plot_panel(axes[0], t_r, d_r, ros, title_ros, vmin=args.vmin, vmax=args.vmax, cmap=args.cmap)
    plot_panel(axes[1], t_p, d_p, pla, title_pla, vmin=args.vmin, vmax=args.vmax, cmap=args.cmap)

    png_path = f"{args.out_prefix}.png"
    pdf_path = f"{args.out_prefix}.pdf"
    # Save with transparent background as requested
    fig.savefig(png_path, dpi=300, transparent=True)
    fig.savefig(pdf_path, transparent=True)
    print(f"Wrote: {png_path}")
    print(f"Wrote: {pdf_path}")


if __name__ == "__main__":
    main()
