public without sharing class SoqlHelper {
    public static String escape(String input) {
        return String.isBlank(input) ? input : String.escapeSingleQuotes(input);
    }

    public static String getType(Object o) {
        if(o==null) return '';              // we can't say much about null with our current techniques
        if(o instanceof List<Object>)       return 'List'; // Must be before instanceof sobject since a list cant be cast to sObject
        if(o instanceof Set<String>)        return 'Set';
        if(o instanceof Set<Id>)            return 'Set';
        if(o instanceof Set<Date>)          return 'Set';
        if(o instanceof Map<String,Object>) return 'Map';
        if(o instanceof Map<Id,Object>)     return 'Map';
        if(o instanceof String)             return 'String';
        if(o instanceof SObject)            return ((SObject)o).getSObjectType().getDescribe().getName();
        if(o instanceof Boolean)            return 'Boolean';
        if(o instanceof Id)                 return 'Id';
        if(o instanceof String)             return 'String';
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return 'Date';
        if(o instanceof Datetime)           return 'Datetime';
        if(o instanceof Time)               return 'Time';
        if(o instanceof Integer)            return 'Integer';
        if(o instanceof Long)               return 'Long';
        if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
        if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
        
        try {
            Datetime tmp = (Datetime)o;
        } catch (Exception e) {
            Matcher matcher = Pattern.compile('Invalid conversion from runtime type ([a-zA-Z]+).*')
                .matcher(e.getMessage());
            if(matcher.matches()) {
                return matcher.group(1);
            }
        }
        
        return 'Object';
    }
    
    public static Boolean isConvertibleSet(Object s) {
        try {
            Object t = convertSetToList(s);
            return true;
        } catch(Exception e) {
            return false;
        }
    }

    public static Object convertSetToList(Object s) {
        if(s instanceof Set<Id>) return new List<Id>((Set<Id>)s);
        if(s instanceof Set<String>) return new List<String>((Set<String>)s);
        if(s instanceof Set<Date>) return new List<Date>((Set<Date>)s);
        if(s instanceof Set<Datetime>) return new List<Datetime>((Set<Datetime>)s);
        if(s instanceof Set<Time>) return new List<Time>((Set<Time>)s);
        if(s instanceof Set<Integer>) return new List<Integer>((Set<Integer>)s);
        if(s instanceof Set<Long>) return new List<Long>((Set<Long>)s);
        if(s instanceof Set<Decimal>) return new List<Decimal>((Set<Decimal>)s);
        if(s instanceof Set<Double>) return new List<Double>((Set<Double>)s);
        throw new SoqlHelperException('Could not convert Set to List because the type of not supported: ' + JSON.serialize(s));
    }

    public static void removeNullFromList(Object lst) {
        for (Integer i = 0; i < ((List<Object>)lst).size(); ++i) {
            if (((List<Object>)lst).get(i) == null) {
                ((List<Object>)lst).remove(i);
            }
        }
    }

    public static Id getFakeId(Schema.SObjectType sobjectType) {
        String keyPrefix = sobjectType.getDescribe().getKeyPrefix();
		return Id.valueOf(keyPrefix + '000000000000');
    }

    public class DatabaseCacheInventory {
        private Map<String, InventoryItem> items = new Map<String, InventoryItem>();

        public void put(String query, List<SObject> result) {
            this.items.put(sanitizeQuery(query), new InventoryItem(result));
        }

        public InventoryItem get(String query) {
            String key = sanitizeQuery(query);
            if (!this.items.containsKey(key)) return null;
            InventoryItem item = this.items.get(key);
            if (item.hasExpired() || item.get() == null) {
                return null;
            }
            return item;
        }

        public Boolean containsKey(String query) {
            String key = sanitizeQuery(query);
            return this.items.containsKey(key);
        }

        public String sanitizeQuery(String query) {
            return generateSafeCacheKeyIgnoreCase(query.deleteWhitespace());
        }

        private String generateSafeCacheKeyIgnoreCase(String cacheKeyString) {
            return md5(cacheKeyString.toLowerCase()).left(16);
        }

        private String md5(String input) {
            Blob b = Blob.valueOf(input);
            Blob hash = Crypto.generateDigest('MD5', b);
            return EncodingUtil.convertToHex(hash);
        }
    }

    public class InventoryItem {
        private final Integer ONE_HOUR = 3600;

        private Object value;
        private Datetime expiresAt;
        private Datetime createdAt;

        public InventoryItem(Object value) {
            this.value = value;
            this.createdAt = Datetime.now();
            this.expiresAt = Datetime.now().addSeconds(ONE_HOUR);
        }

        public Boolean hasExpired() {
            return this.expiresAt < Datetime.now();
        }

        public Object get() {
            return this.value;
        }
    }

    public class SoqlHelperException extends Exception {}
}