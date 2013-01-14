module ActiveRecordCache
  module BelongsToAssociation
    extend ActiveSupport::Concern

    included do
      alias_method_chain :find_target, :caching
    end

    private

    def find_target_with_caching
      if klass.use_activerecord_cache && reflection.options[:primary_key].nil?
        klass.find_through_cache(owner[reflection.foreign_key]).tap { |record| set_inverse_instance(record) }
      else
        find_target_without_caching
      end
    end
  end
end
