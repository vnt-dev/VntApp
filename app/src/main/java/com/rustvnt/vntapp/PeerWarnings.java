package com.rustvnt.vntapp;

import com.vnt.VntApi;
import java.util.List;

final class PeerWarnings {
    private PeerWarnings() { }

    static boolean hasUnreachableIkev2(boolean allowIkev2, List<VntApi.ClientInfo> clients) {
        if (allowIkev2 || clients == null) return false;
        for (VntApi.ClientInfo client : clients) {
            if (client.online() && "IKEV2".equalsIgnoreCase(client.clientType())) return true;
        }
        return false;
    }
}
