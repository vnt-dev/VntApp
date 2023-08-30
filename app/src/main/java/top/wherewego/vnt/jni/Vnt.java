package top.wherewego.vnt.jni;

public class Vnt {
    private final long raw;

    Vnt(long raw) {
        if (raw == 0) {
            throw new RuntimeException();
        }
        this.raw = raw;
    }

    public void stop() {
        stop0(raw);
    }

    public void waitStop() {
        waitStop0(raw);
    }

    public boolean waitStopMs(long ms) {
        return waitStopMs0(raw, ms);
    }

    public PeerDeviceInfo[] list() {
        return list0(raw);
    }

    private native void stop0(long raw);

    private native void waitStop0(long raw);

    private native boolean waitStopMs0(long raw, long ms);

    private native PeerDeviceInfo[] list0(long raw);

    private native void drop0(long raw);

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        drop0(raw);
    }
}
