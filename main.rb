#!/usr/bin/ruby
require 'rubygems'
require 'bundler/setup'
# require your gems as usual
require 'httparty'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'deep_merge'

# time
currentTime = Time.new.utc
currentYear = Time.new.year

# new releases by date
metacriticNewReleasesURL = "http://www.metacritic.com/browse/albums/release-date/new-releases/date"
artistTitleArray = []
albumTitleArray = []
metacriticScoreArray = []
dateReleasedArray = []

# get page and verify that it is a legit page
begin
openURLpage = open(metacriticNewReleasesURL)
rescue OpenURI::HTTPError => ex
	File.open("log.txt","a") do |f|
  		f.write(currentTime.to_s + "    OpenURL Error: " + ex.to_s)
	end
	abort
end
if (openURLpage.size * 0.001) < 100
	File.open("log.txt","a") do |f|
  		f.write(currentTime.to_s + "    Page Size Error: Page size is " + (openURLpage.size * 0.001).to_s + "KB")
	end
	abort
end
page = Nokogiri::HTML(openURLpage)

# get album title
page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.product_title > a").each_with_index do |albumTitle, index|
	albumTitleArray[index] = albumTitle.text.strip
end

# get artist title
page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.condensed_stats > ul > li.stat.product_artist > span.data").each_with_index do |artistTitle, index|
	artistTitleArray[index] = artistTitle.text.strip
end

# get metacritic score
page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.product_score.brief_metascore > div").each_with_index do |metacriticScore, index|
	metacriticScoreArray[index] = metacriticScore.text.strip
end

# get and convert date
page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.condensed_stats > ul > li.stat.release_date > span.data").each_with_index do |dateReleased, index|
	date = Date.strptime(dateReleased.text.strip + " " + currentYear.to_s, "%b %e %Y")
	dateReleasedArray[index] = date.to_s
end

# start the creation of the hash
newReleases = { :resultCount => albumTitleArray.length.to_s , :lastUpdated => currentTime }

# create hash
albumTitleArray.each_with_index do |item, index|
	newReleases = newReleases.deep_merge({:results => [ {:artistTitle => artistTitleArray[index], :albumTitle => albumTitleArray[index], :metacriticScore => metacriticScoreArray[index], :dateReleased => dateReleasedArray[index]}] })
end

# save hash as json to file
File.open("new-releases-date.json","w") do |f|
  f.write(JSON.pretty_generate(JSON.parse(newReleases.to_json)))
end
