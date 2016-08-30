#! /bin/sh
# RAILS_ENV=development bundle exec rake db:create
RAILS_ENV=development bundle exec rake db:reset
RAILS_ENV=development bundle exec rake triplestore_adapter:blazegraph:reset
# RAILS_ENV=development rake admin_user
# RAILS_ENV=development rake lf:harvest
bundle exec rails s -p 3000 -b '0.0.0.0'
