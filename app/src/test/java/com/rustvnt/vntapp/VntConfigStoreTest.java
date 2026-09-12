package com.rustvnt.vntapp;

import static org.junit.Assert.fail;

import org.junit.Test;

public class VntConfigStoreTest {
    @Test public void allowsOneServerWithoutFixedIp() throws Exception {
        validate("quic://vpn.example.com:29872", "");
    }

    @Test public void rejectsNoServerWithoutFixedIp() {
        assertInvalid("", "", "未配置服务器时必须填写虚拟 IP/CIDR");
    }

    @Test public void rejectsMultipleServersWithoutFixedIp() {
        assertInvalid("quic://one.example:29872\nquic://two.example:29872", "",
                "配置多个服务器时必须填写虚拟 IP/CIDR");
    }

    @Test public void allowsNoOrMultipleServersWithFixedIp() throws Exception {
        validate("", "10.26.0.2/24");
        validate("quic://one.example:29872\nquic://two.example:29872", "10.26.0.3/24");
    }

    @Test public void rejectsBlankNetworkCode() {
        assertInvalid("quic://vpn.example.com:29872", "", "网络编号不能为空", " ");
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
