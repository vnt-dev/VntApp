package com.vnt;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;

import java.util.Arrays;

public class RuntimeChangeDnsTest {
    @Test public void readsDnsInOrderFromRuntimeSnapshot() throws Exception {
        RuntimeChange change = parse("{\"dns\":[\"10.26.0.3\",\"223.5.5.5\"]}");
        assertEquals(Arrays.asList("10.26.0.3", "223.5.5.5"), change.getDns());
    }

    @Test public void distinguishesClearingDnsFromAnOlderCoreOmittingIt() throws Exception {
        assertTrue(parse("{\"dns\":[]}").getDns().isEmpty());
        assertNull(parse("{}").getDns());
    }

    private static RuntimeChange parse(String config) throws Exception {
        return RuntimeChange.fromJson(new JSONObject()
                .put("config", new JSONObject(config))
                .put("routes", new JSONArray()));
    }
}
