defmodule TelemetryMetricsCloudwatchTest do
  use ExUnit.Case

  alias Telemetry.Metrics
  alias TelemetryMetricsCloudwatch.Cache

  describe "An empty cache" do
    test "should have the right metric count and max values per metric" do
      empty = %Cache{}
      assert Cache.metric_count(empty) == 0
      assert Cache.max_values_per_metric(empty) == 0
    end
  end

  describe "When handling tags a cache" do
    test "should be able to handle tags with empty/nil values" do
      tvalues = %{host: 'a host', port: 123, something: "", somethingelse: nil}

      counter =
        Metrics.counter([:aname, :count],
          tag_values: &Map.merge(&1, tvalues),
          tags: [:host, :port, :something, :somethingelse]
        )

      cache = Cache.push_measurement(%Cache{}, %{count: 112}, %{}, counter)

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      {_postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [
                 metric_name: "aname.count",
                 value: 112,
                 dimensions: [host: "a host", port: "123"],
                 unit: "Count"
               ]
             ]
    end

    test "should be able to handle tags with non string values" do
      tvalues = %{host: 'a host', port: 123}

      counter =
        Metrics.counter([:aname, :count],
          tag_values: &Map.merge(&1, tvalues),
          tags: [:host, :port]
        )

      cache = Cache.push_measurement(%Cache{}, %{count: 112}, %{}, counter)

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      {_postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [
                 metric_name: "aname.count",
                 value: 112,
                 dimensions: [host: "a host", port: "123"],
                 unit: "Count"
               ]
             ]
    end

    test "should be able to handle more than 10 tags" do
      keys = ~w(a b c d e f g h i j k l m n o p)a
      tvalues = Enum.into(keys, %{}, &{&1, "value"})

      counter =
        Metrics.counter([:aname, :count],
          tag_values: &Map.merge(&1, tvalues),
          tags: keys
        )

      cache = Cache.push_measurement(%Cache{}, %{count: 112}, %{}, counter)

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      {_postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [
                 metric_name: "aname.count",
                 value: 112,
                 dimensions: Enum.take(tvalues, 10),
                 unit: "Count"
               ]
             ]
    end
  end

  describe "When handling counts, a cache" do
    test "should be able to coalesce a single count metric" do
      cache =
        Cache.push_measurement(%Cache{}, %{count: 112}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      # now pop all metrics
      {postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [metric_name: "aname.count", value: 112, dimensions: [], unit: "Count"]
             ]

      assert Cache.metric_count(postcache) == 0
      assert Cache.max_values_per_metric(postcache) == 0
    end

    test "should be able to coalesce multiple count metrics" do
      cache =
        %Cache{}
        |> Cache.push_measurement(%{count: 133}, %{}, Metrics.counter([:aname, :count]))
        |> Cache.push_measurement(%{count: 100}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      # now pop all metrics
      {postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [metric_name: "aname.count", value: 233, dimensions: [], unit: "Count"]
             ]

      assert Cache.metric_count(postcache) == 0
      assert Cache.max_values_per_metric(postcache) == 0
    end

    test "should be able to handle a nil value" do
      cache =
        Cache.push_measurement(%Cache{}, %{count: nil}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 0

      cache =
        %Cache{}
        |> Cache.push_measurement(%{count: 133}, %{}, Metrics.counter([:aname, :count]))
        |> Cache.push_measurement(%{count: nil}, %{}, Metrics.counter([:aname, :count]))
        |> Cache.push_measurement(%{count: 100}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      # now pop all metrics
      {postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [metric_name: "aname.count", value: 233, dimensions: [], unit: "Count"]
             ]

      assert Cache.metric_count(postcache) == 0
      assert Cache.max_values_per_metric(postcache) == 0
    end

    test "should be able to handle a non-numeric, non-nil value" do
      cache =
        Cache.push_measurement(%Cache{}, %{count: "hi"}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 0

      cache =
        %Cache{}
        |> Cache.push_measurement(%{count: 133}, %{}, Metrics.counter([:aname, :count]))
        |> Cache.push_measurement(%{count: "hi"}, %{}, Metrics.counter([:aname, :count]))
        |> Cache.push_measurement(%{count: 100}, %{}, Metrics.counter([:aname, :count]))

      assert Cache.metric_count(cache) == 1
      assert Cache.max_values_per_metric(cache) == 1

      # now pop all metrics
      {postcache, metrics} = Cache.pop_metrics(cache)

      assert metrics == [
               [metric_name: "aname.count", value: 233, dimensions: [], unit: "Count"]
             ]

      assert Cache.metric_count(postcache) == 0
      assert Cache.max_values_per_metric(postcache) == 0
    end
  end
end
