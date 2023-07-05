package top.wherewego.switchjni;

public class Switch {
    private final long raw;

    Switch(long raw) {
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

    public PeerDeviceInfo[] list() {
        return list0(raw);
    }

    private native void stop0(long raw);

    private native void waitStop0(long raw);

    private native PeerDeviceInfo[] list0(long raw);
}
