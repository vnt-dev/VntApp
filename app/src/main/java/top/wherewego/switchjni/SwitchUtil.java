package top.wherewego.switchjni;

import top.wherewego.switchjni.exception.AddressExhaustedException;
import top.wherewego.switchjni.exception.TimeoutException;
import top.wherewego.switchjni.exception.TokenErrorException;

public class SwitchUtil {
    private final long raw;
    private boolean isBuild;

    public SwitchUtil(Config config) {
        raw = new0(config);
        if (raw == 0) {
            throw new RuntimeException();
        }
    }

    public RegResponse connect() throws AddressExhaustedException, TimeoutException, TokenErrorException {
        return connect0(raw);
    }

    public void createIface(int fd) {
        if (fd == 0) {
            throw new RuntimeException();
        }
        createIface0(raw, fd);
    }

    public synchronized Switch build() {
        if (!isBuild) {
            isBuild = true;
            return new Switch(build0(raw));
        }
        throw new RuntimeException();
    }

    private native RegResponse connect0(long raw) throws AddressExhaustedException, TimeoutException, TokenErrorException;

    private native void createIface0(long raw, int fd);

    private native long new0(Config config);

    private native long build0(long raw);
}
