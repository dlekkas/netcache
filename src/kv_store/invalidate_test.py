from client_api import NetCacheClient


def main():
    client = NetCacheClient('10.0.0.2', 50000)

    # answered by cache
    client.read("one")

    # should invalidate cache
    client.put("one", "newval")

    # should read from server
    client.read("one")

    # answered by cache
    client.read("two")

    # should invalidate cache
    client.delete("two")

    # should try to read from server
    client.read("two")




if __name__=="__main__":
    main()
