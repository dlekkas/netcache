import socket
import time
import sys

NETCACHE_PORT = 50000
NOCACHE_PORT = 50001

MAX_SUPPORTED_SERVERS = 254

NETCACHE_READ_QUERY = 0
NETCACHE_WRITE_QUERY = 1
NETCACHE_DELETE_QUERY = 2

NETCACHE_KEY_NOT_FOUND = 20
NETCACHE_METRICS_REPORT = 30


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

    def __init__(self, n_servers=1, no_cache=False):
        self.n_servers = n_servers
        self.servers = []

        if no_cache:
            self.port = NOCACHE_PORT
        else:
            self.port = NETCACHE_PORT

        self.udps = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.get_servers_ips()

        # store all latencies of the requests sent (used for evaluation)
        self.latencies = []


    # the IP addresses assigned to servers are based on the assignment
    # strategy defined at the p4app.json file; the basic l2 strategy
    # that we are using assigns IP addresses starting from 10.0.0.1
    # and assigns incrementing addresses to defined hosts
    def get_servers_ips(self):
        if self.n_servers > MAX_SUPPORTED_SERVERS:
            print("Error: Exceeded maximum supported servers")
            sys.exit()

        for i in range(self.n_servers):
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
            return self.servers[first_letter % self.n_servers]

        elif partition_scheme == 'hash':
            return self.servers[hash(key) % self.n_servers]

        elif partition_scheme == 'consistent-hash':
            # TODO(dimlek): impelement consistent hashing partitioning
            pass

        else:
            print("Error: Invalid partitioning scheme")
            sys.exit()

        return -1


    def read(self, key, seq=0):
        msg = build_message(NETCACHE_READ_QUERY, key, seq)
        if msg is None:
            return

        start_time = time.time()

        self.udps.connect((self.get_node(key), self.port))
        self.udps.send(msg)

        data = self.udps.recv(1024)
        op = data[0]

        latency = time.time() - start_time
        self.latencies.append(latency)

        if op == NETCACHE_KEY_NOT_FOUND:
            print('Error: Key not found (key = ' + key + ')')
        else:
            val = data[21:].decode("utf-8")
            print(val)


    def put(self, key, value, seq = 0, proto='udp'):
        msg = build_message(NETCACHE_WRITE_QUERY, key, seq, value)
        if msg is None:
            return

        if proto == 'udp':
            start_time = time.time()
            self.udps.connect((self.get_node(key), self.port))
            self.udps.send(msg)

            status = self.udps.recv(1024)
            latency = time.time() - start_time

            if status[0] == NETCACHE_KEY_NOT_FOUND:
                print('Error: Key not found (key = ' + key + ')')

            self.latencies.append(latency)

        elif proto == 'tcp':
            tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            tcps.connect((self.get_node(key), self.port))

            start_time = time.time()

            tcps.send(msg)
            status = tcps.recv(1024)

            latency = time.time() - start_time
            self.latencies.append(latency)

            if status[0] == NETCACHE_KEY_NOT_FOUND:
                print('Error: Key not found (key = ' + key + ')')

            tcps.close()

        else:
            print('Protocol for write (' + proto + ') unsupported')


    def delete(self, key, seq = 0):
        msg = build_message(NETCACHE_DELETE_QUERY, key, seq)
        if msg is None:
            return

        tcps = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        tcps.connect((self.get_node(key), self.port))

        start_time = time.time()

        tcps.send(msg)
        status = tcps.recv(1024)

        latency = time.time() - start_time
        self.latencies.append(latency)

        if status[0] == NETCACHE_KEY_NOT_FOUND:
            print('Error: Key not found (key = ' + key + ')')

        tcps.close()


    def request_metrics_report(self):
        results = []

        for server in self.servers:
            msg = build_message(NETCACHE_METRICS_REPORT, "")

            self.udps.connect((server, self.port))
            self.udps.send(msg)

            reply = self.udps.recv(1024)
            print(reply.decode("utf-8"))

        cnt = 0
        for latency in self.latencies:
            cnt += latency

        # calculate average latency in milliseconds
        avg_latency = (cnt / len(self.latencies)) * 1000

        print('avg_latency = ' + '{:.3f}'.format(avg_latency))
