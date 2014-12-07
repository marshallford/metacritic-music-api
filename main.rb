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

# creates array of pages to scrape
metacriticNewReleasesURLs = ["http://www.metacritic.com/browse/albums/release-date/new-releases/date"]
urlIndex = 1 # start at one because the base page is index zero
while true
	tempURL = metacriticNewReleasesURLs[0] + "?page=" + urlIndex.to_s
	openURLpage = open(tempURL, {'User-Agent' => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"})
	if openURLpage.read.downcase.include? "no results found"
		break
	end
	metacriticNewReleasesURLs[urlIndex] = tempURL
	urlIndex = urlIndex + 1
end

artistTitleArray = []
albumTitleArray = []
metacriticScoreArray = []
dateReleasedArray = []
overallIndex = 0 # prevents the index from reseting after page

# loop through URLs and fill individual arrays
metacriticNewReleasesURLs.each_with_index do |url, metacriticNewReleasesURLsIndex|
	# abort if openURI returns an error
	begin
	openURLpage = open(url, {'User-Agent' => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"})
	rescue OpenURI::HTTPError => ex
		File.open("log.txt","a") do |f|
	  		f.write(currentTime.to_s + "    OpenURI Error: " + ex.to_s + "\n")
		end
		abort
	end
	# abort if page size is less than 10KB
	if (openURLpage.size * 0.001) < 10
		File.open("log.txt","a") do |f|
	  		f.write(currentTime.to_s + "    Page Size Error: Page size is " + (openURLpage.size * 0.001).to_s + "KB\n")
		end
		abort
	end

	page = Nokogiri::HTML(openURLpage) # create Nokogiri object

	# get album title and add to array
	page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.product_title > a").each_with_index do |albumTitle, index|
		albumTitleArray[index+overallIndex] = albumTitle.text.strip
	end

	# get artist title and add to array
	page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.condensed_stats > ul > li.stat.product_artist > span.data").each_with_index do |artistTitle, index|
		artistTitleArray[index+overallIndex] = artistTitle.text.strip
	end

	# get metacritic score and add to array
	page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.product_score.brief_metascore > div").each_with_index do |metacriticScore, index|
		metacriticScoreArray[index+overallIndex] = metacriticScore.text.strip
	end

	# get/convert date and add to array
	page.css("#main > div.module.products_module.list_product_condensed_module > div.body > div.body_wrap > div > ol > li.product.release_product > div > div.basic_stat.condensed_stats > ul > li.stat.release_date > span.data").each_with_index do |dateReleased, index|
		date = Date.strptime(dateReleased.text.strip + " " + currentYear.to_s, "%b %e %Y")
		dateReleasedArray[index+overallIndex] = date.to_s
	end
	overallIndex = albumTitleArray.length
end

# verify realistic number of new releases
if albumTitleArray.length > 10000 || albumTitleArray.length < 10
	File.open("log.txt","a") do |f|
  		f.write(currentTime.to_s + "    Number of Results Error: " + albumTitleArray.length.to_s + " result(s) recorded\n")
	end
	abort
end

# start the creation of the hash
newReleases = { :resultCount => albumTitleArray.length.to_s , :lastUpdated => currentTime }

# create hash
albumTitleArray.each_with_index do |item, index|
	newReleases = newReleases.deep_merge({:results => [ {:artistTitle => artistTitleArray[index], :albumTitle => albumTitleArray[index], :metacriticScore => metacriticScoreArray[index], :dateReleased => dateReleasedArray[index]}] })
end

# save hash as json to file
File.open("new-releases.json","w") do |f|
  f.write(JSON.pretty_generate(JSON.parse(newReleases.to_json)))
end
