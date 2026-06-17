# AH Sniper

A World of Warcraft **retail** addon that finds underpriced Auction House deals
and quick reset flips using **TradeSkillMaster (TSM) AuctionDB** data. It scans
the prices TSM captured at login, compares them to market/historical values, and
shows you what's worth buying.

**Author:** CernalGhost  
**Version:** 1.4.0  
**Slash command:** `/ahs` (or `/ahsniper`)

---

## What it does

- **Deal Finder** — scans every listing in TSM's AuctionDB snapshot and surfaces
  items selling below a reference price (historical, market, or a blend), grouped
  by discount tier and ranked by deal % and profit.
- **Reset Hunter** — finds underpriced, *fast-moving* items worth buying out and
  relisting at market. It only considers items with a high region sale rate and
  meaningful daily sales, ignores armor, and ranks by return on investment after
  the AH cut. Click **Resets** or use `/ahs resets`.
- **Auction House tooltips** — while the AH is open, every item tooltip gains an
  "AH Sniper Prices" block (min buyout, DB Market / Historical / Recent, region
  sale avg, and the deal % vs. profit).
- **Outlier filtering** — hides suspicious data (extreme discounts, inflated
  references, thin liquidity, stale pricing) so the list stays trustworthy.
- **Category, rarity, and value filters**, sortable columns, and a one-click
  **Copy** that gives you AH search text (and can fire the AH search directly).

Grey/poor-quality junk is always hidden.

## Requirements

- Retail WoW (The War Within / Midnight).
- **TradeSkillMaster** with the **TSM AuctionDB** module and its companion app
  (the desktop app downloads the pricing data TSM loads at login).

AH Sniper reads AuctionDB data that TSM has already captured — it does not scan
the live Auction House itself, so prices are as fresh as your last TSM app
download plus a `/reload`.

## Install

1. Copy the `AHSniper` folder to
   `World of Warcraft\_retail_\Interface\AddOns\AHSniper\`
   with `AHSniper.toc` and the `.lua` files directly inside it.
2. Make sure **TradeSkillMaster** is installed and has AuctionDB data.
3. `/reload`.
4. You should see `AH Sniper v1.4.0 loaded. Type /ahs` in chat.

Enable **Load out of date AddOns** if the Interface number lags a patch.

## Usage

| Command | Action |
|---|---|
| `/ahs` | Open the deal list and scan |
| `/ahs scan` | Scan for deals |
| `/ahs resets` | Hunt fast-moving items to buy low and relist at market |
| `/ahs config` | Open settings |
| `/ahs debug` | Show TSM data-capture status |

- **Scan** runs the deal finder; **Resets** runs the reset hunter.
- Click any row (or its **Copy** button) to get AH search text; with the Auction
  House open, **Try AH Search** runs the search for you.
- **Filter** opens rarity / special filters; the left sidebar filters by item
  category; click column headers to sort.

## Settings

Sliders cover minimum deal %, minimum profit, minimum market price, the outlier
thresholds, and the high-value threshold, plus a dropdown for which reference
price drives the deal % (historical, market, region, or a max/avg blend).

Reset Hunter thresholds are stored in `AHSniperDB` and can be tuned directly:
`resetMinSaleRate`, `resetMinSoldPerDay`, `resetMinProfitCopper`,
`resetMinRoiPercent`, `resetAHCutPercent`, and `resetIgnoreArmor`.

## Troubleshooting

- **"AuctionDB data not captured" / no results** — the addon must load *before*
  TradeSkillMaster_AppHelper so it can capture the data blob. Run `/reload`, and
  use `/ahs debug` to confirm captures. Make sure the TSM desktop app has
  downloaded data for your realm/region.
- **"TSM_API was not found"** — TradeSkillMaster isn't loaded; enable it.
- **See Lua errors** — `/console scriptErrors 1` then `/reload`.

## Contributing

Bug reports, feature ideas, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

---

For WoW addon development rules (Midnight / AI agents), see the parent workspace
`docs-for-ai-agents/` folder — not shipped with the package.
