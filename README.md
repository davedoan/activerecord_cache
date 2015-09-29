# activerecord_cache

Basic caching for ActiveRecord models using the Rails low-level cache (`Rails.cache`).

### Installation

In your Gemfile, add this line:

    gem "activerecord_cache"

### Usage

To enable caching for a model:

    class User < ActiveRecord::Base
      self.use_activerecord_cache = true
    end

Or:

    User.use_activerecord_cache = true

