# frozen_string_literal: true

require "uri"
require "cgi"
require "net/http"
require "openssl"
require "nokogiri"
require "scraperwiki"

GOOGLE_SEARCH_URL = "https://www.google.com/search"

QUERY = 'site:https://jobs.lever.co "Remote" AND ("Fulltime" OR "Full Time" OR "Full-Time") AND ("Customer support specialist" OR "Customer Support")'

HEADERS = {
  "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
  "Accept-Language" => "en-US,en;q=0.9"
}.freeze

PARAMS = {
  q: QUERY,
  hl: "en",
  num: "10",     # first page (Google caps at ~10)
  start: "0",
  filter: "0"
}.freeze

def build_url(base, params)
  uri = URI(base)
  uri.query = URI.encode_www_form(params)
  uri.to_s
end

def http_get(url, headers = {})
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  req = Net::HTTP::Get.new(uri.request_uri)
  headers.each { |k, v| req[k] = v }

  res = http.request(req)
  raise "HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
  res.body
end

def google_redirect_to_real(url)
  # e.g. /url?q=https://real.example&sa=...
  return url unless url.start_with?("/url?")
  u = URI.parse(url)
  qs = CGI.parse(u.query.to_s)
  real = qs["q"]&.first
  real && !real.empty? ? real : nil
rescue
  nil
end

def extract_snippet(card)
  %w[VwiC3b aCOpRe IsZvec].each do |klass|
    node = card.at_css(".#{klass}")
    txt = node&.text&.strip
    return txt.gsub(/\s+/, " ") if txt && !txt.empty?
  end

  card.css("div").each do |div|
    txt = div.text.to_s.strip.gsub(/\s+/, " ")
    return txt if txt.length.between?(30, 500)
  end
  nil
end

def parse_results(html)
  doc = Nokogiri::HTML(html)
  results = []

  cards = doc.css("div.g")
  cards = doc.css("a:has(h3)") if cards.empty?

  rank = 0
  cards.each do |card|
    h3 = card.at_css("h3")
    a  = h3&.ancestors("a")&.first || card.at_css("a")
    next unless h3 && a && a["href"]

    title = h3.text.to_s.strip.gsub(/\s+/, " ")
    link  = a["href"].to_s

    if link.start_with?("/url?")
      link = google_redirect_to_real(link)
    elsif link.start_with?("/")
      link = nil
    end
    next if title.empty? || link.nil?

    rank += 1
    snippet = extract_snippet(card)

    results << {
      "rank"       => rank,
      "title"      => title,
      "link"       => link,
      "snippet"    => snippet,
      "query"      => QUERY,
      "fetched_at" => Time.now.to_i
    }
  end

  results
end

def save_results(rows)
  rows.each do |row|
    ScraperWiki.save_sqlite(unique_keys: ["link"], data: row)
  end
end

def main
  url  = build_url(GOOGLE_SEARCH_URL, PARAMS)
  html = http_get(url, HEADERS)
  rows = parse_results(html)
  save_results(rows)
  puts "Saved #{rows.length} results from the first page."
end

main if __FILE__ == $PROGRAM_NAME
