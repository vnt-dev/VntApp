package com.rustvnt.vntapp;

import static org.junit.Assert.*;
import org.junit.Test;

public class SubnetRouteUpdateQueueTest {
    @Test public void keepsLatestSnapshotAndSchedulesOneDrain() {
        SubnetRouteUpdateQueue queue = new SubnetRouteUpdateQueue();
        assertTrue(queue.offer("[\"192.168.0.0/24,10.26.0.2\"]"));
        assertFalse(queue.offer("[\"172.16.0.0/16,10.26.0.3\"]"));
        assertEquals("[\"172.16.0.0/16,10.26.0.3\"]", queue.take());
        assertNull(queue.take());
        assertTrue(queue.offer("[]"));
    }

    @Test public void closeDropsSnapshotsUntilReset() {
        SubnetRouteUpdateQueue queue = new SubnetRouteUpdateQueue();
        queue.close();
        assertFalse(queue.offer("[]"));
        assertNull(queue.take());
        queue.reset();
        assertTrue(queue.offer("[]"));
    }
}
