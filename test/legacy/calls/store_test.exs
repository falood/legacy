defmodule Legacy.Calls.StoreTest do
  use Legacy.RedisCase, async: true

  describe "Legacy.Calls.Store.incr/3" do
    test "creates counters for new & old at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.Store.incr "call-store-1", now , {2, 3}

      assert Redix.command!(redis, ~w(EXISTS calls:call-store-1:86400:#{base}:new)) == 1
      assert Redix.command!(redis, ~w(EXISTS calls:call-store-1:86400:#{base}:old)) == 1
    end

    test "sets both new and old counts to values provided", %{redis: redis} do
      Legacy.Calls.Store.incr "call-store-2", 1506816000, {2, 3}

      new_key = "calls:call-store-2:86400:1506816000:new"
      old_key = "calls:call-store-2:86400:1506816000:old"
      assert Redix.command!(redis, ~w(MGET #{new_key} #{old_key})) == ["2", "3"]
    end

    test "increments by values if counts existed before", %{redis: redis} do
      new_key = "calls:call-store-3:86400:1506816000:new"
      old_key = "calls:call-store-3:86400:1506816000:old"
      Redix.command! redis, ~w(MSET #{new_key} 2 #{old_key} 3)

      Legacy.Calls.Store.incr "call-store-3", 1506816000, {3, 4}

      assert Redix.command!(redis, ~w(MGET #{new_key} #{old_key})) == ["5", "7"]
    end

    test "returns the new values" do
      assert Legacy.Calls.Store.incr("call-store-12", 1506816000, {2, 3}) == {2, 3}
    end
  end

  describe "Legacy.Calls.Store.incr_new" do
    test "creates counters for new at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.Store.incr_new "call-store-4", now, 2

      assert Redix.command!(redis, ~w(EXISTS calls:call-store-4:86400:#{base}:new)) == 1
    end

    test "sets new count to the value provided", %{redis: redis} do
      Legacy.Calls.Store.incr_new "call-store-5", 1506816000, 2
      assert Redix.command!(redis, ~w(GET calls:call-store-5:86400:1506816000:new)) == "2"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-store-6:86400:1506816000:new 2)

      Legacy.Calls.Store.incr_new "call-store-6", 1506816000, 3

      assert Redix.command!(redis, ~w(GET calls:call-store-6:86400:1506816000:new)) == "5"
    end

    test "defauts to value 1 when given none", %{redis: redis} do
      Legacy.Calls.Store.incr_new "call-store-7", 1506816000
      assert Redix.command!(redis, ~w(GET calls:call-store-7:86400:1506816000:new)) == "1"
    end

    test "returns the new value" do
      assert Legacy.Calls.Store.incr_new("call-store-13", 1506816000, 80) == 80
    end
  end

  describe "Legacy.Calls.Store.incr_old" do
    test "creates counters for old at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.Store.incr_old "call-store-8", now, 2

      assert Redix.command!(redis, ~w(EXISTS calls:call-store-8:86400:#{base}:old)) == 1
    end

    test "sets old count to the value provided", %{redis: redis} do
      Legacy.Calls.Store.incr_old "call-store-9", 1506816000, 2
      assert Redix.command!(redis, ~w(GET calls:call-store-9:86400:1506816000:old)) == "2"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-store-10:86400:1506816000:old 2)

      Legacy.Calls.Store.incr_old "call-store-10", 1506816000, 3

      assert Redix.command!(redis, ~w(GET calls:call-store-10:86400:1506816000:old)) == "5"
    end

    test "defauts to value 1 when given none", %{redis: redis} do
      Legacy.Calls.Store.incr_old "call-store-11", 1506816000
      assert Redix.command!(redis, ~w(GET calls:call-store-11:86400:1506816000:old)) == "1"
    end

    test "returns the new value" do
      assert Legacy.Calls.Store.incr_old("call-store-14", 1506816000, 77) == 77
    end
  end

  describe "Legacy.Calls.Store.get" do
    test "returns 0 for both calls when they're missing" do
      assert Legacy.Calls.Store.get("inexistent", 1506816000) == {0, 0}
    end

    test "returns a tuple with new and old calls for the given timestamp & feature", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-store-15:86400:1506816000:new 3)
      Redix.command! redis, ~w(SET calls:call-store-15:86400:1506816000:old 2)

      assert Legacy.Calls.Store.get("call-store-15", 1506816000) == {3, 2}
    end
  end

  describe "Legacy.Calls.Store.get_many" do
    test "returns calls for multiple timestamps", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-store-16:86400:1506816000:new 3)
      Redix.command! redis, ~w(SET calls:call-store-16:86400:1506902400:old 2)
      Redix.command! redis, ~w(SET calls:call-store-16:86400:1506988800:old 1)

      assert Legacy.Calls.Store.get_many("call-store-16", [1506816000, 1506902400, 1506988800]) == [
        {3, 0},
        {0, 2},
        {0, 1}
      ]
    end
  end
end
