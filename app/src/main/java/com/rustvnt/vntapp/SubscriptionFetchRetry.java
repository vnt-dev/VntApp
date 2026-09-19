package com.rustvnt.vntapp;

/** Small platform-neutral retry loop so subscription startup behavior is unit-testable. */
final class SubscriptionFetchRetry {
    interface Fetcher { String fetch() throws Throwable; }
    interface Cancellation { boolean requested(); }
    interface Waiter { void waitFor(long delayMs) throws InterruptedException; }
    interface FailureReporter { void onFailure(long attempt, Throwable error); }

    private SubscriptionFetchRetry() {}

    static String fetch(Fetcher fetcher, Cancellation cancellation, Waiter waiter,
                        FailureReporter reporter, long retryDelayMs) throws InterruptedException {
        long attempts = 0;
        while (!cancellation.requested()) {
            try {
                return fetcher.fetch();
            } catch (Throwable error) {
                if (cancellation.requested()) break;
                reporter.onFailure(++attempts, error);
                waiter.waitFor(retryDelayMs);
            }
        }
        throw new InterruptedException("启动已取消");
    }
}
