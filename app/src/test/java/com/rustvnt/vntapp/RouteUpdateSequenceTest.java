package com.rustvnt.vntapp;

import static org.junit.Assert.*;

import java.util.ArrayList;
import java.util.List;
import org.junit.Test;

public class RouteUpdateSequenceTest {
    @Test public void usesStrictPrepareEstablishCompleteOrder() throws Exception {
        List<String> calls = new ArrayList<>();
        RouteUpdateSequence.run(new RouteUpdateSequence.Operations() {
            @Override public void prepare() { calls.add("prepare"); }
            @Override public int establish() { calls.add("establish"); return 42; }
            @Override public void complete(int fd) { calls.add("complete:" + fd); }
        });
        assertEquals(List.of("prepare", "establish", "complete:42"), calls);
    }

    @Test public void establishFailureDoesNotCallComplete() {
        List<String> calls = new ArrayList<>();
        assertThrows(Exception.class, () -> RouteUpdateSequence.run(new RouteUpdateSequence.Operations() {
            @Override public void prepare() { calls.add("prepare"); }
            @Override public int establish() throws Exception {
                calls.add("establish");
                throw new Exception("failed");
            }
            @Override public void complete(int fd) { calls.add("complete"); }
        }));
        assertEquals(List.of("prepare", "establish"), calls);
    }
}
