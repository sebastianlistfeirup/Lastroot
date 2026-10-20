#!/usr/bin/env python3
"""LR-27: which cards, relics, mutations and champion paths the bot ends runs
with, and the win rate when it has them. Flags anything present in >= 90 % of
runs of a faction ("dominates every choice") for human review.
Reads evidence/balance/balance_report_<tag>.json; writes evidence/balance/picks_<tag>.md.
Usage: python3 tools/balance/pick_report.py [tag ...]   (default: greedy casual greedy_hard casual_hard)"""
import collections, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
B = os.path.join(ROOT, "evidence", "balance")


def report(tag):
    path = os.path.join(B, "balance_report_%s.json" % tag)
    if not os.path.exists(path):
        return None
    d = json.load(open(path))
    lines = ["# Valg i bot-runs: `%s`" % tag, "", "Kilde: `%s` (%s). Bot er regressionssignal, ikke bevis for sjov." % (os.path.basename(path), d.get("bot", "")), ""]
    flags = []
    for fac in ("BARK", "SPORE"):
        runs = [r for r in d["runs"] if r["faction"] == fac]
        if not runs:
            continue
        n = len(runs)
        cats = {"Kort i slutdæk (antal runs)": [], "Relikvier": [], "Mutationer": [], "Championretning": []}
        for r in runs:
            cats["Kort i slutdæk (antal runs)"].append(set(r["deck"]))
            cats["Relikvier"].append(set(r["relics"]))
            cats["Mutationer"].append(set(r["mutations"]))
            cats["Championretning"].append({r["path"].split(" ")[0] or "(ingen)"})
        wins = sum(1 for r in runs if r["won"])
        lines += ["## %s — %d runs, %d sejre" % (fac, n, wins), ""]
        for cat, sets in cats.items():
            cnt = collections.Counter(x for s in sets for x in s)
            lines += ["**%s**" % cat, "", "| Valg | I runs | Andel | Sejre med |", "|---|---|---|---|"]
            for item, c in sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0])):
                w = sum(1 for r, s in zip(runs, sets) if item in s and r["won"])
                lines.append("| %s | %d | %d %% | %d/%d |" % (item, c, round(100 * c / n), w, c))
                upgraded_or_relic = cat != "Kort i slutdæk (antal runs)" or item.endswith("+")
                if c / n >= 0.9 and upgraded_or_relic and cat != "Championretning":
                    flags.append("%s %s: %s i %d %% af runs" % (fac, cat, item, round(100 * c / n)))
            lines.append("")
    lines += ["## Mulige dominerende valg (≥ 90 %, kun opgraderinger/relikvier/mutationer)", ""]
    lines += ["- " + f for f in flags] or ["- ingen"]
    lines += ["", "Bemærk: botten (scripts/domain/bot/auto_player.gd) vælger kun *kort* ud fra værdi. Relikvier, mutationer, championretning og lejr-opgradering tager den **første** mulighed (M01 og M02 er altid først, Root Sprout er første opgraderbare kort i dækket). Disse andele siger derfor intet om styrke; mål dem med mennesker (docs/PLAYTEST_GUIDE.md). Kort i startdækket står i alle runs og er ikke et fund."]
    out = os.path.join(B, "picks_%s.md" % tag)
    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return out, flags


def main():
    tags = sys.argv[1:] or ["greedy", "casual", "greedy_hard", "casual_hard"]
    for t in tags:
        r = report(t)
        if r is None:
            print("PICKS %s: no report (run tools/balance/run_balance.gd first)" % t)
        else:
            print("PICKS %s -> %s, %d flags" % (t, os.path.relpath(r[0], ROOT), len(r[1])))


if __name__ == "__main__":
    main()
