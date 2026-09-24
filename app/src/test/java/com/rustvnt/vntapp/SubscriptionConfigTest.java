package com.rustvnt.vntapp;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class SubscriptionConfigTest {
    @Test public void instanceIdIsStableShapeAndRandom() {
        String first = SubscriptionConfig.newInstanceId();
        String second = SubscriptionConfig.newInstanceId();
        assertEquals(64, first.length());
        assertTrue(first.matches("[0-9a-f]{64}"));
        assertNotEquals(first, second);
    }

    @Test public void onlyExplicitNoDeviceModeSkipsVpnPermission() {
        assertFalse(SubscriptionConfig.requiresVpn("no"));
        assertFalse(SubscriptionConfig.requiresVpn(" NO "));
        assertTrue(SubscriptionConfig.requiresVpn("tun"));
        assertTrue(SubscriptionConfig.requiresVpn("tap"));
        assertTrue(SubscriptionConfig.requiresVpn(""));
        assertTrue(SubscriptionConfig.requiresVpn(null));
    }
}
