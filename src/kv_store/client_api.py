import socket

def convert(val):
	return int.from_bytes(bytes(val, "utf-8"), "big")

def build_message(op, key, seq=0, value = ""):

    msg = bytearray()
    msg += op.to_bytes(1, 'big')
    msg += seq.to_bytes(4, 'big')

    msg += convert(key).to_bytes(16, 'big')

    msg += convert(value).to_bytes(128, 'big')

    return msg

class NetCacheClient:

    def __init__(self, host,port):
        self.host = host
        self.port = port
        self.udps = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def read(self, key, seq=0):
        msg = build_message(0, key, seq)
        self.udps.connect((self.host, self.port))
        self.udps.send(msg)
        data = self.udps.recvfrom(1024)
        self.udps.close
        print(data[0].decode("utf-8"))

    def put(self, key, value, seq = 0):
        msg = build_message(1, key, seq, value)
        tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcps.connect((self.host, self.port))
        tcps.send(msg)
        tcps.close()

    def delete(self, key, seq = 0):
        msg = build_message(2, key, seq)
        tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcps.connect((self.host, self.port))
        tcps.send(msg)
        tcps.close()

client = NetCacheClient('10.0.0.2', 50000)

client.read("one")
