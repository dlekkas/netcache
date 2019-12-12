import socket
import sys

NETCACHE_PORT = 50000

N_SERVERS = 4
MAX_SUPPORTED_SERVERS = 254


def convert(val):
	return int.from_bytes(bytes(val, "utf-8"), "big")

def build_message(op, key, seq=0, value = ""):

    msg = bytearray()
    msg += op.to_bytes(1, 'big')
    msg += seq.to_bytes(4, 'big')

    if len(key) <= 8:
        msg += convert(key).to_bytes(16, 'big')
    else:
        print("Error: Key should be up to 8 bytes")
        return None

    if len(value) <= 64:
        msg += convert(value).to_bytes(64, 'big')
    else:
        print("Error: Value should be up to 64 bytes")
        return None

    return msg


class NetCacheClient:

    def __init__(self, port=NETCACHE_PORT):
        self.servers = []
        self.port = port
        self.udps = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.get_servers_ips()

    # the IP addresses assigned to servers are based on the assignment
    # strategy defined at the p4app.json file; the basic l2 strategy
    # that we are using assigns IP addresses starting from 10.0.0.1
    # and assigns incrementing addresses to defined hosts
    def get_servers_ips(self):
        if N_SERVERS > MAX_SUPPORTED_SERVERS:
            print("Error: Exceeded maximum supported servers")
            sys.exit()

        for i in range(N_SERVERS):
            self.servers.append("10.0.0." + str(i+1));

    # return the right node who contains the given key - our implementation
    # is based on client side partitioning i.e the client directly sends
    # the message to the correct node
    # TODO:1(dimlek): implement consistent hashing partitioning
    # TODO:2(dimlek): explore option of proxy assisted partitioning
    def get_node(self, key, partition_scheme='range'):
        if partition_scheme == 'range':
            # find the right node through range partitioning based on 1st key character
            first_letter = ord(key[0])
            return self.servers[first_letter % N_SERVERS]
        elif partition_scheme == 'consistent-hash':
            # TODO(dimlek): impelement consistent hashing partitioning
            pass
        else:
            print("Error: Invalid partitioning scheme")
            sys.exit()

        return -1

    def read(self, key, seq=0):
        msg = build_message(0, key, seq)
        if msg is None:
            return

        self.udps.connect((self.get_node(key), self.port))
        self.udps.send(msg)
        data = self.udps.recv(1024)
        print(data[21:].decode("utf-8"))


    def put(self, key, value, seq = 0, proto='udp'):
        msg = build_message(1, key, seq, value)
        if msg is None:
            return

        if proto == 'udp':
            self.udps.connect((self.get_node(key), self.port))
            self.udps.send(msg)

            status = self.udps.recv(1024)
            # TODO: evaluate the status returned

        elif proto == 'tcp':
            tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            tcps.connect((self.get_node(key), self.port))
            tcps.send(msg)

            status = tcps.recv(1024)
            # TODO: evaluate the status returned

            tcps.close()
        else:
            print('Protocol for write (' + proto + ') unsupported')


    def delete(self, key, seq = 0):
        msg = build_message(2, key, seq)
        if msg is None:
            return

        tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcps.connect((self.get_node(key), self.port))
        tcps.send(msg)

        status = tcps.recv(1024)
        # TODO: evaluate the status returned
        tcps.close()

