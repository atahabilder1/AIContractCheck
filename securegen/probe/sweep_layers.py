"""
Layer sweep: find which residual-stream layer best exposes vulnerability.

One forward pass per contract already computes ALL layers (out.hidden_states),
so we grab several layers at once instead of re-running the model per layer.
For each layer we train a linear probe over K contract-level splits and report
mean +/- sd AUROC. Picks the layer to wire into the steered decoder.

Run:
    python -m securegen.probe.sweep_layers \
        --model Qwen/Qwen2.5-Coder-7B-Instruct --llm qwen \
        --layers 4,8,12,16,18,20,24,28 --seeds 6
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from .extract_activations import (
    AGG, _build_line_index, _line_starts, _char_to_line)


def _auroc(y, scores):
    import torch
    order = torch.argsort(scores, descending=True)
    y = y[order]
    P = float(y.sum()); N = float((1 - y).sum())
    if P == 0 or N == 0:
        return float("nan")
    tpr = torch.cumsum(y, 0) / P
    fpr = torch.cumsum(1 - y, 0) / N
    return float(torch.trapz(tpr, fpr))


def _train_eval_linear(X, y, groups, seed, epochs=20):
    import torch, torch.nn as nn
    from torch.utils.data import DataLoader, TensorDataset
    g = torch.unique(groups)
    gen = torch.Generator().manual_seed(seed)
    g = g[torch.randperm(g.shape[0], generator=gen)]
    cut = int(0.8 * g.shape[0])
    train_c = set(g[:cut].tolist())
    tr = torch.tensor([int(gi) in train_c for gi in groups.tolist()])
    Xtr, ytr, Xte, yte = X[tr], y[tr], X[~tr], y[~tr]

    probe = nn.Sequential(nn.Linear(X.shape[1], 1))
    pos = float(ytr.mean().clamp(1e-3, 1 - 1e-3))
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=torch.tensor([(1 - pos) / pos]))
    opt = torch.optim.Adam(probe.parameters(), lr=1e-3)
    dl = DataLoader(TensorDataset(Xtr, ytr), batch_size=512, shuffle=True,
                    generator=gen)
    for _ in range(epochs):
        for xb, yb in dl:
            opt.zero_grad()
            loss_fn(probe(xb).squeeze(-1), yb).backward()
            opt.step()
    with torch.no_grad():
        scores = torch.sigmoid(probe(Xte).squeeze(-1))
    return _auroc(yte, scores)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="Qwen/Qwen2.5-Coder-7B-Instruct")
    ap.add_argument("--llm", default="qwen")
    ap.add_argument("--layers", default="4,8,12,16,18,20,24,28")
    ap.add_argument("--seeds", type=int, default=6)
    ap.add_argument("--max-length", type=int, default=4096)
    ap.add_argument("--out", default="securegen/probe/layer_sweep.pt")
    args = ap.parse_args()

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    layers = [int(x) for x in args.layers.split(",")]
    line_index = _build_line_index()

    tok = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForCausalLM.from_pretrained(
        args.model, torch_dtype=torch.float16, device_map="auto",
        output_hidden_states=True)
    model.eval()

    with open(AGG) as f:
        rows = [r for r in csv.DictReader(f)
                if r["llm"] == args.llm
                and str(r.get("compiled", "")).lower() in ("true", "1")]
    print(f"{len(rows)} compiled {args.llm} contracts; layers {layers}")

    per_layer = {L: [] for L in layers}
    labels, gids = [], []
    for cid, row in enumerate(rows):
        fp = row["filepath"]
        if not Path(fp).exists():
            continue
        code = Path(fp).read_text()
        flagged = line_index.get(fp, set())
        starts = _line_starts(code)
        enc = tok(code, return_tensors="pt", return_offsets_mapping=True,
                  truncation=True, max_length=args.max_length)
        offsets = enc.pop("offset_mapping")[0]
        with torch.no_grad():
            out = model(**{k: v.to(model.device) for k, v in enc.items()})

        last_tok_of_line = {}
        for t in range(offsets.shape[0]):
            sc, ec = int(offsets[t][0]), int(offsets[t][1])
            if sc == 0 and ec == 0:
                continue
            last_tok_of_line[_char_to_line(sc, starts)] = t
        for line, t in last_tok_of_line.items():
            for L in layers:
                per_layer[L].append(out.hidden_states[L][0, t].float().cpu())
            labels.append(1 if line in flagged else 0)
            gids.append(cid)
        if (cid + 1) % 50 == 0:
            print(f"  {cid+1}/{len(rows)} contracts, {len(labels)} samples")

    y = torch.tensor(labels, dtype=torch.float32)
    groups = torch.tensor(gids, dtype=torch.long)
    results = {}
    print(f"\n{len(labels)} samples, {float(y.mean()):.3f} positive\n"
          f"{'layer':>6} {'mean':>7} {'sd':>6}")
    for L in layers:
        X = torch.stack(per_layer[L])
        aucs = torch.tensor([_train_eval_linear(X, y, groups, s)
                             for s in range(args.seeds)])
        m, sd = float(aucs.mean()), float(aucs.std())
        results[L] = (m, sd)
        print(f"{L:>6} {m:>7.3f} {sd:>6.3f}")

    best = max(results, key=lambda L: results[L][0])
    print(f"\nBEST layer = {best}  AUROC = {results[best][0]:.3f}")
    torch.save({"results": results, "layers": layers, "y_mean": float(y.mean()),
                "model": args.model, "best": best}, args.out)


if __name__ == "__main__":
    main()
