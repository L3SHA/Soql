# SOQL Apex Library

Lightweight Apex library for Soql queries in builder style. Supports session cache, which allows to avoid SOQL governor limits.

## Examples

### Simple select query

```
List<Account> accounts = (List<Account>) Soql.fetch(Account.sObjectType)
    .field('Name')
    .query();
```

### Query with filter

```
List<Account> accounts = (List<Account>) Soql.fetch(Account.sObjectType)
    .field('Name')
    .filter('Name', 'Test')
    .query();
```

### Aggregate query

```
List<AggregateResult> result = Soql.fetch(Account.sObjectType)
    .fields(new List<String> {'Name', 'COUNT(Id) Cnt'})
    .groupBy('Name')
    .havingCount('Id', Soql.GREATER_THAN, 1)
    .query();
```