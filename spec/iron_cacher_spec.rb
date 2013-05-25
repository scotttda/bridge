require 'rspec'
require File.expand_path(File.dirname(__FILE__) + '/../lib/iron_cacher')

describe IronCacher do
  class MockIronCache
    extend IronCacher
  end

  describe "iron_cache_client" do
    it "return an iron cache client  instance" do
      MockIronCache.iron_cache_client.should be_is_a(IronCache::Client)
    end
    
    it "should use a separate config file from the iron.json" do
      MockIronCache.iron_cache_client.project_id.should == ENV['IRON_CACHE_PROJECT_ID']
    end

  end
  
  describe "iron_cache" do
    it "return an iron cache instance" do
      MockIronCache.iron_cache.should be_is_a(IronCache::Cache)
    end
    
    it "should should return the cache with the name of the as CACHE_NAME" do
      MockIronCache.iron_cache.name.should == IronCacher::CACHE_NAME
    end    
  end
  
  describe "add_to_cache" do
    before(:each) do
      @key=Time.now.to_f.to_s
    end

    it "should return the key" do
      MockIronCache.add_to_cache(@key, 'value').should == @key
    end
  
    it "should add an expiry" do
      MockIronCache.add_to_cache(@key, 'value')
      expires = MockIronCache.iron_cache.get(@key)['expires']
      DateTime.parse(expires).should < DateTime.parse('9999-01-01T00:00:00+00:00')
    end

  end  
  
  describe "random_key_and_value" do
    it "should return an array" do
      MockIronCache.random_key_and_value(IronCacher::CACHE_NAME).class.should == Array
    end
    
    it "should return the key as the first element and value in cache as the second" do
      key,value = MockIronCache.random_key_and_value(IronCacher::CACHE_NAME)
      MockIronCache.iron_cache.get(key).value.should == value
    end
  end

end