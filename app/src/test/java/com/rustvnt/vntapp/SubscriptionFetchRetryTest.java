package com.rustvnt.vntapp;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.Test;

public class SubscriptionFetchRetryTest {
    @Test public void retriesFailureThenReturnsFetchedConfig() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        List<String> failures = new ArrayList<>();
        List<Long> delays = new ArrayList<>();

        String result = SubscriptionFetchRetry.fetch(
                () -> calls.incrementAndGet() == 1
                        ? throwFailure("temporary failure") : "{\"revision\":1}",
                () -> false,
                delays::add,
                (attempt, error) -> failures.add(attempt + ":" + error.getMessage()),
                5_000L);

        assertEquals("{\"revision\":1}", result);
        assertEquals(2, calls.get());
        assertEquals(List.of("1:temporary failure"), failures);
        assertEquals(List.of(5_000L), delays);
    }

    @Test public void cancellationAfterFailurePreventsAnotherFetch() {
        AtomicInteger calls = new AtomicInteger();
        AtomicBoolean cancelled = new AtomicBoolean();

        try {
            SubscriptionFetchRetry.fetch(
                    () -> { calls.incrementAndGet(); throw new IllegalStateException("offline"); },
                    cancelled::get,
                    ignored -> { },
                    (attempt, error) -> cancelled.set(true),
                    5_000L);
            fail("Expected cancellation");
        } catch (InterruptedException error) {
            assertTrue(error.getMessage().contains("启动已取消"));
        }

        assertEquals(1, calls.get());
    }

    private static String throwFailure(String message) {
        throw new IllegalStateException(message);
    }
}
