package com.rustvnt.vntapp;

import static org.junit.Assert.fail;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

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
