"""Piste shaping: groomed profile + modelled jumps, baked into height.r32 (game/data/streif/jumps.json).

The summer DGM has crests that would launch a rider 80-90 m at race speed and lacks the shaped
kickers/landings of the real course. ``jumps.json`` (editable, created from config defaults if
missing) describes, along the centre line s:

* ``groom``: per-section design speeds. Crests are cut where a rider at that speed would lift off
  harder than ``crest_g`` (v^2*kappa > crest_g*g*cos), hollows are filled where the compression
  would exceed ``comp_g``.
* ``jumps``: lip position, design speed and target length. The landing hill follows the ballistic
  trajectory (tuck drag) with a small impact angle at the target distance; the run-out blends back
  into the terrain with bounded compression load. Too fast -> lands on the flat -> hard landing.

Inside the corridor the surface is rebuilt as a prepared piste: shaped profile(s) plus a smooth
quadratic cross profile fitted to the terrain, blended into the natural terrain at the edge
(``FADE_M``). Rendered terrain and physics height field stay identical (both read height.r32).
Idempotent: always starts from derived/height_base.npy written by process_terrain.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import ndimage

import config
from common import read_json, write_json
from geo import grid_shape, sample_bilinear, write_r32
from process_terrain import gradient_stats

DERIVED = config.RAW / "derived"
G = 9.81
FULL_EXTRA_M = 4.0  # full offset up to corridor edge + this
FADE_M = 14.0  # then fade to zero over this distance


def default_spec() -> dict:
    return {
        "note": "Editable piste shaping. s = horizontal distance along line.json (m). Re-run "
                "tools/pipeline/process_shaping.py (and godot --headless --import) after edits.",
        "design": {"mass_kg": 95.0, "air_density": 1.05, "cda_tuck_m2": 0.16, "mu": 0.03},
        "groom": {"crest_g": 1.35, "comp_g": 2.6, "speeds_kmh": config.SHAPING_GROOM_SPEEDS_KMH},
        "jumps": config.SHAPING_JUMPS,
    }


def _speed_profile(s: np.ndarray, named: list[dict], speeds: dict) -> np.ndarray:
    v = np.full(len(s), speeds.get("Start", 100.0))
    for sec in named:
        v[s >= sec["s"]] = speeds.get(sec["name"], v[s >= sec["s"]][0] if (s >= sec["s"]).any() else 100.0)
    v = ndimage.gaussian_filter1d(v, 15.0, mode="nearest")
    return v / 3.6


def groom(h: np.ndarray, ds: float, v: np.ndarray, crest_g: float, comp_g: float,
          frozen: np.ndarray, iters: int = 4000) -> np.ndarray:
    """Cut crests / fill hollows until the curvature limits hold (red-black relaxation)."""
    h = h.copy()
    for _ in range(iters):
        changed = 0.0
        for parity in (1, 2):
            i = np.arange(parity, len(h) - 1, 2)
            slope = (h[i + 1] - h[i - 1]) / (2 * ds)
            cos = 1.0 / np.sqrt(1.0 + slope ** 2)
            arc = (1.0 + slope ** 2) ** 1.5  # kappa = h'' / arc
            crest_lim = crest_g * G * cos / v[i] ** 2 * arc * ds * ds
            comp_lim = np.maximum(comp_g - cos, 0.2) * G / v[i] ** 2 * arc * ds * ds
            d2 = h[i - 1] - 2 * h[i] + h[i + 1]
            cut = (d2 < -crest_lim) & ~frozen[i]
            fill = (d2 > comp_lim) & ~frozen[i]
            new = h[i].copy()
            new[cut] = (h[i - 1][cut] + h[i + 1][cut] + crest_lim[cut]) / 2.0
            new[fill] = (h[i - 1][fill] + h[i + 1][fill] - comp_lim[fill]) / 2.0
            changed = max(changed, float(np.abs(new - h[i]).max(initial=0.0)))
            h[i] = new
        if changed < 1e-4:
            break
    return h


def trajectory(s0: float, y0: float, slope: float, v0: float, design: dict, s_max: float) -> tuple:
    """Ballistic flight in the vertical plane along s (tuck drag). Returns s, y, dy/ds, speed."""
    k = 0.5 * design["air_density"] * design["cda_tuck_m2"] / design["mass_kg"]
    ang = -math.atan(slope)
    vx, vy = v0 * math.cos(ang), v0 * math.sin(ang)
    x, y, dt = s0, y0, 0.002
    xs, ys, ss, vs = [x], [y], [vy / vx], [v0]
    while x < s_max:
        sp = math.hypot(vx, vy)
        vx += -k * sp * vx * dt
        vy += (-G - k * sp * vy) * dt
        x += vx * dt
        y += vy * dt
        xs.append(x)
        ys.append(y)
        ss.append(vy / vx)
        vs.append(math.hypot(vx, vy))
    return np.array(xs), np.array(ys), np.array(ss), np.array(vs)


def shape_jump(s: np.ndarray, h: np.ndarray, jump: dict, design: dict) -> tuple[np.ndarray, float, float]:
    """Landing hill + run-out for one jump. Returns new profile and the shaped [s_lip, s_end]."""
    ds = s[1] - s[0]
    s_lip, v0, length = jump["s_lip"], jump["v_kmh"] / 3.6, jump["length_m"]
    beta = math.tan(math.radians(jump.get("impact_deg", 6.0)))
    ramp = jump.get("knoll_m", 10.0)
    i_lip = int(np.searchsorted(s, s_lip))
    # straight approach ramp: removes small natural kickers so the real take-off angle is the design one
    i_a = max(1, i_lip - int(round(jump.get("approach_m", 14.0) / ds)))
    h = h.copy()
    h[i_a:i_lip + 1] = np.linspace(h[i_a], h[i_lip], i_lip + 1 - i_a)
    slope0 = (h[i_lip] - h[i_a]) / (s[i_lip] - s[i_a])  # dy/ds (< 0 downhill)
    y_lip = h[i_lip] + jump.get("lip_m", 0.0)
    tx, ty, tsl, tv = trajectory(s[i_lip], y_lip, -slope0, v0, design, s[i_lip] + length + 5)
    s_land = s[i_lip] + length
    traj_y = np.interp(s, tx, ty)
    out = h.copy()
    if jump.get("lip_m", 0.0) > 0.0:  # kicker: raise the approach towards the lip
        kl = jump.get("kicker_len_m", 15.0)
        w = np.clip((s - (s[i_lip] - kl)) / kl, 0.0, 1.0)
        m = (s <= s[i_lip]) & (s >= s[i_lip] - kl)
        out[m] = h[m] + jump["lip_m"] * w[m] ** 2
    zone = (s > s[i_lip]) & (s <= s_land)
    c = beta * (s_land - s) * np.clip((s - s[i_lip]) / ramp, 0.0, 1.0)
    land = traj_y - c
    out[zone] = land[zone]  # built landing hill: knoll after the lip, then the trajectory minus a wedge
    # run-out: cubic Hermite from the landing tangent back to the terrain, bounded compression
    i_l = int(np.searchsorted(s, s_land))
    y_l = land[i_l]
    slope_l = float(np.interp(s_land, tx, tsl)) + beta
    v_l = float(np.interp(s_land, tx, tv))
    comp_g = jump.get("runout_g", 2.4)
    best = None
    for t_len in np.arange(20.0, 260.0, 4.0):
        i_e = int(np.searchsorted(s, s[i_l] + t_len))
        if i_e >= len(s) - 3:
            break
        y_e = h[i_e]
        slope_e = (h[i_e + 2] - h[i_e - 2]) / (s[i_e + 2] - s[i_e - 2])
        u = (s[i_l:i_e + 1] - s[i_l]) / (s[i_e] - s[i_l])
        L = s[i_e] - s[i_l]
        h00, h10 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u
        h01, h11 = -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
        seg = h00 * y_l + h10 * L * slope_l + h01 * y_e + h11 * L * slope_e
        d1 = np.gradient(seg, ds)
        d2 = np.gradient(d1, ds)
        kappa = d2 / (1 + d1 ** 2) ** 1.5
        load = 1.0 / np.sqrt(1 + d1 ** 2) + v_l ** 2 * np.maximum(kappa, 0) / G
        crest = v_l ** 2 * np.maximum(-kappa, 0) / G - 1.0 / np.sqrt(1 + d1 ** 2)
        score = max(load.max() - comp_g, 0.0) + max(crest.max(), 0.0)
        if best is None or score < best[2]:
            best = (i_e, seg, score)
        if score == 0.0:
            break
    i_e, seg, score = best
    if score > 0.0:
        print(f"[shaping] WARNING {jump.get('name', '?')}: run-out exceeds limits by {score:.2f} g")
    out[i_l:i_e + 1] = seg
    return out, s[i_lip], s[i_e]


def main() -> None:
    out_dir = config.OUT
    spec_path = out_dir / "jumps.json"
    if not spec_path.exists():
        write_json(spec_path, default_spec())
        print("[shaping] wrote default jumps.json")
    spec = read_json(spec_path)
    meta = read_json(out_dir / "meta.json")
    ext_def = read_json(DERIVED / "extent.json")
    core = ext_def["core"]
    base = np.load(DERIVED / "height_base.npy")
    near = np.load(DERIVED / "near_idx.npy")
    corridor = np.load(DERIVED / "corridor_dist.npy")
    line_doc = read_json(out_dir / "line.json")
    line = np.asarray(line_doc["points"], dtype=float)
    named = read_json(out_dir / "sections.json")["sections"]
    e = line[:, 0] + meta["origin_e0"]
    n = meta["origin_n0"] - line[:, 2]
    s = line[:, 3]
    ds = float(s[1] - s[0])
    h0 = sample_bilinear(base, core, e, n)

    design = spec["design"]
    v = _speed_profile(s, named, spec["groom"]["speeds_kmh"])
    frozen = np.zeros(len(s), dtype=bool)
    frozen[:3] = True
    frozen[-3:] = True
    prof = h0.copy()
    shaped = []
    for jump in spec["jumps"]:
        prof, a, b = shape_jump(s, prof, jump, design)
        frozen |= (s >= a - 6.0) & (s <= b)
        shaped.append((jump["name"], a, b))
        print(f"[shaping] {jump['name']}: lip {a:.0f} m, shaped to {b:.0f} m")
    prof = groom(prof, ds, v, spec["groom"]["crest_g"], spec["groom"]["comp_g"], frozen)
    dh = prof - h0
    print(f"[shaping] profile offsets {dh.min():.2f} .. {dh.max():.2f} m")

    # Rebuild the corridor surface; every vertex needs a smooth (s, d) coordinate along the line.
    rows, cols = grid_shape(core)
    gx = meta["core"]["world_min_x"] + np.arange(cols, dtype=np.float64) * meta["core"]["res_m"]
    gz = meta["core"]["world_min_z"] + np.arange(rows, dtype=np.float64) * meta["core"]["res_m"]
    lat = np.clip(1.0 - (corridor - FULL_EXTRA_M) / FADE_M, 0.0, 1.0)
    lat = lat * lat * (3 - 2 * lat)
    rr, cc = np.nonzero(lat > 0.0)
    idx = np.minimum(near[rr, cc], len(s) - 1)
    tan = np.gradient(line[:, [0, 2]], axis=0)
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    px, pz = gx[cc], gz[rr]
    # Projection along interpolated vertex normals: X = P(t) + d*N(t) with P, T lerped between the
    # vertices of a segment. Unlike nearest-point projection on the polyline (which leaves constant-s
    # wedges on the outside of every vertex -> a staircase profile), s is smooth on both sides.
    best_d = np.full(len(idx), np.inf)
    s_cell = np.zeros(len(idx))
    rel_x = np.zeros(len(idx))
    rel_z = np.zeros(len(idx))
    seg_i = np.zeros(len(idx), dtype=np.int64)
    pts = line[:, [0, 2]]
    for off in range(-5, 5):  # the rasterised nearest vertex can be a few vertices off
        i0 = np.clip(idx + off, 0, len(s) - 2)
        ax_, az_ = pts[i0, 0], pts[i0, 1]
        dx_, dz_ = pts[i0 + 1, 0] - ax_, pts[i0 + 1, 1] - az_
        ta_x, ta_z = tan[i0, 0], tan[i0, 1]
        dtx, dtz = tan[i0 + 1, 0] - ta_x, tan[i0 + 1, 1] - ta_z
        ex, ez = px - ax_, pz - az_
        qa = -(dx_ * dtx + dz_ * dtz)
        qb = ex * dtx + ez * dtz - (dx_ * ta_x + dz_ * ta_z)
        qc = ex * ta_x + ez * ta_z
        with np.errstate(divide="ignore", invalid="ignore"):
            disc = np.sqrt(np.maximum(qb * qb - 4 * qa * qc, 0.0))
            lin = np.abs(qa) < 1e-9
            t1 = np.where(lin, -qc / qb, (-qb + disc) / (2 * qa))
            t2 = np.where(lin, -qc / qb, (-qb - disc) / (2 * qa))
        for t in (t1, t2):
            ok = np.isfinite(t) & (t >= -1e-6) & (t <= 1 + 1e-6)
            t = np.clip(np.nan_to_num(t), 0.0, 1.0)
            fx, fz = ax_ + dx_ * t, az_ + dz_ * t
            dist2 = (px - fx) ** 2 + (pz - fz) ** 2
            better = ok & (dist2 < best_d)
            best_d[better] = dist2[better]
            s_cell[better] = (s[i0] + (s[i0 + 1] - s[i0]) * t)[better]
            rel_x[better], rel_z[better] = (px - fx)[better], (pz - fz)[better]
            seg_i[better] = i0[better]
    missing = ~np.isfinite(best_d)
    if missing.any():  # fallback (line ends, inside of folds): nearest vertex + its tangent
        mi = idx[missing]
        rx, rz = px[missing] - pts[mi, 0], pz[missing] - pts[mi, 1]
        s_cell[missing] = s[mi] + rx * tan[mi, 0] + rz * tan[mi, 1]
        rel_x[missing], rel_z[missing] = rx, rz
        seg_i[missing] = mi
        print(f"[shaping] {int(missing.sum())} cells use the nearest-vertex fallback")
    idx = seg_i
    s_cell[near[rr, cc] >= len(s)] = s[-1] + 1.0  # run-out beyond the finish: no shaping
    # Prepared piste: inside the corridor the surface is rebuilt as profile(s) + c1(s)*d + c2(s)*d^2
    # (cross profile fitted to the terrain and smoothed along s). Natural edges that run oblique to
    # the line (and would launch a rider who is off the centre line) are thereby groomed away;
    # kickers, knolls and landings run square to the line. Fades into the terrain at the edge.
    nrm = np.stack([-tan[:, 1], tan[:, 0]], axis=1)  # right of travel in (x, z)
    width = np.interp(s, [sec["s"] for sec in named], [sec["width_m"] for sec in named])
    width = ndimage.gaussian_filter1d(width, 20.0 / ds)
    offs = np.linspace(-1.0, 1.0, 9)
    samples = np.empty((len(s), len(offs)))
    for k, o in enumerate(offs):
        d = o * (width / 2.0 + FULL_EXTRA_M)
        samples[:, k] = sample_bilinear(base, core, e + nrm[:, 0] * d, n - nrm[:, 1] * d)
    c1 = np.empty(len(s))
    c2 = np.empty(len(s))
    for i in range(len(s)):
        d = offs * (width[i] / 2.0 + FULL_EXTRA_M)
        coef = np.polyfit(d, samples[i] - samples[i, 4], 2)
        c2[i], c1[i] = coef[0], coef[1]
    sig = config.SHAPING_CROSS_SIGMA_M / ds
    c1 = ndimage.gaussian_filter1d(c1, sig, mode="nearest")
    c2 = ndimage.gaussian_filter1d(c2, sig, mode="nearest")
    d_cell = rel_x * nrm[idx, 0] + rel_z * nrm[idx, 1]
    built = np.interp(s_cell, s, prof) + np.interp(s_cell, s, c1) * d_cell \
        + np.interp(s_cell, s, c2) * d_cell ** 2
    inside = (s_cell >= s[0]) & (s_cell <= s[-1])
    height = base.astype(np.float64)
    delta = np.where(inside, built - base[rr, cc], 0.0)
    # Inside tight turns the corridor is wider than the turn radius: the nearest-vertex mapping folds
    # and s jumps between neighbouring cells -> steps in the built surface. Smooth delta there.
    full = np.zeros(base.shape)
    full[rr, cc] = delta * lat[rr, cc]
    s_grid = np.full(base.shape, np.nan)
    s_grid[rr, cc] = s_cell
    jump_s = np.zeros(base.shape, dtype=bool)
    jump_s[:, 1:] |= np.abs(np.diff(s_grid, axis=1)) > 3.0
    jump_s[1:, :] |= np.abs(np.diff(s_grid, axis=0)) > 3.0
    fold = ndimage.binary_dilation(jump_s, iterations=int(config.SHAPING_FOLD_BLEND_M))
    wf = ndimage.gaussian_filter(fold.astype(np.float64), config.SHAPING_FOLD_BLEND_M / 3.0)
    smooth = ndimage.gaussian_filter(full, config.SHAPING_FOLD_SIGMA_M)
    full = full * (1.0 - wf) + smooth * wf
    print(f"[shaping] fold cells: {int(jump_s.sum())}")
    height += full
    height = height.astype(np.float32)
    assert height.shape == grid_shape(core)
    write_r32(out_dir / "height.r32", height)

    # line y and stats on the shaped surface
    y = sample_bilinear(height, core, e, n)
    line[:, 1] = y
    line_doc["points"] = [[round(float(a), 3), round(float(b), 3), round(float(c), 3), round(float(d), 2)]
                          for a, b, c, d in line]
    write_json(out_dir / "line.json", line_doc)
    x, z = line[:, 0], line[:, 2]
    s3 = np.concatenate([[0.0], np.cumsum(np.sqrt(np.diff(x) ** 2 + np.diff(z) ** 2 + np.diff(y) ** 2))])
    st = read_json(out_dir / "line_stats.json")
    g10, g10_at = gradient_stats(s, y, 10.0)
    g50, g50_at = gradient_stats(s, y, 50.0)
    st.update({
        "length_3d_m": round(float(s3[-1]), 1), "start_alt_m": round(float(y[0]), 1),
        "finish_alt_m": round(float(y[-1]), 1), "drop_m": round(float(y[0] - y[-1]), 1),
        "mean_gradient_pct": round(float((y[0] - y[-1]) / s[-1] * 100), 1),
        "max_gradient_10m_pct": round(g10 * 100, 1), "max_gradient_10m_at_s": round(g10_at, 0),
        "max_gradient_50m_pct": round(g50 * 100, 1), "max_gradient_50m_at_s": round(g50_at, 0),
        "shaped": [{"name": nm, "s_lip": round(a, 1), "s_end": round(b, 1)} for nm, a, b in shaped],
        "shaping_offset_range_m": [round(float(dh.min()), 2), round(float(dh.max()), 2)],
    })
    write_json(out_dir / "line_stats.json", st)
    print(f"[shaping] max gradient {g10 * 100:.0f} % at s={g10_at:.0f}")


if __name__ == "__main__":
    main()
