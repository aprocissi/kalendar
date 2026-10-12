import os

public enum Log {
    public static let shell = Logger(subsystem: "com.massena.kalendar", category: "shell")
    public static let auth = Logger(subsystem: "com.massena.kalendar", category: "auth")
}
