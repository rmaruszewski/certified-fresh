class Movie
  attr_accessor :title, :release_year, :rotten_url, :imdb_id, :imdb_rating

  def initialize(title)
    @title = title
  end
end
