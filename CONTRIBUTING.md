# Contributing to AH Sniper

Thanks for helping improve AH Sniper. This project is open to bug reports, feature ideas, and pull requests.

## Before you start

- Search [existing issues](https://github.com/CernalGhost/AHSniper/issues) to avoid duplicates.
- For gameplay questions, use [Discussions](https://github.com/CernalGhost/AHSniper/discussions) or open an issue with the **question** label.
- AH Sniper is a **retail** addon and requires **TradeSkillMaster** with AuctionDB data.

## Reporting bugs

Use the [bug report template](https://github.com/CernalGhost/AHSniper/issues/new?template=bug_report.yml) and include:

- WoW client version and addon version (chat on `/reload`)
- TSM version and whether `/ahs debug` shows AuctionDB data captured
- Steps to reproduce (deal scan vs. reset hunter vs. tooltips)
- Lua errors if any (`/console scriptErrors 1`, then `/reload`)

## Suggesting features

Use the [feature request template](https://github.com/CernalGhost/AHSniper/issues/new?template=feature_request.yml). Explain the gold-making or shopping workflow you want to improve.

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Make focused changes. Match the existing Lua style across the module files.
3. Test in-game with TSM loaded: `/reload`, `/ahs scan`, `/ahs resets`, open the AH and hover tooltips.
4. Update `CHANGELOG.md` under an `## Unreleased` section (or the next version if you are bumping the `.toc`).
5. Open a PR against `main` and fill out the pull request template.

### WoW addon constraints

- AH Sniper reads TSM AuctionDB snapshots captured at login; it does not live-scan the AH.
- `EarlyHook.lua` must load before `TradeSkillMaster_AppHelper` to capture data — preserve load order in `AHSniper.toc`.

## Development setup

```text
World of Warcraft\_retail_\Interface\AddOns\AHSniper\
  AHSniper.toc
  Core.lua
  ...
```

Install **TradeSkillMaster** and ensure the desktop app has downloaded AuctionDB data for your realm.

## Releases

Maintainers tag versions matching `## Version:` in `AHSniper.toc` (e.g. `v1.4.0`). Pushing a tag runs the GitHub Actions packager and creates a release zip.

## License

By contributing, you agree that your contributions are licensed under the same [MIT License](LICENSE) as the project.
