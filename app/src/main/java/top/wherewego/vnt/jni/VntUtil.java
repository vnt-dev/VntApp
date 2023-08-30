package top.wherewego.vnt.jni;

import top.wherewego.vnt.jni.exception.AddressExhaustedException;
import top.wherewego.vnt.jni.exception.TimeoutException;
import top.wherewego.vnt.jni.exception.TokenErrorException;

public class VntUtil {
    private final long raw;
    private boolean isBuild;

    public VntUtil(Config config) {
        raw = new0(config);
        if (raw == 0) {
            throw new RuntimeException();
        }
    }

    public void connect() {
        connect0(raw);
    }

    public RegResponse register() throws AddressExhaustedException, TimeoutException, TokenErrorException {
        return register0(raw);
    }

    public void createIface(int fd) {
        if (fd == 0) {
            throw new RuntimeException();
        }
        createIface0(raw, fd);
    }

    public synchronized Vnt build() {
        if (!isBuild) {
            isBuild = true;
            return new Vnt(build0(raw));
        }
        throw new RuntimeException();
    }

    private native void connect0(long raw);

    private native RegResponse register0(long raw) throws AddressExhaustedException, TimeoutException, TokenErrorException;

    private native void createIface0(long raw, int fd);

    private native long new0(Config config);

    private native long build0(long raw);
}
