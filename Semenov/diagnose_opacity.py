#!/usr/bin/env python3
import struct
import numpy as np


def _read_record_be_f77(f, marker_bytes=4):
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
        raise ValueError("Record length mismatch")
    return payload


def read_opacity_file(path, marker_bytes=4):
    with open(path, "rb") as f:
        rec = _read_record_be_f77(f, marker_bytes)
        ints = np.frombuffer(rec, dtype=">i4")
        nt, nd = int(ints[0]), int(ints[1])
        rec2 = _read_record_be_f77(f, marker_bytes)
        need = nt + nd + nt * nd
        arr = np.frombuffer(rec2, dtype=">f8", count=need)
        t = arr[:nt].astype(float)
        d = arr[nt : nt + nd].astype(float)
        data = arr[nt + nd :].astype(float).reshape((nt, nd), order="F")
        return t, d, data


def stats(name, t, data, t_thresh=3.0, vmin=-6.0):
    mask = t >= t_thresh
    sub = data[mask, :]
    nan_count = np.isnan(sub).sum()
    total = sub.size
    finite = np.isfinite(sub)
    finite_count = finite.sum()
    if finite_count:
        minv = np.nanmin(sub)
        maxv = np.nanmax(sub)
        under_count = np.sum(sub < vmin)
    else:
        minv = maxv = np.nan
        under_count = 0
    print(f"[{name}] T>=10^{t_thresh} K region:")
    print(f"  size={total}, NaN={nan_count}, finite={finite_count}")
    print(f"  min={minv:.3g}, max={maxv:.3g}")
    print(f"  values < vmin({vmin}) count={under_count}")


def main():
    t, d, ros = read_opacity_file("semenov_ros.data")
    t2, d2, pla = read_opacity_file("semenov_pla.data")
    print(f"t range (log10 K): {t.min():.3f} .. {t.max():.3f}")
    print(f"d range (log10 g/cc): {d.min():.3f} .. {d.max():.3f}")
    stats("ROS", t, ros)
    stats("PLA", t2, pla)


if __name__ == "__main__":
    main()

