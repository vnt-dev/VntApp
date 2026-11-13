package com.rustvnt.vntapp;

import static org.junit.Assert.fail;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.List;

public class VntConfigStoreTest {
    @Test public void allowsOneServerWithoutExplicitIp() throws Exception {
        validate("quic://vpn.example.com:29872", "");
    }

    @Test public void rejectsNoServerWithoutExplicitIp() {
        assertInvalid("", "", "未配置服务器时必须填写虚拟 IP/CIDR");
    }

    @Test public void rejectsMultipleServersWithoutExplicitIp() {
        assertInvalid("quic://one.example:29872\nquic://two.example:29872", "",
                "配置多个服务器时必须填写虚拟 IP/CIDR");
    }

    @Test public void allowsNoOrMultipleServersWithExplicitIp() throws Exception {
        validate("", "10.26.0.2/24");
        validate("quic://one.example:29872\nquic://two.example:29872", "10.26.0.3/24");
    }

    @Test public void rejectsBlankNetworkCode() {
        assertInvalid("quic://vpn.example.com:29872", "", "网络编号不能为空", " ");
    }

    @Test public void createsExclusiveSubscriptionProfile() {
        VntConfigStore.Profile profile = VntConfigStore.Profile.createSubscription(
                "公司网络", "vnt2://join/2/example", null);
        assertTrue(profile.isSubscription());
        assertEquals("{}", profile.json);
        assertEquals("vnt2://join/2/example", profile.subscription);
    }

    @Test public void changingSubscriptionKeepsProfileIdentity() {
        VntConfigStore.Profile original = new VntConfigStore.Profile(
                "id", "公司网络", "{}", VntConfigStore.Profile.MODE_SUBSCRIPTION,
                "vnt2://join/2/old");
        VntConfigStore.Profile renamed = VntConfigStore.Profile.createSubscription(
                "新名称", "vnt2://join/2/old", original);
        assertEquals("id", renamed.id);
        assertEquals("新名称", renamed.name);
        assertEquals("vnt2://join/2/old", renamed.subscription);
    }

    @Test public void rejectsNonSubscriptionLink() {
        try {
            VntConfigStore.Profile.createSubscription("bad", "https://example.com/config", null);
            fail("Expected subscription validation to fail");
        } catch (IllegalArgumentException error) {
            assertEquals("订阅链接格式无效", error.getMessage());
        }
    }

    @Test public void rejectsLegacySubscriptionLink() {
        try {
            VntConfigStore.Profile.createSubscription("bad", "vnt2://join/1/legacy", null);
            fail("Expected legacy subscription link to be rejected");
        } catch (IllegalArgumentException error) {
            assertEquals("订阅链接格式无效", error.getMessage());
        }
    }

    @Test public void rejectsMtuBelowCoreMinimum() {
        assertInvalidMtu(1279);
    }

    @Test public void rejectsMtuAboveInterfaceMaximum() {
        assertInvalidMtu(9001);
    }

    @Test public void acceptsCoreMtuRange() {
        VntConfigStore.Profile.validateMtu(1280);
        VntConfigStore.Profile.validateMtu(9000);
    }

    @Test public void acceptsValidIpv4() {
        assertTrue(VntConfigStore.Profile.isValidIpv4("10.26.0.3"));
        assertTrue(VntConfigStore.Profile.isValidIpv4("223.5.5.5"));
        assertTrue(VntConfigStore.Profile.isValidIpv4("0.0.0.0"));
        assertTrue(VntConfigStore.Profile.isValidIpv4("255.255.255.255"));
    }

    @Test public void rejectsInvalidIpv4() {
        assertFalse(VntConfigStore.Profile.isValidIpv4("256.1.1.1"));
        assertFalse(VntConfigStore.Profile.isValidIpv4("10.26.0"));
        assertFalse(VntConfigStore.Profile.isValidIpv4("10.26.0.3.4"));
        assertFalse(VntConfigStore.Profile.isValidIpv4("abc"));
        assertFalse(VntConfigStore.Profile.isValidIpv4(""));
        assertFalse(VntConfigStore.Profile.isValidIpv4("10.26..3"));
        assertFalse(VntConfigStore.Profile.isValidIpv4(null));
    }

    @Test public void collectsValidDnsWhenTunnelEnabled() {
        List<String> dns = VntConfigStore.Profile.validateDnsServers(true, "10.26.0.3\n223.5.5.5");
        assertEquals(2, dns.size());
        assertEquals("10.26.0.3", dns.get(0));
        assertEquals("223.5.5.5", dns.get(1));
    }

    @Test public void ignoresDnsWhenTunnelDisabled() {
        List<String> dns = VntConfigStore.Profile.validateDnsServers(false, "10.26.0.3\nbad-value");
        assertTrue(dns.isEmpty());
    }

    @Test public void rejectsInvalidDnsWhenTunnelEnabled() {
        try {
            VntConfigStore.Profile.validateDnsServers(true, "10.26.0.3\nnot-an-ip");
            fail("Expected DNS validation to fail");
        } catch (IllegalArgumentException error) {
            assertTrue(error.getMessage().contains("DNS 地址无效"));
        }
    }

    @Test public void omitsDnsWhenTunnelDisabled() {
        // 纯逻辑：关闭走隧道时不收集任何地址（即使原文本含非法项也不校验）。
        assertTrue(VntConfigStore.Profile.validateDnsServers(false, "10.26.0.3\nnot-an-ip").isEmpty());
        assertTrue(VntConfigStore.Profile.validateDnsServers(false, "").isEmpty());
    }

    @Test public void emptyDnsYieldsEmptyListWhenTunnelOn() {
        assertTrue(VntConfigStore.Profile.validateDnsServers(true, "").isEmpty());
        assertTrue(VntConfigStore.Profile.validateDnsServers(true, "\n , ").isEmpty());
    }

    private static void assertInvalidMtu(int mtu) {
        try {
            VntConfigStore.Profile.validateMtu(mtu);
            fail("Expected MTU validation to fail");
        } catch (Exception error) {
            assertEquals("MTU 必须在 1280-9000 之间", error.getMessage());
        }
    }

    private static void validate(String servers, String ip) {
        VntConfigStore.Profile.validateBasicConfig(servers, "team-prod-net", ip);
    }

    private static void assertInvalid(String servers, String ip, String expectedMessage) {
        assertInvalid(servers, ip, expectedMessage, "team-prod-net");
    }

    private static void assertInvalid(String servers, String ip, String expectedMessage, String networkCode) {
        try {
            VntConfigStore.Profile.validateBasicConfig(servers, networkCode, ip);
            fail("Expected configuration validation to fail");
        } catch (Exception error) {
            org.junit.Assert.assertEquals(expectedMessage, error.getMessage());
        }
    }
}
