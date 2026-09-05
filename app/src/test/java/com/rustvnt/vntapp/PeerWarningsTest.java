package com.rustvnt.vntapp;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.vnt.VntApi;
import java.util.Collections;
import java.util.List;
import org.junit.Test;

public class PeerWarningsTest {
    @Test public void warnsForOnlineIkev2WhenDisabled() {
        assertTrue(PeerWarnings.hasUnreachableIkev2(false, List.of(client("IKEV2", true))));
    }

    @Test public void doesNotWarnWhenIkev2IsAllowed() {
        assertFalse(PeerWarnings.hasUnreachableIkev2(true, List.of(client("IKEV2", true))));
    }

    @Test public void doesNotWarnForOfflineIkev2OrVntClients() {
        assertFalse(PeerWarnings.hasUnreachableIkev2(false,
                List.of(client("IKEV2", false), client("VNT", true))));
    }

    @Test public void doesNotWarnForEmptyOrMissingList() {
        assertFalse(PeerWarnings.hasUnreachableIkev2(false, Collections.emptyList()));
        assertFalse(PeerWarnings.hasUnreachableIkev2(false, null));
    }

    private static VntApi.ClientInfo client(String type, boolean online) {
        return new VntApi.ClientInfo("10.26.0.2", "test", "", type, online, false,
                null, null, null, 0, null, null);
    }
}
