import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  // ✅ After deploying to Railway/Render, paste your URL here.
  // Example: "https://algoarena-server.up.railway.app"
  // DO NOT add a trailing slash. DO NOT use localhost.
  static const String _serverUrl = "https://algoarenaa-production.up.railway.app";

  void connect() {
    socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.on("connect", (_) => print("✅ Socket connected: ${socket.id}"));
    socket.on("disconnect", (_) => print("❌ Socket disconnected"));
    socket.on("connect_error", (e) => print("❌ Connection error: $e"));
  }

  void setUser(String uid, String username) {
    socket.emit("setUser", {"uid": uid, "username": username});
  }

  void setUid(String uid) {
    socket.emit("setUid", uid);
  }

  void createRoom(String roomName) {
    socket.emit("createRoom", roomName);
  }

  void joinRoom(String roomName) {
    socket.emit("joinRoom", roomName);
  }

  void submitAnswer(String roomId, String answer) {
    socket.emit("submitAnswer", {"roomId": roomId, "answer": answer});
  }

  bool get isConnected => socket.connected;

  void disconnect() {
    socket.disconnect();
  }
}