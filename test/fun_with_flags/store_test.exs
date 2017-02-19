defmodule FunWithFlags.StoreTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  alias FunWithFlags.{Store, Config}

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end

  test "looking up an undefined flag returns false" do
    flag_name = unique_atom()
    assert false == Store.lookup(flag_name)
  end

  test "put() can change the value of a flag" do
    flag_name = unique_atom()

    assert false == Store.lookup(flag_name)
    Store.put(flag_name, true)
    assert true == Store.lookup(flag_name)
    Store.put(flag_name, false)
    assert false == Store.lookup(flag_name)
  end

  test "put() returns the tuple {:ok, a_boolean_value}" do
    flag_name = unique_atom()
    assert {:ok, true} == Store.put(flag_name, true)
    assert {:ok, false} == Store.put(flag_name, false)
  end

  describe "unit: enable and disable with this module's API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      Store.put(flag_name, false)
      assert false == Store.lookup(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      Store.put(flag_name, true)
      assert true == Store.lookup(flag_name)
    end
  end


  describe "reload(flag_name) reads the flag value from Redis and updates the Cache" do
    alias FunWithFlags.Store.{Cache, Persistent}

    test "if the flag is not found in Redis, it sets it to false in the Cache" do
      flag_name = unique_atom()
      assert false == Persistent.get(flag_name)

      Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)
      assert true = Store.lookup(flag_name)

      Store.reload(flag_name)

      assert {:ok, false} = Cache.get(flag_name)
      assert false == Store.lookup(flag_name)
    end

    test "if the flag is false in Redis, it sets it to false in the Cache" do
      flag_name = unique_atom()
      Persistent.put(flag_name, false)
      assert false == Persistent.get(flag_name)

      Cache.put(flag_name, true)
      assert {:ok, true} = Cache.get(flag_name)
      assert true == Store.lookup(flag_name)

      Store.reload(flag_name)

      assert {:ok, false} = Cache.get(flag_name)
      assert false == Store.lookup(flag_name)
    end

    test "if the flag is true in Redis, it sets it to true in the Cache" do
      flag_name = unique_atom()
      Persistent.put(flag_name, true)
      assert true == Persistent.get(flag_name)

      Cache.put(flag_name, false)
      assert {:ok, false} = Cache.get(flag_name)
      assert false == Store.lookup(flag_name)

      Store.reload(flag_name)

      assert {:ok, true} = Cache.get(flag_name)
      assert true == Store.lookup(flag_name)
    end
  end


  describe "integration: enable and disable with the top-level API" do
    test "looking up a disabled flag returns false" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == Store.lookup(flag_name)
    end

    test "looking up an enabled flag returns true" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == Store.lookup(flag_name)
    end
  end


  describe "integration: Cache and Persistence" do
    alias FunWithFlags.Store.{Cache, Persistent}

    test "setting a value will update both the cache and the persistent store" do
      flag_name = unique_atom()

      assert {:miss, :not_found, nil} == Cache.get(flag_name)
      assert false == Persistent.get(flag_name)
      Store.put(flag_name, true)
      assert {:ok, true} == Cache.get(flag_name)
      assert true == Persistent.get(flag_name)
    end

    test "when the value is initially not in the cache but set in redis,
          looking it up will populate the cache" do
      flag_name = unique_atom()
      Persistent.put(flag_name, true)

      assert {:miss, :not_found, nil} == Cache.get(flag_name)
      assert true == Persistent.get(flag_name)
      
      assert true == Store.lookup(flag_name)
      assert {:ok, true} == Cache.get(flag_name)
    end


    test "when the value is initially not in the cache and not in redis,
          looking it up will populate the cache" do
      flag_name = unique_atom()

      assert {:miss, :not_found, nil} == Cache.get(flag_name)
      assert false == Persistent.get(flag_name)
      
      assert false == Store.lookup(flag_name)
      assert {:ok, false} == Cache.get(flag_name)
    end

    test "when a value in the cache expires, we can still reload it from redis" do
      flag_name = unique_atom()
      Persistent.put(flag_name, true)

      assert {:miss, :not_found, nil} == Cache.get(flag_name)
      assert true == Persistent.get(flag_name)

      assert true == Store.lookup(flag_name)
      assert {:ok, true} == Cache.get(flag_name)

      timetravel by: (Config.cache_ttl + 1) do
        assert {:miss, :expired, true} = Cache.get(flag_name)
        assert true == Store.lookup(flag_name)
      end
    end

  end
end
