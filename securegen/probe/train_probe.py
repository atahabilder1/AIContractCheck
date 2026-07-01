"""
Train the security probe: hidden-state activation -> P(vulnerable).

Deliberately tiny (linear or 1-hidden-layer MLP) so it adds negligible latency
during decoding. Reports AUROC against the Slither teacher labels — that number
is itself a paper result: "a linear probe recovers Slither's judgment with AUROC
X from layer L activations", i.e. vulnerability is linearly decodable from the
model's own representations.

Run:
    python -m securegen.probe.train_probe --in securegen/probe/activations.pt
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default="securegen/probe/activations.pt")
    ap.add_argument("--out", default="securegen/probe/probe.pt")
    ap.add_argument("--arch", choices=["linear", "mlp"], default="mlp")
    ap.add_argument("--epochs", type=int, default=20)
    ap.add_argument("--lr", type=float, default=1e-3)
    args = ap.parse_args()

    import torch
    import torch.nn as nn
    from torch.utils.data import DataLoader, TensorDataset

    data = torch.load(args.inp)
    X, y = data["X"], data["y"]
    groups = data.get("groups")

    # CONTRACT-LEVEL split: all lines of a contract go to the same side, else
    # autocorrelated lines leak across train/test and inflate AUROC. Fall back
    # to a plain sample split only if group ids are missing (legacy caches).
    if groups is not None:
        g = torch.unique(groups)
        perm = torch.randperm(g.shape[0])
        g = g[perm]
        cut_c = int(0.8 * g.shape[0])
        train_c = set(g[:cut_c].tolist())
        tr_mask = torch.tensor([int(gi) in train_c for gi in groups.tolist()])
        Xtr, ytr = X[tr_mask], y[tr_mask]
        Xte, yte = X[~tr_mask], y[~tr_mask]
        print(f"Contract-level split: {cut_c} train / "
              f"{g.shape[0]-cut_c} test contracts")
    else:
        n = X.shape[0]
        idx = torch.randperm(n)
        X, y = X[idx], y[idx]
        cut = int(0.8 * n)
        Xtr, ytr, Xte, yte = X[:cut], y[:cut], X[cut:], y[cut:]

    hidden = X.shape[1]
    if args.arch == "linear":
        probe = nn.Sequential(nn.Linear(hidden, 1))
    else:
        probe = nn.Sequential(
            nn.Linear(hidden, 256), nn.ReLU(), nn.Dropout(0.1), nn.Linear(256, 1))

    # class imbalance: weight positives
    pos = float(ytr.mean().clamp(1e-3, 1 - 1e-3))
    pos_weight = torch.tensor([(1 - pos) / pos])
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
    opt = torch.optim.Adam(probe.parameters(), lr=args.lr)

    dl = DataLoader(TensorDataset(Xtr, ytr), batch_size=512, shuffle=True)
    for ep in range(args.epochs):
        probe.train()
        for xb, yb in dl:
            opt.zero_grad()
            logit = probe(xb).squeeze(-1)
            loss = loss_fn(logit, yb)
            loss.backward()
            opt.step()

    # eval: AUROC
    probe.eval()
    with torch.no_grad():
        scores = torch.sigmoid(probe(Xte).squeeze(-1))
    auroc = _auroc(yte, scores)
    print(f"Test AUROC = {auroc:.3f}  (positives={float(yte.mean()):.3f}, n={len(yte)})")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": probe.state_dict(), "arch": args.arch,
                "hidden": hidden, "layer": data.get("layer"),
                "model": data.get("model"), "auroc": auroc}, args.out)
    print(f"Saved probe -> {args.out}")


def _auroc(y, scores) -> float:
    import torch
    order = torch.argsort(scores, descending=True)
    y = y[order]
    P = float(y.sum())
    N = float((1 - y).sum())
    if P == 0 or N == 0:
        return float("nan")
    tps = torch.cumsum(y, 0)
    fps = torch.cumsum(1 - y, 0)
    tpr = tps / P
    fpr = fps / N
    # trapezoid
    auc = torch.trapz(tpr, fpr)
    return float(auc)


if __name__ == "__main__":
    main()
