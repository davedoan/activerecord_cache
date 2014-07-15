require 'test_helper'

class ActiveRecordCacheTest < ActiveSupport::TestCase

  setup do
    Rails.cache.clear
  end



  # Loading records should persist to cache
  test "loading records using find should persist them to the cache" do
    Rails.cache.expects(:write).twice
    CachedRecord.find(1, 2)
  end

  test "loading all records should persist them to the cache" do
    Rails.cache.expects(:write).twice
    CachedRecord.all.load    
  end

  test "loading records using a where should persist them to the cache" do
    Rails.cache.expects(:write).once
    CachedRecord.where(:name => 'John').load    
  end



  # Finders should use the cache
  test "#find(id) should use the cache" do
    cache_records(1)

    assert_query_count 0 do
      CachedRecord.find(1)
    end
  end

  test "#find(ids) should use the cache" do
    cache_records(1,2)

    assert_query_count 0 do
      CachedRecord.find(1, 2)
    end
  end

  test "#find(ids) with some cached records should query for additional records" do
    cache_records(1)

    assert_query_count 1 do
      CachedRecord.find(1, 2)
    end
  end



  # Complex queries should skip the cache
  test "#where(:id => id, :other => criteria) should NOT use the cache" do
    cache_records(1)

    records = CachedRecord.where(:id => 1, :name => 'Bogus').load

    assert records.empty?, 'should not find cached record'
  end

  test "#select(:id) should NOT use the cache" do
    cache_records(1)

    Rails.cache.expects(:write).never
    CachedRecord.select(:id).load
  end



  # belongs_to associations should use the cache
  test "accessing cached associations should use the cache" do
    cache_records(1)
    associated = AssociatedRecord.find(1)

    assert_query_count 0 do
      associated.cached_record
    end
  end

  test "accessing associations should persist records to the cache" do
    associated = AssociatedRecord.find(1)

    Rails.cache.expects(:write).once
    associated.cached_record
  end

  test "associations that do not reference the primary key should NOT use the cache" do
    cache_records(1, 2)
    non_primary = NonPrimaryAssociated.find(1)

    assert_query_count 1 do
      non_primary.cached_record
    end
  end



  # Preloading associations should use the cache
  test "preloading associations should use the cache" do
    cache_records(1)

    assert_query_count 1 do
      AssociatedRecord.includes(:cached_record).find(1)
    end
  end

  test "preloading associations should persist records to the cache" do
    Rails.cache.expects(:write).once
    AssociatedRecord.includes(:cached_record).find(1)
  end

  test "preloading associations that do not reference the primary key should NOT use the cache" do
    cache_records(1, 2)

    assert_query_count 2 do
      NonPrimaryAssociated.includes(:cached_record).find(1)
    end
  end



  # Saving and destroying
  test "saving a record should write it to the cache" do
    Rails.cache.expects(:write).once
    CachedRecord.create!({})
  end

  test "destroying a record should remove it from the cache" do
    Rails.cache.expects(:delete).once
    CachedRecord.find(1).destroy
  end



  private

  def assert_query_count(expected_count, &block)
    count = count_queries do
      yield block
    end

    assert_equal expected_count, count, "expected #{expected_count} queries"
  end

  def count_queries(&block)
    count = 0

    counter = ->(name, started, finished, unique_id, payload) {
      unless payload[:name].in? %w[ CACHE SCHEMA ]
        count += 1
      end
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)

    count
  end

  def cache_records(*records)
    CachedRecord.find(Array(records).flatten)
  end

end
