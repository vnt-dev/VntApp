package com.rustvnt.vntapp;

final class IpUpdateSequence {
    interface Operations {
        void prepare() throws Exception;
        int establish() throws Exception;
        void complete(int tunFd) throws Exception;
    }

    private IpUpdateSequence() {}

    static void run(boolean noTun, Operations operations) throws Exception {
        operations.prepare();
        int tunFd = noTun ? -1 : operations.establish();
        operations.complete(tunFd);
    }
}
