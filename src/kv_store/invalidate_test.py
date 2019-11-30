from client_api import NetCacheClient


def main():
    client = NetCacheClient('10.0.0.2', 50000)

    # answered by cache
    client.read("one")

    # should invalidate cache
    client.put("one", "newval")

    # should read from server
    client.read("one")




if __name__=="__main__":
    main()
