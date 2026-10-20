#!/usr/bin/env python3
"""Check generated AAM discovery metadata; run after `quarto render`.

This checks local technical conditions, not Google Scholar inclusion.
Bibliographic baseline: publisher DOI 10.1016/j.jretconser.2026.104814
and the existing accepted manuscript. Uses Python stdlib and pdftotext.
"""
from collections import defaultdict
from hashlib import sha256
from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "_site"
BASE = "https://hikarugoto.com/"
ARTICLE = BASE + "AAM/aam-jrcs-2026/"
PDF = ARTICLE + "aam-jrcs-2026.pdf"
TITLE = "Framing the Attitude-Behavior Gap as Structural Disconnection: A Dual-Level Diagnostic of Customer Experience Quality"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.in_head = False
        self.meta = defaultdict(list)
        self.canonical = []
        self.links = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "head":
            self.in_head = True
        if tag == "meta" and self.in_head:
            self.meta[attrs.get("name", "").lower()].append(attrs.get("content", ""))
        if tag == "link" and "canonical" in attrs.get("rel", "").split():
            self.canonical.append(attrs["href"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])

    def handle_endtag(self, tag):
        if tag == "head":
            self.in_head = False


def check(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)
    print("PASS: " + message)


page = Page(SITE / "AAM/aam-jrcs-2026/index.html")
expected = {
    "citation_title": TITLE,
    "citation_author": "Goto, Hikaru",
    "citation_publication_date": "2026",
    "citation_journal_title": "Journal of Retailing and Consumer Services",
    "citation_issn": "0969-6989",
    "citation_volume": "92",
    "citation_firstpage": "104814",
    "citation_doi": "10.1016/j.jretconser.2026.104814",
    "citation_pdf_url": PDF,
    "citation_fulltext_world_readable": "true",
    "citation_language": "en",
}
for key, value in expected.items():
    check(page.meta[key] == [value], key + " appears once in head with verified value")
check(page.canonical == [ARTICLE], "single canonical uses directory URL")
check(urlparse(PDF).path.rsplit("/", 1)[0] + "/" == urlparse(ARTICLE).path,
      "PDF and abstract are in the same directory")
check(PDF in [urljoin(ARTICLE, link) for link in page.links], "abstract has static PDF link")
for name in ("robots", "googlebot", "googlebot-news"):
    check(not any(re.search(r"\b(noindex|none)\b", value, re.I) for value in page.meta[name]),
          "no indexing block in " + name + " meta")

for path in ("index.html", "publications.html", "en/index.html"):
    source_url = urljoin(BASE, path)
    links = [urljoin(source_url, link) for link in Page(SITE / path).links]
    check(ARTICLE in links and PDF in links, path + " links to canonical abstract and PDF")
    check(ARTICLE + "index.html" not in links, path + " avoids alternate abstract link")

robots = RobotFileParser()
robots.parse((SITE / "robots.txt").read_text().splitlines())
for url in (BASE, BASE + "publications.html", ARTICLE, PDF):
    check(robots.can_fetch("Googlebot", url), "robots allows " + url)
check(BASE + "sitemap.xml" in (robots.site_maps() or []), "robots declares sitemap")
locations = [node.text for node in ET.parse(SITE / "sitemap.xml").iter()
             if node.tag.endswith("}loc")]
check(locations.count(ARTICLE) == 1 and ARTICLE + "index.html" not in locations,
      "sitemap lists one canonical abstract URL")

pdf = ROOT / "AAM/aam-jrcs-2026/aam-jrcs-2026.pdf"
data = pdf.read_bytes()
check(len(data) < 5_000_000, "PDF below 5 MB: " + str(len(data)) + " bytes")
check(sha256(data).digest() == sha256((SITE / pdf.relative_to(ROOT)).read_bytes()).digest(),
      "generated PDF is byte-identical to source")
original = subprocess.check_output(["git", "show", "HEAD:" + str(pdf.relative_to(ROOT))], cwd=ROOT)
check(data == original, "AAM PDF unchanged from HEAD")
text = subprocess.check_output(["pdftotext", "-layout", str(pdf), "-"], text=True)
normalized = " ".join(text.split())
check(TITLE in normalized and "Goto, H." in normalized, "PDF title and author citation extract correctly")
check("References" in text and "Abstract" in text, "PDF abstract and references are searchable")
check("CC BY-NC-ND 4.0" in text, "existing PDF license is retained")

# Exercise the actual post-render script in an isolated fixture.
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp) / "_site"
    fixture.mkdir()
    sitemap = fixture / "sitemap.xml"
    sitemap.write_text("<urlset><loc>" + ARTICLE + "index.html</loc><loc>" + BASE + "publications.html</loc></urlset>")
    subprocess.run(["bash", str(ROOT / "scripts/normalize-sitemap.sh")], cwd=tmp, check=True)
    check(sitemap.read_text() == "<urlset><loc>" + ARTICLE + "</loc><loc>" + BASE + "publications.html</loc></urlset>",
          "sitemap normalizer removes only directory index.html")
print("PDF SHA-256:", sha256(data).hexdigest())
