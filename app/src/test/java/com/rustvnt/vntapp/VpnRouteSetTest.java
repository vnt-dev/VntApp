package com.rustvnt.vntapp;

import static org.junit.Assert.*;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.Test;

public class VpnRouteSetTest {
    @Test public void normalizesAndDeduplicatesAllRouteSources() {
        List<VpnRouteSet.Route> routes = VpnRouteSet.build(
                "10.26.0.8", 24,
                List.of("192.168.1.42/24"),
                List.of("172.16.0.0/16,10.26.0.2"),
                List.of("192.168.1.0/24,10.26.0.3", "172.16.0.0/16,10.26.0.2"));
        assertEquals(
                List.of("10.26.0.0/24", "192.168.1.0/24", "172.16.0.0/16"),
                routes.stream().map(VpnRouteSet.Route::cidr).collect(Collectors.toList()));
    }

    @Test public void targetChangeDoesNotChangeAndroidCidrSet() {
        Set<String> first = VpnRouteSet.cidrs(List.of("192.168.0.0/24,10.26.0.2"));
        Set<String> second = VpnRouteSet.cidrs(List.of("192.168.0.0/24,10.26.0.9"));
        assertEquals(first, second);
    }

    @Test public void keepsOverlappingCidrsForLongestPrefixRouting() {
        assertEquals(
                Set.of("192.168.0.0/24", "192.168.0.0/25"),
                VpnRouteSet.cidrs(List.of(
                        "192.168.0.0/24,10.26.0.2",
                        "192.168.0.0/25,10.26.0.3")));
    }

    @Test public void rejectsInvalidIpv4Route() {
        assertThrows(IllegalArgumentException.class,
                () -> VpnRouteSet.cidrs(List.of("192.168.999.0/24,10.26.0.2")));
    }
}
