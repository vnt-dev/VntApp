package com.vnt;

public class VntException extends Exception {
    public VntException(String message) { super(message); }
    public VntException(String message, Throwable cause) { super(message, cause); }
}
