from collections import deque

import socket
import logging
import threading
import time
import sys
import os

STATISTICS_REFRESH_INTERVAL = 30.0

NETCACHE_PORT = 50000
NOCACHE_PORT = 50001

NETCACHE_READ_QUERY = 0
NETCACHE_WRITE_QUERY = 1
NETCACHE_DELETE_QUERY = 2
NETCACHE_HOT_READ_QUERY = 3
NETCACHE_UPDATE_COMPLETE = 4
NETCACHE_DELETE_COMPLETE = 5
NETCACHED_UPDATE = 6
NETCACHE_UPDATE_COMPLETE_OK = 7

NETCACHE_REQUEST_SUCCESS = 10
NETCACHE_KEY_NOT_FOUND = 20
NETCACHE_METRICS_REPORT = 30



def convert(val):
    return int.from_bytes(bytes(val, "utf-8"), "big")

def build_message(op, key, seq=0, value = ""):

    msg = bytearray()
    msg += op.to_bytes(1, 'big')
    msg += seq.to_bytes(4, 'big')
    msg += key.to_bytes(16, 'big')

    msg += convert(value).to_bytes(64, 'big')

    return msg


class KVServer:

    def __init__(self, host, nocache=False, suppress=False, max_listen=10):
        # simple in-memory key value store, represented by a dictionary
        self.kv_store = {}

        # server ip address
        self.host = host
        # server name
        self.name = 'server' + self.host.split('.')[-1]

        # port server is listening to
        if nocache:
            self.port = NOCACHE_PORT
        else:
            self.port = NETCACHE_PORT

        # suppress printing messages
        self.suppress = suppress
        # udp server socket
        self.udpss = None
        #tcp server socket
        self.tcpss = None
        # max clients to listen to
        self.max_listen = max_listen
        # specifies whether the server is blocking for cache updates
        self.blocking = False
        # queue to store incoming requests while blocking
        self.incoming_requests = deque()

        # keep number of requests dispatched to use for evaluation
        self.requests_cnt = 0

        # unix socket for out of band communication with controller
        # (used for cache coherency purposes)
        self.unixss = None


    def activate(self):

        # enable logging for debuggin purposes
        logging.basicConfig(
                filename='log/{}.log'.format(self.name),
                format='%(asctime)s %(levelname)-8s %(message)s',
                level=logging.DEBUG,
                datefmt='%d-%m-%Y %H:%M:%S')

        # create udp socket server
        self.udpss = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udpss.bind((self.host, self.port))

        # create tcp socket server
        self.tcpss = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcpss.bind((self.host, self.port))
        self.tcpss.listen(1)

        # spawn new thread that serves incoming udp (read) queries
        server_udp_t = threading.Thread(target=self.handle_client_udp_request)
        server_udp_t.start()

        # spawn new thread that serves incoming tcp (put/delete) queries
        server_tcp_t = threading.Thread(target=self.handle_client_tcp_request)
        server_tcp_t.start()

        # self.periodic_request_report()

        # starting time of serving requests (used for throughput calculation)
        self.start_time = time.time()

        """
        sock= socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.bind('/tmp/what_a_night.s')
        sock.listen(1)

        conn, addr = sock.accept()
        data = conn.recv(1024)
        print(data)
        print('Success')
        """


    # periodically print the number of requests received (used for testing purposes
    # to evalute the quality of load balancing)
    def periodic_request_report(self):
        t = threading.Timer(STATISTICS_REFRESH_INTERVAL, self.periodic_request_report)
        t.daemon = True
        t.start()

        # TODO(dimlek): add whatever statistics here
        if not self.suppress:
            print('[{}] Number of requests received = {}'.format(self.name, self.requests_cnt))


    # handles incoming udp queries
    def handle_client_udp_request(self):

        while True:

            # if server is not currently blocking updates/writes then if there are
            # requests waiting in the queue then serve those requests, elsewise
            # serve the new incoming packet
            if not self.blocking and len(self.incoming_requests) > 0:
                netcache_pkt, addr = self.incoming_requests.popleft()
            else:
                netcache_pkt, addr = self.udpss.recvfrom(1024)

            # netcache_pkt is an array of bytes belonging to incoming packet's data
            # the data portion of the packet represents the netcache header, so we
            # can extract all the fields defined in the netcache custom protocol

            op = netcache_pkt[0]
            seq = netcache_pkt[1:5]
            key = netcache_pkt[5:21]
            value = netcache_pkt[21:]

            #transform key to int
            key_s = int.from_bytes(key,'big')
            key = key.decode('utf-8').lstrip('\x00')
            seq = int.from_bytes(seq,'big')

            #transform val to string
            value = value.decode("utf-8")


            # if server is blocking to wait for cache to finish updating, then check
            # if the update is finished or otherwise put the received packet into
            # queue to serialize writes/updates

            if self.blocking:

                if op == NETCACHE_UPDATE_COMPLETE_OK:
                    logging.info('Successfully completed UPDATE(' + key + ') from client '
                            + addr[0] + ':' + str(addr[1]))

                    if not self.suppress:
                        print('[{}] Successfully completed UPDATE({})'.format(self.name, key))

                    # start accepting writes/updates again
                    self.blocking = False
                    continue

                elif op != NETCACHE_READ_QUERY:
                    self.incoming_requests.append((netcache_pkt, addr))
                    continue



            if op == NETCACHE_READ_QUERY:
                logging.info('Received READ(' + key + ') from client ' + addr[0])

                if not self.suppress:
                    print('[{}] Received READ({}) from client {}'.format(self.name, key, addr[0]))

                if key in self.kv_store:
                    val = self.kv_store[key]
                    msg = build_message(NETCACHE_READ_QUERY, key_s, seq, val)
                    self.udpss.sendto(msg, addr)
                else:
                    msg = build_message(NETCACHE_KEY_NOT_FOUND, key_s, seq)
                    self.udpss.sendto(msg, addr)

                self.requests_cnt += 1


            elif op == NETCACHE_HOT_READ_QUERY:

                if not self.suppress:
                    print('[{}] Received HOTREAD({}) from client {}'.format(self.name, key, addr[0]))

                if key in self.kv_store:
                    val = self.kv_store[key]
                    msg = build_message(NETCACHE_HOT_READ_QUERY, key_s, seq, val)
                    self.udpss.sendto(msg, addr)
                else:
                    msg = build_message(NETCACHE_KEY_NOT_FOUND, key_s, seq)
                    self.udpss.sendto(msg, addr)

                self.requests_cnt += 1


            elif op == NETCACHED_UPDATE:
                logging.info('Received UPDATE(' + key + ') from client '
                        + addr[0] + ":" + str(addr[1]))

                if not self.suppress:
                    print('[{}] Received UPDATE({}) from client {}'.format(self.name, key, addr[0]))

                # if key already exists in server then it's a valid update query
                if key in self.kv_store:
                    # update the value of the requested key
                    self.kv_store[key] = value

                    # reply to client immediately that the request is dispatched
                    msg = build_message(NETCACHE_REQUEST_SUCCESS, key_s, seq)
                    self.udpss.sendto(msg, addr)

                    # inform the switch with appropriate operation field of netcache
                    # header to update its cache and to validate the key again
                    msg = build_message(NETCACHE_UPDATE_COMPLETE, key_s, seq, value)
                    self.udpss.sendto(msg, addr)

                    # server now should block until cache is updated before serving further writes/updates
                    self.blocking = True


                else:
                    logging.error('Key exists in cache but not in server (key = ' + key + ')')
                    print('Error: Key exists in cache but not in server (key = ' + key + ')')

                self.requests_cnt += 1


            elif op == NETCACHE_WRITE_QUERY:
                logging.info('Received WRITE(' + key + ') from client '
                        + addr[0] + ":" + str(addr[1]))

                if not self.suppress:
                    print('[{}] Received WRITE({}) from client {}'.format(self.name, key, addr[0]))

                # write the value of the requested key
                self.kv_store[key] = value

                # reply back to client that write was successful
                msg = build_message(NETCACHE_REQUEST_SUCCESS, key_s, seq, value)
                self.udpss.sendto(msg, addr)

                self.requests_cnt += 1


            elif op == NETCACHE_METRICS_REPORT:

                if not self.suppress:
                    print('[{}] Received METRICS_REPORT_REQUEST() from client {}'
                            .format(self.name, key, addr[0]))

                total_elapsed_time = time.time() - self.start_time
                if total_elapsed_time != 0:
                    throughput = self.requests_cnt / total_elapsed_time
                else:
                    throughput = 0

                data = '\n'.join((
                    "[{}] requests_received = {}".format(self.name, self.requests_cnt),
                    "[{}] throughput = {}\n".format(self.name, throughput)))

                self.udpss.sendto(bytes(data, "utf-8"), addr)


            else:
                logging.info('Unsupported/Invalid query type received from client ' + addr[0])
                print('Unsupported query type (received op = ' + str(op) + ')')


    # serves incoming tcp queries (i.e. put/delete)
    def handle_client_tcp_request(self):

        while True:

            conn, addr = self.tcpss.accept()

            netcache_pkt = conn.recv(1024)

            op = netcache_pkt[0]
            seq = netcache_pkt[1:5]
            key = netcache_pkt[5:21]
            value = netcache_pkt[21:]

            #transform key to int
            key_s = int.from_bytes(key,'big')
            seq = int.from_bytes(seq, 'big')

            #transform val to string
            value = value.decode("utf-8")
            #transform key to string
            key = key.decode("utf-8").lstrip('\x00')


            if op == NETCACHE_WRITE_QUERY or op == NETCACHED_UPDATE:
                logging.info('Received WRITE(' + key + ') from client '
                        + addr[0] + ":" + str(addr[1]))

                if not self.suppress:
                    print('[{}] Received WRITE({}) from client {}'.format(self.name, key, addr[0]))

                # update the value of the requested key
                self.kv_store[key] = value

                # inform the switch with appropriate operation field of netcache header
                # to update its cache and to validate the key again
                msg = build_message(NETCACHE_UPDATE_COMPLETE, key_s, seq, value)
                conn.sendall(msg)
                conn.close()

                self.requests_cnt += 1



            elif op == NETCACHE_DELETE_QUERY:
                logging.info('Received DELETE(' + key + ') from client '
                        + addr[0] + ":" + str(addr[1]))

                if not self.suppress:
                    print('[{}] Received DELETE({}) from client {}'.format(self.name, key, addr[0]))

                if key in self.kv_store:
                    # delete the key from the key-value store
                    del self.kv_store[key]

                    # inform the switch with appropriate operation field of netcache header
                    # to evict this key from cache
                    msg = build_message(NETCACHE_DELETE_COMPLETE, key_s, seq)
                    conn.sendall(msg)
                else:
                    msg = build_message(NETCACHE_KEY_NOT_FOUND, key_s, seq)
                    conn.sendall(msg)

                conn.close()
                self.requests_cnt += 1

            else:
                logging.info('Unsupported query type received from client '
                        + addr[0] + ":" + str(addr[1]))



    # populate the running server with key-value pairs from a data file
    def populate_from_file(self, file_name):
        if os.path.exists(file_name):
            with open(file_name, 'r') as fp:
                try:
                    # parse each line and insert the key-value pair into
                    # the key-value store
                    for line in fp:
                        key = line.rstrip('\n').split('=')[0]
                        val = line.rstrip('\n').split('=')[1]
                        self.kv_store[key] = val
                except:
                    # if a parsing error occurs then we stop parsing the file,
                    # though pairs added up to the error are not reverted
                    print("Error: while parsing " + str(file_name))
        else:
            print("Error: file " + str(file_name) + " doesn't exist.")




def main(disable_cache, suppress_output, input_files):

    from subprocess import check_output

    # dynamically get the IP address of the server
    server_ip = check_output(['hostname', '--all-ip-addresses']).decode('utf-8').rstrip()
    server = KVServer(server_ip, nocache=disable_cache, suppress=suppress_output)

    # populate the server with all the files given as command line
    # arguments (Usage: python3 server.py [file1 file2 ...])
    for data_file in input_files:
        server.populate_from_file(data_file)

    server.activate()


if __name__ == "__main__":

    import argparse
    parser = argparse.ArgumentParser()

    parser.add_argument('--disable-cache', help='do not use netcache', action='store_true')
    parser.add_argument('--suppress-output', help='supress output printing messages', action='store_true')
    parser.add_argument('--input', help='input files to prepopulate server', required=False, nargs="*")
    args = parser.parse_args()

    main(args.disable_cache, args.suppress_output, args.input)
