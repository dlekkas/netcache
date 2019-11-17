import socket

def build_message(op, key, seq=0, value = None):

    msg = bytearray()
    msg += op.to_bytes(1, 'big')
    msg += seq.to_bytes(4, 'big')
    msg += key.to_bytes(16, 'big')

    if value != None:
        msg += bytes(value, "utf-8")

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

client = NetCacheClient('10.0.0.2', 40007)

client.read(0)
client.put(0,"test")
client.read(1)
client.read(0)
client.delete(0)
client.read(0)
