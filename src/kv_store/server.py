import socket
import logging
import threading
import time
import sys

import threading

LOGGING_FILE = 'server.log'

logging.basicConfig(
        filename=LOGGING_FILE,
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.DEBUG,
        datefmt='%d-%m-%Y %H:%M:%S')

NETCACHE_READ_QUERY = 0
NETCACHE_WRITE_QUERY = 1
NETCACHE_DELETE_QUERY = 2


class KVServer:

    def __init__(self, host, port, max_listen=10):
        # simple in-memory key value store, represented by a dictionary
        self.kv_store = {}
        # server ip address
        self.host = host
        # port server is listening to
        self.port = port
        # udp server socket
        self.udpss = None
        #tcp server socket
        self.tcpss = None
        # max clients to listen to
        self.max_listen = max_listen


    def activate(self):

        # create udp socket server
        self.udpss = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udpss.bind((self.host, self.port))

        # create tcp socket server
        self.tcpss = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcpss.bind((self.host, self.port))
        self.tcpss.listen(1)

        logging.info('Key-Value store server started listening on port ' + str(self.port))

        # spawn new thread that serves incoming udp (read) queries
        server_udp_t = threading.Thread(target=self.handle_client_udp_request)
        server_udp_t.start()

        # spawn new thread that serves incoming tcp (put/delete) queries
        server_tcp_t = threading.Thread(target=self.handle_client_tcp_request)
        server_tcp_t.start()


    # handles incoming udp queries (i.e. read queries)
    def handle_client_udp_request(self):

        while True:

            # netcache_pkt is an array of bytes belonging to incoming packet's data
            # the data portion of the packet represents the netcache header, so we
            # can extract all the fields defined in the netcache custom protocol

            netcache_pkt, addr = self.udpss.recvfrom(1024)

            op = netcache_pkt[0]
            seq = netcache_pkt[1:5]
            key = netcache_pkt[5:21]
            value = netcache_pkt[21:]

            #transform key to int
            key = int.from_bytes(key,'big')

            if op != NETCACHE_READ_QUERY:
                logging.info('Unsupported/Invalid query type received from client ' + addr[0])
            else:
                logging.info('Received READ from client ' + addr[0] + ":" + str(addr[1]))

                if key in self.kv_store:
                    val = self.kv_store[key]
                    self.udpss.sendto(bytes(val, "utf-8"), addr)
                else:

                    # TODO: ?what is the behaviour in this case?
                    self.udpss.sendto(bytes("no such key", "utf-8"), addr)

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
            key = int.from_bytes(key,'big')
            #transform val to string
            value = value.decode("utf-8")

            if op == NETCACHE_WRITE_QUERY:
                logging.info('Received WRITE from client ' + addr[0] + ":" + str(addr[1]))

                #inserts or updates the value of the respective key
                self.kv_store[key] = value

                # TODO: ?are we supposed to return something?
                conn.close()

            elif op == NETCACHE_DELETE_QUERY:
                logging.info('Received DELETE from client ' + addr[0] + ":" + str(addr[1]))

                if key in self.kv_store:
                    del self.kv_store[key]

                # TODO: ?are we supposed to return something?
                conn.close()

            else:
                logging.info('Unsupported query type received from client ' + addr[0] + ":" + str(addr[1]))

server = KVServer('10.0.0.2', 40007)
server.activate()



