module ActiveRecordCache
  module Relation
    extend ActiveSupport::Concern

    included do
      alias_method_chain :to_a, :caching
    end

    def to_a_with_caching
      previously_loaded = loaded?

      records = to_a_without_caching
      records.each(&:write_to_cache) if @klass.use_activerecord_cache && !previously_loaded && select_values.empty?

      records
    end
  end
end
