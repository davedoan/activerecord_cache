require 'test_helper'

class ActiveRecordCacheTest < ActiveSupport::TestCase

  setup do
    Rails.cache.clear

    # Not sure why, but mocha expectations aren't being cleared between tests…
    Mocha::Mockery.instance.stubba.unstub_all
  end



  # Loading records should persist to cache
  test "loading records using find should persist them to the cache" do
    Rails.cache.expects(:write).twice
    CachedRecord.find(1, 2)
  end

  test "loading all records should NOT persist them to the cache" do
    Rails.cache.expects(:write).never
    CachedRecord.all.load    
  end

  test "loading records using a where should NOT persist them to the cache" do
    Rails.cache.expects(:write).never
    CachedRecord.where(:name => 'John').load    
  end



  # Errors should still be raised
  test "loading missing records should still throw errors" do
    bogus_id = 12345

    assert_raises ActiveRecord::RecordNotFound do
      CachedRecord.find(bogus_id)
    end

    assert_raises ActiveRecord::RecordNotFound do
      CachedRecord.find([1, bogus_id])
    end
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

  # where + id gets treated like a complex query
  test "#where(:id => id) does NOT use the cache" do
    cache_records(1)

    assert_query_count 1 do
      records = CachedRecord.where(:id => 1).load
    end
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

  test "polymorphic fix" do
    assert_equal 1, CachedTypeARecord.find(1).poly_record.id
    assert_equal "CachedTypeARecord", CachedTypeARecord.find(1).poly_record.detail_type
    assert_not_nil Rails.cache.read("CachedTypeARecord/1")
    poly_record_id = PolyRecord.find(2).cached_type_a_record.poly_record.id
    assert_equal 1, CachedTypeARecord.find(1).poly_record.id # would fail with 2 without fix in BelongsToAssociation.find_target_with_caching
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
