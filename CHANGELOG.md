# AH Sniper Changelog

## 1.4.0

### Added
- **Reset Hunter** — a new scan mode that finds underpriced, fast-moving items
  worth buying out and relisting at market value. Click the **Resets** button
  (or `/ahs resets`). It only surfaces items with a high region sale rate and
  meaningful daily sales, ignores armor, and ranks results by return on
  investment (buy price vs. market, after the AH cut).
- **AH tooltips everywhere** — while the Auction House is open, every item
  tooltip now shows an "AH Sniper Prices" block (min buyout, DB Market /
  Historical / Recent, region sale avg, and the deal % vs. profit), just like
  hovering rows inside the Sniper window.

### Changed
- **Simpler gold amounts** — prices now show as rounded gold with thousands
  separators (e.g. `19,999g`, `700,000g`) instead of `19,999g 00s 00c`.
  Sub-gold values still show silver/copper.

### Fixed
- Grey/poor-quality "junk" items are now reliably hidden even before their item
  data has cached, by also detecting the grey item-link color.
- Repositioned the results scrollbar into the right-hand gutter so it no longer
  floats over the title bar or content.

### Reset Hunter tuning (saved variables)
Defaults can be adjusted in `AHSniperDB`: `resetMinSaleRate` (0.15),
`resetMinSoldPerDay` (1), `resetMinProfitCopper` (50000 = 5g),
`resetMinRoiPercent` (25), `resetAHCutPercent` (5), `resetIgnoreArmor` (true).

## 1.3.0 and earlier

Pre-release development: TSM AuctionDB capture, deal scanner with outlier
filtering, grouped/sortable results UI, category/rarity filters, and AH search
copy. First packaged public release is 1.4.0.
