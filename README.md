# Google First-Page Job Search (Ruby on Morph.io)

Scrapes the **first Google results page** for a boolean query that targets Lever job posts, then saves results to Morph.io SQLite via `scraperwiki`.

> Heads-up: Google can block automated requests or change markup. This script is best-effort. If you hit consent/CAPTCHA pages, consider a search API (e.g., SerpAPI) or a different engine.

## Default query

Defined in `scraper.rb`:

