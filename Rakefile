def gemf(ext = '')
  puts `pwd`
  puts `bundle config --local gemfile Gemfile#{ext}`
  puts `bundle install`
end

task :default do
  gemf
end

task :dev do
  gemf( '.dev' )
end
