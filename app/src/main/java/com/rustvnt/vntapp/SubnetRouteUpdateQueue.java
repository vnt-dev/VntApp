package com.rustvnt.vntapp;

final class SubnetRouteUpdateQueue {
    private String latest;
    private boolean drainScheduled;
    private boolean closed;

    synchronized boolean offer(String routesJson) {
        if (closed) return false;
        latest = routesJson;
        if (drainScheduled) return false;
        drainScheduled = true;
        return true;
    }

    synchronized String take() {
        if (closed) {
            drainScheduled = false;
            latest = null;
            return null;
        }
        String routesJson = latest;
        latest = null;
        if (routesJson == null) drainScheduled = false;
        return routesJson;
    }

    synchronized void reset() {
        latest = null;
        drainScheduled = false;
        closed = false;
    }

    synchronized void close() {
        closed = true;
        latest = null;
    }
}
