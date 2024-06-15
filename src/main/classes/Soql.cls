public with sharing class Soql {
    // Operators
    public static final String GREATER_THAN = '>';
    public static final String GREATER_THAN_OR_EQUAL = '>=';
    public static final String LESS_THAN = '<';
    public static final String LESS_THAN_OR_EQUAL = '<=';
    public static final String EQUAL = '=';
    public static final String NOT_EQUAL = '!=';
    public static final String LIKE_OPERATOR = 'LIKE';

    // Special keywords
    public static final String TODAY = 'TODAY';
    public static final String LAST_WEEK = 'LAST_WEEK';
    public static final String NULL_VALUE = 'NULL';
    public static final String ORDER_ASC = 'ASC';
    public static final String ORDER_DESC = 'DESC';

    // Aggregate functions
    public static final String COUNT = 'COUNT';

    private static SoqlHelper.DatabaseCacheInventory cache = new SoqlHelper.DatabaseCacheInventory();

    private interface IField {
        String compile();
        Boolean isIllogical();
    }

    private interface IFieldValue {
        String compile();
        Boolean isEmpty();
    }

    public static String[] getAllFieldsForObject(String objectName) {
        return getAllFieldsForObject(objectName, false);
    }

    public static String[] getAllFieldsForObject(String objectName, Boolean onlyEditable) {
        if (!onlyEditable) {
            return new List<String>(Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().keySet());
        }
        Map<String,Schema.SObjectField> fields = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        String[] output = new String[]{};
        for (String fieldName : fields.keySet()) {
            if (fields.get(fieldName).getDescribe().isUpdateable()) {
                output.add(fieldName);
            }
        }
        return output;
    }

    public static QueryBuilder fetch(SObjectType objectType) {
        return fetch(objectType.getDescribe().getName());
    }

    public static QueryBuilder fetch(String objectName) {
        return new QueryBuilder().object(objectName);
    }

    public static List<SObject> query(String queryString, Map<String,Object> tokens) {
        Executor e = new Executor();
        Query q = new Query(queryString, tokens);
        return e.query(q);
    }

    public static IFieldValue createFieldValue(Object value) {
        // Convert set to list
        if (SoqlHelper.getType(value) == 'Set' && SoqlHelper.isConvertibleSet(value)) {
            value = SoqlHelper.convertSetToList(value);
        }

        // List<String>, List<Id>
        if (value instanceof List<String> || value instanceof List<Id>) {
            return new FieldValueStringList(value);
        }

        // List<Date>
        if (value instanceof List<Date>) {
            return new FieldValueDateList(value);
        }

        // List<Object>
        else if (value instanceof List<Object>) {
            return new FieldValueListDefault(value);
        }

        // Date
        else if (value instanceof Date) {
            return new FieldValueDate(value);
        }

        // Datetime
        else if (value instanceof Datetime) {
            return new FieldValueDatetime(value);
        }

        // String
        else if (value instanceof String) {
            return new FieldValueString(value);
        }

        // Default
        return new FieldValue(value);
    }



    public class Query {
        public String query {get; private set;}
        public Map<String,Object> tokens {get; private set;}
        private Pattern tokenPattern = Pattern.compile(':([a-zA-Z0-9_-]+)');

        public Query(String query) {
            this.query = query;
            this.tokens = new Map<String,Object>();
        }

        public Query(String queryString, Map<String,Object> tokens) {
            this.query = queryString;
            this.tokens = tokens;
        }

        public String get() {
            return this.query;
        }

        public String prepare() {
            return this.prepare(this.tokens);
        }

        public String prepare(Map<String,Object> tokens) {
            String tempQuery = this.query;
            if (tokens.keySet().size() < 1) {
                return tempQuery;
            }

            Matcher tokenMatcher = this.tokenPattern.matcher(tempQuery);
            if (!tokenMatcher.find()) {
                return tempQuery;
            }

            do {
                String token = tokenMatcher.group().replace(':', '');
                if (!tokens.containsKey(token)) {
                    continue;
                }
                IFieldValue queryField = createFieldValue(tokens.get(token));
                tempQuery = tempQuery.replaceAll(':' + token, queryField.compile());
            } while (tokenMatcher.find());

            return tempQuery;
        }
    }

    public class Executor {
        private Boolean useCache = false;

        public Executor enableCache() {
            this.useCache = true;
            return this;
        }

        public Executor disableCache() {
            this.useCache = false;
            return this;
        }

        private Boolean shouldUseCache() {
            return this.useCache;
        }

        public List<SObject> query(String queryString) {
            return this.query(new Query(queryString));
        }

        public List<SObject> query(Query query) {
            if (this.shouldUseCache() && cache.containsKey(query.get())) {
                System.debug('Soql :: Using cache for: ' + query.get());
                return (List<SObject>)cache.get(query.get()).get();
            }
            System.debug('Query to execute ' + query.get());
            List<SObject> result = Database.query(query.get());
            if (this.shouldUseCache()) {
                System.debug('Soql :: Caching result');
                cache.put(query.get(), result);
            }
            return result;
        }
    }

    public class QueryBuilder {
        private Executor executor = new Executor();
        private String objectName;
        private String[] selectFields = new String[]{};
        private FieldCollection subqueries = new FieldCollection(',', ', ');
        private FilterFieldCollection filters = new FilterFieldCollection('WHERE', ' AND ');
        private FieldCollection orderBy = new FieldCollection('ORDER BY', ', ');
        private FieldCollection groupBy = new FieldCollection('GROUP BY', ', ');
        private FieldCollection have = new FieldCollection('HAVING', ' AND ');
        private LimitField limiter = new LimitField();
        private OffsetField offset = new OffsetField();
        private AllRows allRows = new AllRows();
        private LockRows lockRows = new LockRows();

        public QueryBuilder object(String objectName) {
            this.objectName = objectName;
            return this;
        }

        public QueryBuilder field(String field) {
            this.selectFields.add(field.trim());
            return this;
        }

        public QueryBuilder fields(List<SObjectField> selectFields) {
            for (SObjectField selectField : selectFields) {
                this.selectFields.add(selectField.getDescribe().getName());
            }
            return this;
        }

        public QueryBuilder fields(List<String> selectFields) {
            this.selectFields.addAll(selectFields);
            return this;
        }

        public QueryBuilder fields(Set<String> selectFields) {
            return this.fields(new List<String>(selectFields));
        }

        public QueryBuilder fields(String selectFieldsString) {
            Set<String> fields = new Set<String>(selectFieldsString.split(','));
            for (String s : fields) {
                s = s.trim();
            }
            this.selectFields.addAll(fields);
            return this;
        }

        public QueryBuilder subquery(String query) {
            this.subqueries.add(new Subquery(query));
            return this;
        }

        public QueryBuilder filter(String field, String operator, Object value) {
            this.filters.add(new FilterField(field, operator, createFieldValue(value)));
            return this;
        }

        public QueryBuilder filter(String field, Object value) {
            return this.filter(field, Soql.EQUAL, value);
        }

        public QueryBuilder filter(String field, List<Object> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, Set<Object> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, Set<Date> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, Set<Id> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, List<Id> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, Set<String> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filter(String field, List<String> values) {
            return this.filter(field, 'IN', values);
        }

        public QueryBuilder filterLike(String field, Object value) {
            return this.filter(field, Soql.LIKE_OPERATOR, value);
        }

        public QueryBuilder filterNot(String field, Object value) {
            return this.filter(field, Soql.NOT_EQUAL, value);
        }

        public QueryBuilder filterNot(String field, List<String> values) {
            return this.filter(field, 'NOT IN', values);
        }

        public QueryBuilder filterNot(String field, Set<String> values) {
            return this.filter(field, 'NOT IN', values);
        }

        public QueryBuilder filterNot(String field, Set<Id> values) {
            return this.filter(field, 'NOT IN', values);
        }

        public QueryBuilder filterNot(String field, List<Object> values) {
            return this.filter(field, 'NOT IN', values);
        }

        public QueryBuilder filterNot(String field, Set<Object> values) {
            return this.filter(field, 'NOT IN', values);
        }

        public QueryBuilder filterLogic(String logic) {
            this.filters.filterLogic(logic);
            return this;
        }

        public QueryBuilder groupBy(String field) {
            this.groupBy.add(new GroupByField(field));
            return this;
        }

        public QueryBuilder havingCount(String field, String operator, Integer value) {
            this.have.add(new HavingField(field, COUNT, operator, new FieldValue(value)));
            return this;
        }

        public QueryBuilder orderBy(String field, String direction) {
            this.orderBy.add(new OrderByField(field, direction));
            return this;
        }

        public QueryBuilder withLimit(Integer queryLimit) {
            this.limiter.limitCount = queryLimit;
            return this;
        }

        public QueryBuilder fromOffset(Integer offset) {
            this.offset.offset = offset;
            return this;
        }

        public QueryBuilder allRows() {
            this.allRows.allRows = true;
            return this;
        }

        public QueryBuilder lockRows() {
            this.lockRows.lockRows = true;
            return this;
        }

        public QueryBuilder useCache() {
            return this.enableCache();
        }

        public QueryBuilder enableCache() {
            this.executor.enableCache();
            return this;
        }

        public QueryBuilder disableCache() {
            this.executor.disableCache();
            return this;
        }

        public QueryBuilder allFields() {
            this.selectFields = Soql.getAllFieldsForObject(this.objectName);
            return this;
        }

        public QueryBuilder allEditableFields() {
            this.selectFields = Soql.getAllFieldsForObject(this.objectName, true);
            return this;
        }

        public String compile() {
            if (this.selectFields.size() < 1) {
                this.allFields();
            }
            return String.format('SELECT {0} {1} FROM {2} {3} {4} {5} {6} {7} {8} {9} {10}', new String[]{
                String.join(this.selectFields, ', '),
                this.subqueries.compile(),
                this.objectName,
                this.filters.compile(),
                this.groupBy.compile(),
                this.have.compile(),
                this.orderBy.compile(),
                this.limiter.compile(),
                this.offset.compile(),
                this.allRows.compile(),
                this.lockRows.compile()
            });
        }

        public List<SObject> query() {
            if (this.filters.hasIllogicalFilters()) {
                System.debug('Illogical query, skipping execution: ' + this.compile());
                return new List<SObject>();
            }
            String queryString = this.compile();
            return this.executor.query(queryString);
        }

        public SObject queryOne() {
            List<SObject> result = this.query();
            if (result.isEmpty()) {
                return null;
            }
            return result.get(0);
        }
    }

    private class Subquery implements IField {
        private String subquery;

        public Subquery(String subquery) {
            this.subquery = subquery;
        }

        public String compile() {
            return '(' + this.subquery + ')';
        }

        public Boolean isIllogical() {
            return false;
        }

    }

    virtual class FieldValue implements IFieldValue {
        private Object value;

        public FieldValue(Object value) {
            this.value = value;
        }

        virtual public String compile() {
            return SoqlHelper.escape(String.valueOf(this.value));
        }

        virtual public Boolean isEmpty() {
            return false;
        }
    }

    class FieldValueString extends FieldValue {
        public FieldValueString(Object value) {
            super(value);
        }

        override public String compile() {
            if (String.valueOf(this.value).contains('LAST_N_')) {
                return super.compile();
            }
            if (String.valueOf(this.value).toUpperCase() == Soql.TODAY) {
                return super.compile();
            }
            if (String.valueOf(this.value).toUpperCase() == Soql.LAST_WEEK) {
                return super.compile();
            }
            if (String.valueOf(this.value).toUpperCase() == Soql.NULL_VALUE) {
                return super.compile();
            }
            return '\'' + SoqlHelper.escape(String.valueOf(this.value)) + '\'';
        }
    }

    class FieldValueDate extends FieldValue {
        public FieldValueDate(Object value) {
            super(value);
        }

        override public String compile() {
            return String.valueOf((Date)this.value);
        }
    }

    class FieldValueDatetime extends FieldValue {
        public FieldValueDatetime(Object value) {
            super(value);
        }

        override public String compile() {
            if (this.value == null) return null;
            return ((Datetime)this.value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'z\'');
        }
    }

    virtual class FieldValueList extends FieldValue {
        public FieldValueList(Object value) {
            super(value);
            SoqlHelper.removeNullFromList(this.value);
        }

        override public String compile() {
            return '(' + String.join((List<String>)this.value, ',') + ')';
        }

        override public Boolean isEmpty() {
            if (((List<Object>)this.value).size() < 1) {
                return true;
            }
            return false;
        }
    }

    class FieldValueListDefault extends FieldValueList {
        public FieldValueListDefault(Object value) {
            super(value);
            List<String> output = new List<String>();
            for (Object tmp : (List<Object>)this.value) {
                output.add(SoqlHelper.escape(String.valueOf(tmp)));
            }
            this.value = output;
        }
    }

    class FieldValueStringList extends FieldValueList {
        public FieldValueStringList(Object value) {
            super(value);
            List<String> output = new List<String>();
            for (Object tmp : (List<Object>)this.value) {
                output.add('\'' + SoqlHelper.escape(String.valueOf(tmp)) + '\'');
            }
            this.value = output;
        }
    }

    class FieldValueDateList extends FieldValueList {
        public FieldValueDateList(Object value) {
            super(value);
            List<String> output = new List<String>();
            for (Object tmp : (List<Object>)this.value) {
                output.add(String.valueOf((Date)tmp));
            }
            this.value = output;
        }
    }

    private class FilterFieldCollection extends FieldCollection {
        private String filterLogic;

        public FilterFieldCollection(String prefix, String separator) {
            super(prefix, separator);
        }

        public void filterLogic(String logic) {
            this.filterLogic = logic;
        }
        
        override public String compile() {
            if (this.fields.size() < 1) return '';

            String[] output = new String[]{};
            for (IField field : this.fields) {
                output.add(field.compile());
            }

            if (String.isNotBlank(this.filterLogic)) {
                if (output.size() != this.filterLogic.countMatches('{')) {
                    System.System.debug('Filter logic does not match number of filters.');
                }
                return this.prefix + ' ' + String.format(this.filterLogic, output);
            }
            
            return this.prefix + ' ' + String.join(output, this.separator);
        }
    }

    virtual class FieldCollection {
        private String prefix;
        private String separator;
        private IField[] fields = new IField[]{};

        public FieldCollection(String prefix, String separator) {
            this.prefix = prefix;
            this.separator = separator;
        }

        public FieldCollection(String separator) {
            this.prefix = '';
            this.separator = separator;
        }

        public void add(IField field) {
            this.fields.add(field);
        }

        virtual public String compile() {
            if (this.fields.size() < 1) {
                return '';
            }
            String[] output = new String[]{};
            for (IField field : this.fields) {
                output.add(field.compile());
            }
            return this.prefix + ' ' + String.join(output, this.separator);
        }

        virtual public Boolean hasIllogicalFilters() {
            for (IField field : this.fields) {
                if (field.isIllogical()) {
                    return true;
                }
            }
            return false;
        }
    }

    private class FilterField implements IField {
        private String field;
        private String operator;
        private IFieldValue value;

        public FilterField(String field, String operator, IFieldValue value) {
            this.field = field;
            this.operator = operator;
            this.value = value;
        }

        public String compile() {
            return this.field + ' ' + this.operator + ' ' + this.value.compile();
        }

        public Boolean isIllogical() {
            return this.value.isEmpty();
        }
    }

    private class GroupByField implements  IField {
        private String field;

        public GroupByField(String field) {
            this.field = field;
        }

        public String compile() {
            return this.field;
        }

        public Boolean isIllogical() {
            return false;
        }

    }

    private class HavingField implements IField {
        private String field;
        private String aggregateFunction;
        private String operator;
        private IFieldValue value;

        public HavingField(String field, String aggregateFunction, String operator, IFieldValue value) {
            this.field = field;
            this.operator = operator;
            this.aggregateFunction = aggregateFunction;
            this.value = value;
        }

        public String compile() {
            return this.aggregateFunction + '(' + this.field + ') ' + this.operator + ' ' + this.value.compile();
        }

        public Boolean isIllogical() {
            return this.value.isEmpty();
        }
    }

    private class OrderByField implements IField {
        private String field;
        private String direction;

        public OrderByField(String field, String direction) {
            this.field = field;
            this.direction = direction;
        }

        public String compile() {
            return this.field + ' ' + this.direction.toUpperCase();
        }

        public Boolean isIllogical() {
            return false;
        }
    }

    private class LimitField implements IField {
        private Integer limitCount = 0;

        public String compile() {
            return this.limitCount == 0 ? '' : 'LIMIT ' + String.valueOf(this.limitCount);
        }

        public Boolean isIllogical() {
            return false;
        }
    }

    private class OffsetField implements IField {
        private Integer offset = 0;

        public String compile() {
            return this.offset == 0 ? '' : 'OFFSET ' + String.valueOf(this.offset);
        }

        public Boolean isIllogical() {
            return false;
        }
    }

    private class AllRows implements IField {
        private Boolean allRows = false;

        public String compile() {
            return this.allRows ? 'ALL ROWS' : '';
        }

        public Boolean isIllogical() {
            return false;
        }
    }

    private class LockRows implements IField {
        private Boolean lockRows = false;

        public String compile() {
            return this.lockRows ? 'FOR UPDATE' : '';
        }

        public Boolean isIllogical() {
            return false;
        }
    }
}