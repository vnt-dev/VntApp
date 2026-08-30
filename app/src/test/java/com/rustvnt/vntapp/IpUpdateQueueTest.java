package com.rustvnt.vntapp;

import static org.junit.Assert.*;
import org.junit.Test;

public class IpUpdateQueueTest {
    @Test public void keepsLatestRequestAndSchedulesOneDrain() {
        IpUpdateQueue queue = new IpUpdateQueue();
        assertTrue(queue.offer(new IpUpdateQueue.Request(1, "10.0.0.2", 24)));
        assertFalse(queue.offer(new IpUpdateQueue.Request(2, "10.0.0.3", 24)));
        assertEquals(2, queue.take().requestId());
        assertFalse(queue.offer(new IpUpdateQueue.Request(2, "10.0.0.3", 24)));
        assertFalse(queue.offer(new IpUpdateQueue.Request(1, "10.0.0.2", 24)));
        assertNull(queue.take());
        assertTrue(queue.offer(new IpUpdateQueue.Request(3, "10.0.0.4", 24)));
    }

    @Test public void closeDropsUpdatesUntilReset() {
        IpUpdateQueue queue = new IpUpdateQueue();
        queue.close();
        assertFalse(queue.offer(new IpUpdateQueue.Request(1, "10.0.0.2", 24)));
        assertNull(queue.take());
        queue.reset();
        assertTrue(queue.offer(new IpUpdateQueue.Request(2, "10.0.0.3", 24)));
    }
}
