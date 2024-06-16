@IsTest(IsParallel=true)
private class SoqlTest {
    private static Integer TEST_SIZE = 20;
    private static String OBJECT_NAME = 'Account';

    @TestSetup 
    private static void setup() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < TEST_SIZE; ++i) {
            Account account = new Account(
                Name = 'Test ' + String.valueOf(i),
                Description = 'Test ' + String.valueOf(i),
                NumberOfEmployees = 100 * (i + 1)
            );
            accounts.add(account);
        }
        insert accounts;
    }

    // private static Id getId() {
    //     return fflib_IDGenerator.generate(Account.sObjectType);
    // }

    @IsTest 
    private static void validateSelect() {
        List<Account> result = Soql.fetch(OBJECT_NAME).query();
        Assert.areEqual(result.size(), TEST_SIZE);
    }

    @IsTest 
    private static void validateSelectSingleField() {
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').query();
        Assert.areEqual(
            new Set<String> {'Id', 'Name'},
            result.get(0).getPopulatedFieldsAsMap().keySet()
        );
    }

    // @IsTest 
    // private static void validateSelectFilter() {
    //     List<Account> result = Soql.fetch(OBJECT_NAME).filter('NumberOfEmployees', (Double)100).query();
    //     Assert.areEqual(1, result.size());
    // }

    // @IsTest 
    // private static void validateSelectFilterIn() {
    //     List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').filter('NumberOfEmployees', new Double[] {100, 200, 300}).query();
    //     Assert.areEqual(3, result.size());
    // }

    // @IsTest 
    // private static void validateSelectNegativeFilter() {
    //     List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').filterNot('NumberOfEmployees', 100).query();
    //     Assert.areEqual(TEST_SIZE - 1, result.size());
    // }

    // @IsTest 
    // private static void validateSelectNegativeFilterIn() {
    //     List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').filterNot('NumberOfEmployees', new Double[] {100, 200, 300}).query();
    //     Assert.areEqual(TEST_SIZE - 3, result.size());
    // }

    @IsTest 
    private static void filterTypeBoolean() {
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').filter('IsDeleted', false).query();
        Assert.areEqual(TEST_SIZE, result.size());
    }

    @IsTest 
    private static void filterLike() {
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').filterLike('Name', '%Test%').query();
        Assert.areEqual(TEST_SIZE, result.size());
    }

    @IsTest 
    private static void withLimit() {
        Integer expectedResult = 5;
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').withLimit(expectedResult).query();
        Assert.areEqual(expectedResult, result.size());
    }

    @IsTest 
    private static void fromOffset() {
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').fromOffset(5).query();
        Assert.areEqual(TEST_SIZE - 5, result.size());
    }

    @IsTest 
    private static void allRows_ReturnsDeleted() {
        delete Soql.fetch(OBJECT_NAME).field('Name').query();
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').allRows().query();
        Assert.areEqual(TEST_SIZE, result.size());
    }

    @IsTest 
    private static void lockRows_NoExceptionThrown() {
        List<Account> result = Soql.fetch(OBJECT_NAME).field('Name').lockRows().query();
        Assert.areEqual(TEST_SIZE, result.size());
    }

    @IsTest 
    private static void lockRows_MakeSureQueryCompilesCorrect() {
        Assert.areEqual(true, Soql.fetch(OBJECT_NAME).field('Name').lockRows().compile().contains('FOR UPDATE'));
    }

    @IsTest 
    private static void groupBy() {
        Account ex1 = new Account(
            Name = 'Test 1',
            NumberOfEmployees = 100
        );
        insert ex1;
        Account ex2 = new Account(
            Name = 'Test 1',
            NumberOfEmployees = 100
        );
        insert ex2;
        List<AggregateResult> result = Soql.fetch(OBJECT_NAME)
            .fields(new List<String> {'Name', 'COUNT(Id) Cnt'})
            .filter('Name', 'Test 1')
            .groupBy('Name')
            .query();
        Assert.areEqual(3, result.get(0).get('Cnt'));
    }

    @IsTest 
    private static void havingCount() {
        Account ex1 = new Account(
            Name = 'Test 1',
            NumberOfEmployees = 100
        );
        insert ex1;
        Account ex2 = new Account(
            Name = 'Test 1',
            NumberOfEmployees = 100
        );
        insert ex2;
        List<AggregateResult> result = Soql.fetch(OBJECT_NAME)
            .fields(new List<String> {'Name', 'COUNT(Id) Cnt'})
            .groupBy('Name')
            .havingCount('Id', Soql.GREATER_THAN, 1)
            .query();
        Assert.areEqual(1, result.size());
    }

    @IsTest 
    private static void validateOrderBy() {
        List<Account> result = Soql.fetch(OBJECT_NAME).orderBy('NumberOfEmployees', 'DESC').query();
        Assert.areEqual(2000.00, result.get(0).get('NumberOfEmployees'));

        result = Soql.fetch(OBJECT_NAME).orderBy('NumberOfEmployees', 'ASC').query();
        Assert.areEqual(100.00, result.get(0).NumberOfEmployees);
    }

    // @IsTest 
    // private static void validateComplexBuild() {
    //     List<Account> result = Soql.fetch(OBJECT_NAME)
    //         .field('Name')
    //         .fields(new String[]{'Id', 'CreatedDate'})
    //         .filter('NumberOfEmployees', '>', 500.00)
    //         .filter('NumberOfEmployees', '<', TEST_SIZE * 100)
    //         .filter('IsDeleted', false)
    //         .withLimit(10)
    //         .fromOffset(5)
    //         .query();

    //     Assert.areEqual('Test 10', result.get(0).Name);
    // }

    @IsTest 
    private static void sessionCache() {
        List<Account> exceptions = Soql.fetch(OBJECT_NAME).field('Name').useCache().query();
        Assert.areEqual(TEST_SIZE, exceptions.size());

        Account e = new Account(
            Name = 'Test ' + String.valueOf(TEST_SIZE + 1),
            NumberOfEmployees = 1
        );
        insert e;
        System.assertNotEquals(null, e.Id);

        // With cache
        exceptions = Soql.fetch(OBJECT_NAME).field('Name').useCache().query();
        Assert.areEqual(TEST_SIZE, exceptions.size());

        // Without cache
        exceptions = Soql.fetch(OBJECT_NAME).field('Name').query();
        Assert.areEqual(TEST_SIZE + 1, exceptions.size());
    }

    @IsTest 
    private static void prepareString() {
        String query = 'SELECT Id FROM Something WHERE Name=:name';
        Assert.areEqual(
            query.replace(':name', '\'Test\''),
            new Soql.Query(query, new Map<String, Object> {'name' => 'Test'}).prepare()
        );
    }

    @IsTest 
    private static void prepareInteger() {
        String query = 'SELECT Id FROM Something WHERE Number=:num';
        Assert.areEqual(
            query.replace(':number', '1'),
            new Soql.Query(query, new Map<String, Object> {'number' => 1}).prepare()
        );
    }

    @IsTest 
    private static void prepareLastNDays() {
        String query = 'SELECT Id FROM Something WHERE DateCreated=:last_n_days';
        Assert.areEqual(
            query.replace(':last_n_days', 'LAST_N_DAYS:5'),
            new Soql.Query(query, new Map<String, Object> {'last_n_days' => 'LAST_N_DAYS:5'}).prepare()
        );
    }

    // @IsTest 
    //private static void prepareId() {
    //     String query = 'SELECT Id FROM Something WHERE Id=:id';
    //     Id testId = getId();
    //     Assert.areEqual(
    //         query.replace(':id', '\'' + testId + '\''),
    //         new Soql.Query(query, new Map<String, Id> {'id' => testId}).prepare()
    //     );
    // }

    @IsTest 
    private static void prepareStringList() {
        String query = 'SELECT Id FROM Something WHERE Name IN :names';
        Assert.areEqual(
        query.replace(':names', '(\'A\',\'B\',\'C\')'),
        new Soql.Query(query, new Map<String, Object> {'names' => new List<String>{'A', 'B', 'C'}}).prepare()
        );
    }

    // @IsTest 
    //private static void prepareIdList() {
    //     String query = 'SELECT Id FROM Something WHERE Name IN :ids';
    //     Id id = getId();
    //     Assert.areEqual(
    //         query.replace(':ids', '(\'' + String.valueOf(id) + '\')'),
    //         new Soql.Query(query, new Map<String, Object> {'ids' => new List<Id>{id}}).prepare()
    //     );
    // }

    @IsTest 
    private static void prepareDateList() {
        String query = 'SELECT Id FROM Something WHERE DateCreated IN :dates';
        Assert.areEqual(
            query.replace(':dates', '(1970-01-01,1971-01-01,1972-01-01)'),
            new Soql.Query(query, new Map<String, Object> {'dates' => new List<Date>{
                Date.newInstance(1970, 1, 1),
                Date.newInstance(1971, 1, 1),
                Date.newInstance(1972, 1, 1)
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareDatetimeList() {
        String query = 'SELECT Id FROM Something WHERE DateCreated IN :dates';
        Assert.areEqual(
            query.replace(':dates', '(1970-01-01 01:01:01,1971-01-01 01:01:01,1972-01-01 01:01:01)'),
            new Soql.Query(query, new Map<String, Object> {'dates' => new List<Datetime>{
                Datetime.newInstanceGmt(1970, 1, 1, 1, 1, 1),
                Datetime.newInstanceGmt(1971, 1, 1, 1, 1, 1),
                Datetime.newInstanceGmt(1972, 1, 1, 1, 1, 1)
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareTimeList() {
        String query = 'SELECT Id FROM Something WHERE TimeCreated IN :times';
        Assert.areEqual(
            query.replace(':times', '(01:02:03.004Z,05:06:07.008Z)'),
            new Soql.Query(query, new Map<String, Object> {'times' => new List<Time>{
                Time.newInstance(1, 2, 3, 4),
                Time.newInstance(5, 6, 7, 8)
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareIntegerList() {
        String query = 'SELECT Id FROM Something WHERE Number IN :numbers';
        Assert.areEqual(
            query.replace(':numbers', '(1,2,3)'),
            new Soql.Query(query, new Map<String, Object> {'numbers' => new List<Integer>{
                1, 2, 3
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareLongList() {
        String query = 'SELECT Id FROM Something WHERE Number IN :numbers';
        Assert.areEqual(
            query.replace(':numbers', '(1,2,3)'),
            new Soql.Query(query, new Map<String, Object> {'numbers' => new List<Integer>{
                1, 2, 3
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareDecimalList() {
        String query = 'SELECT Id FROM Something WHERE Number IN :numbers';
        Assert.areEqual(
            query.replace(':numbers', '(1.01,2.02,3.03)'),
            new Soql.Query(query, new Map<String, Object> {'numbers' => new List<Decimal>{
                1.01, 2.02, 3.03
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareDoubleList() {
        String query = 'SELECT Id FROM Something WHERE Number IN :numbers';
        Assert.areEqual(
            query.replace(':numbers', '(1.01,2.02,3.03)'),
            new Soql.Query(query, new Map<String, Object> {'numbers' => new List<Decimal>{
                1.01, 2.02, 3.03
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareListWithNull() {
        String query = 'SELECT Id FROM Something WHERE Number IN :numbers';
        Assert.areEqual(
            query.replace(':numbers', '(1,2,3)'),
            new Soql.Query(query, new Map<String, Object> {'numbers' => new List<Integer>{
                1, 2, 3, null
            }}).prepare()
        );
    }

    @IsTest 
    private static void prepareStringSet() {
        String query = 'SELECT Id FROM Something WHERE Name IN :names';
        Assert.areEqual(
            query.replace(':names', '(\'A\',\'B\',\'C\')'),
            new Soql.Query(query, new Map<String, Object> {'names' => new Set<String>{'A', 'B', 'C'}}).prepare()
        );
    }

    // @IsTest 
    // private static void prepareIdSet() {
    //     String query = 'SELECT Id FROM Something WHERE Name IN :ids';
    //     Id id = RecordTypeHelper.ACCOUNT_BUSINESS;
    //     Assert.areEqual(
    //         query.replace(':ids', '(\'' + String.valueOf(id) + '\')'),
    //         new Soql.Query(query, new Map<String, Object> {'ids' => new Set<Id>{id}}).prepare()
    //     );
    // }
}