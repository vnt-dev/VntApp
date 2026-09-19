package com.rustvnt.vntapp;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNull;
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

    @Test public void startupDuplicateIsAcknowledgedAfterRevisionCommit() {
        assertNull(SubscriptionConfig.settledAckStatus(7, 6));
        assertEquals("applied", SubscriptionConfig.settledAckStatus(7, 7));
        assertEquals("superseded", SubscriptionConfig.settledAckStatus(6, 7));
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
