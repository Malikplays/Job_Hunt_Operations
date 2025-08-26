import os
import time
import urllib.parse
import requests
from bs4 import BeautifulSoup
import scraperwiki  # morph.io helper for SQLite

GOOGLE_SEARCH_URL = "https://www.google.com/search"

# ---- 1) Build your Boolean query ----
QUERY = (
    'site:https://jobs.lever.co "Remote" AND '
    '("Fulltime" OR "Full Time" OR "Full-Time") AND '
    '("Customer support specialist" OR "Customer Support")'
)

# ---- 2) HTTP options ----
HEADERS = {
    # A realistic desktop UA helps avoid getting the "lite" HTML or blocks
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
}

PARAMS = {
    "q": QUERY,
    "hl": "en",
    "num": "10",   # Google usually caps at 10 results per page
    "start": "0",  # first page
    "filter": "0", # show similar results too (optional)
}

def get_html(url: str, params: dict) -> str:
    """Fetch search HTML."""
    resp = requests.get(url, params=params, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    return resp.text

def parse_results(html: str):
    """
    Parse Google result cards robustly.
    Returns list of dicts: {title, link, snippet, rank}
    """
    soup = BeautifulSoup(html, "lxml")

    results = []

    # Strategy:
    # - Primary: result blocks have 'div.g' with an 'a' that wraps an <h3>.
    # - Backup: look for <a> tags that contain an <h3>, which is common in Google's markup.
    rank = 0

    # Prefer explicit cards first
    cards = soup.select("div.g")
    if not cards:
        # Fallback: search anchors with h3 inside
        cards = [a.parent for a in soup.select("a h3") if a and a.parent and a.parent.name == "a"]

    # Helper to extract snippet from nearby nodes
    def extract_snippet(card):
        # Known snippet classes (Google changes these often)
        snippet_classes = [
            "VwiC3b",      # current common
            "aCOpRe",      # older
            "IsZvec",      # container, holds VwiC3b
        ]
        # Try common containers first
        for cls in snippet_classes:
            node = card.select_one(f".{cls}")
