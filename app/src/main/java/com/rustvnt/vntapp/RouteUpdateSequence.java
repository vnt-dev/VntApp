package com.rustvnt.vntapp;

final class RouteUpdateSequence {
    interface Operations {
        void prepare() throws Exception;
        int establish() throws Exception;
        void complete(int tunFd) throws Exception;
    }

    private RouteUpdateSequence() {}

    static void run(Operations operations) throws Exception {
        operations.prepare();
        int tunFd = operations.establish();
        operations.complete(tunFd);
    }
}
