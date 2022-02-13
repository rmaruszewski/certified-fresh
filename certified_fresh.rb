require 'nokogiri'
require 'open-uri'
require 'resolv-replace'
require 'json'
require 'cgi'
require_relative 'movie'

class CertifiedFresh 

  CERTIFIED_FRESH_URL = 'https://www.rottentomatoes.com/api/private/v2.0/browse?maxTomato=100&certified&sortBy=release&type=cf-dvd-streaming-all&page=%s'
  ROTTEN_URL_PREFIX = 'https://www.rottentomatoes.com/'
  IMDB_SEARCH_URL= 'https://www.imdb.com/search/title/?title=%s&release_date=%s-01-01,%s-12-31'
  MIN_RATING = 7.0

  def initialize
    @movies = []
  end

  def run
    read_certified_fresh
    puts "Certified fresh movies #{@movies.size}"
    read_release_years
    @movies.delete_if { |movie| movie.release_year.nil? }
    read_imdb_url
    @movies.delete_if { |movie| movie.imdb_rating.nil? || movie.imdb_id.nil? }
    puts "Certified fresh movies found on IMDB: #{@movies.size}" 
    @movies.keep_if { |movie| movie.imdb_rating > MIN_RATING }
    puts "Certified fresh movies with ratings > #{MIN_RATING}: #{@movies.size}" 
    save_result
  end

  def read_certified_fresh
    puts 'Reading all the certified fresh...'
    page = 1

    loop do
      puts("Page: #{page}")
      doc = read_json(CERTIFIED_FRESH_URL % page)

      return if doc['results'].empty?

      doc['results'].each do |json|
        title = json['title']

        if title.include?('(')
          title = title[0...(title.index('(') - 1)]
        end

        movie = Movie.new(title)
        movie.rotten_url = ROTTEN_URL_PREFIX + json['url']
        @movies << movie
      end

      page += 1
    end
  end

  def read_release_years
    @movies.each_with_index do |movie, index|
      puts "Reading release year for #{index + 1}. #{movie.title}"
      doc = read_doc(movie.rotten_url)
      info = doc.css('score-board > p[slot=info]')
      movie.release_year = info.text[0...info.text.index(',')].to_i
    rescue => e
      puts "Error when reading release year for #{movie.title}: #{e}"
    end
  end

  def read_imdb_url
    @movies.each_with_index do |movie, index|
      puts "Searching IMDB for #{index + 1}. #{movie.title}"
      doc = read_doc(IMDB_SEARCH_URL % [CGI::escape(movie.title), movie.release_year - 1, movie.release_year + 1])
      list = doc.css('div[class=lister-list]')[0]
      content = list.css('div[class=lister-item-content]')[0]
      url = content.css('h3 > a').attr('href').value
      movie.imdb_id = url.split('/')[2]
      rating = content.css('div[class=ratings-bar] div[class*=ratings-imdb-rating]').text.strip.to_f
      movie.imdb_rating = rating
    rescue => e
      puts "Error when searching IMDB for #{movie.title}: #{e}"
    end
  end

  def save_result
    File.open("movies.txt", 'w') do |file|
      @movies.each do |movie|
        file.puts(movie.imdb_id)
      end
    end
  end

  def read_json(url)
    JSON.parse(URI.open(url).read)
  end

  def read_doc(url)
    Nokogiri::HTML(URI.open(url, 'User-Agent' => 'Mozilla/5.0'))
  end

  app = CertifiedFresh.new
  app.run
end

