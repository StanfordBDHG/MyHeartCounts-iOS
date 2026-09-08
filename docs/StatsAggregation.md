<!--

This source file is part of the My Heart Counts iOS open-source project

SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

# Stats aggregation metadata

Monthly stats entries may carry the optional `average` and `provenance` fields below. These fields are additive: existing entries remain readable, and writers should omit metadata they cannot establish accurately.

The Swift metadata types are `StatsDocument.Average` and `StatsDocument.Provenance`; source keys use `StatsDocument.SourceID`. Nesting these types does not change the JSON field names or encoding.

```json
{
  "start": "2026-09-07T08:00:00+02:00",
  "end": "2026-09-07T09:00:00+02:00",
  "unit": "count/min",
  "min": 60,
  "max": 100,
  "avg": 75,
  "average": {
    "numerator": 2250,
    "denominator": 30,
    "weighting": "example-observation-mean-v1"
  },
  "provenance": {
    "origins": ["example:original-device-dataset"]
  }
}
```

`average.numerator / average.denominator` must reproduce `avg` in the entry's unit. Both numbers must be finite; the denominator must be positive. `weighting` identifies the averaging algorithm and weight units. Writers must agree on its complete semantics before using the same identifier. In this illustrative example, the numerator is the sum of 30 individual observations and the denominator is their count. It does **not** describe HealthKit heart-rate averaging.

Compatible averages merge by summing their numerators and denominators. Weights must remain attached through subsequent interval aggregation; an average of already averaged buckets generally loses the original weighting. Identical weight labels alone do not establish that two contributions can be pooled: compatible bucket boundaries and independent provenance are also required. Partial overlap cannot be resolved exactly by prorating aggregate values; consumers may explicitly opt into diagnosed interval approximations as described in [StatsQueries.md](StatsQueries.md).

`provenance.origins` is the complete set of stable, namespaced originating datasets represented by the entry, shared consistently across ingestion paths. Disjoint, nonempty origin sets can establish independent datasets. Missing provenance or an empty origin set means the complete lineage is unknown. An immediate uploader's bundle identifier does not establish the originating dataset: a provider may copy a wearable reading into HealthKit while its direct integration uploads the same reading separately.

For individual quantity readings and blood-pressure pairs, `provenance.observationID` may contain a stable, globally namespaced identifier for the original observation. Copies must preserve that identifier to support exact duplicate removal. Different IDs do not prove independent origin datasets.

The HealthKit writer adds `healthkit:<lowercase UUID>` observation IDs to individual quantity readings and blood-pressure correlations, with an empty `origins` array. These IDs survive recalculation, but cannot identify a separately imported copy that lost the original UUID. Existing entries without this metadata stay readable and receive conservative source selection when independence cannot be established.

The HealthKit stats writer currently emits whole-second dates. Source comparisons use the exact parsed instant, including fractional seconds supplied by other writers, without truncating every source to whole seconds. Preserve the shared `observationID` across ingestion paths to identify copies even when their timestamp precision changes.

Under `.automatic`, current HealthKit documents support the following behavior:

- Cumulative values (steps and exercise time) prefer HealthKit for overlapping buckets and fill gaps from other sources; competing totals are not added.
- Heart-rate minima and maxima can merge across matching whole buckets without independent-origin metadata.
- Heart-rate averages prefer HealthKit for competing buckets because its writer supplies neither a complete origin set nor compatible average weights.
- Overlapping sleep sessions prefer HealthKit; uncovered sessions from other sources can still be included.
- Individual quantity readings and blood-pressure pairs at different timestamps can coexist. At a shared timestamp, unknown or overlapping origins cause preferred-source fallback. Matching observation IDs are deduplicated across timestamps.

Adding origins to a server writer alone does not establish independence from HealthKit's unknown lineage. Pooling competing averages requires complete, disjoint origin sets and compatible weights on **both** contributions. Writers must omit unsupported metadata rather than infer it from uploader names, sample counts, or bucket durations.

## HealthKit heart-rate limitation

HealthKit heart rate uses a temporally weighted integration function, and a quantity sample may represent an entire series of underlying measurements. Counting `HKQuantitySample` objects therefore cannot provide its averaging denominator. Apple's public `HKStatistics.duration()` contract describes covered sample duration; it does not establish that this duration is the denominator used by `averageQuantity()`.

The HealthKit writer consequently keeps its existing `min`, `max`, and `avg` values without adding inferred weights. Source selection remains conservative for these averages and exposes fallback diagnostics. Independent providers with trustworthy weights can use the optional `average` schema. Supporting exact pooling of HealthKit averages requires a documented mergeable representation or a separately specified averaging algorithm; it must not silently substitute a different meaning for the existing HealthKit average.

Sources: [HealthKit temporal aggregation](https://developer.apple.com/documentation/healthkit/hkquantityaggregationstyle/discretetemporallyweighted), [HKStatistics duration](https://developer.apple.com/documentation/healthkit/hkstatistics/duration()), [WWDC19: Exploring New Data Representations in HealthKit](https://developer.apple.com/videos/play/wwdc2019/218/).
