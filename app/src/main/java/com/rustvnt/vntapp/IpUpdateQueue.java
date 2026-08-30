package com.rustvnt.vntapp;

final class IpUpdateQueue {
    record Request(long requestId, String ip, int prefixLen) {}

    private Request latest;
    private long newestRequestId;
    private boolean drainScheduled;
    private boolean closed;

    synchronized boolean offer(Request request) {
        // Rust reuses the request id while the same target IP is pending. Ignore
        // duplicate or late callbacks so a completed switch cannot be prepared again.
        if (closed || request.requestId() <= newestRequestId) return false;
        newestRequestId = request.requestId();
        latest = request;
        if (drainScheduled) return false;
        drainScheduled = true;
        return true;
    }

    synchronized Request take() {
        if (closed) {
            drainScheduled = false;
            latest = null;
            return null;
        }
        Request request = latest;
        latest = null;
        if (request == null) drainScheduled = false;
        return request;
    }

    synchronized void reset() {
        latest = null;
        newestRequestId = 0;
        drainScheduled = false;
        closed = false;
    }

    synchronized void close() {
        closed = true;
        latest = null;
    }
}
