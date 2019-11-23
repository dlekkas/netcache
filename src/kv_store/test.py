from client_api import NetCacheClient


def main():
    client = NetCacheClient('10.0.0.2', 50000)

    # read should be returned from switch (cached statically)
    client.read("one")
    client.read("two")
    client.read("ten")

    # read should be forwared to KV-Store and return error (not inserted)
    client.read("test")

    # put query should be forwarded to KV-Store
    client.put("test", "test_ok")

    # read should be forwared to KV-Store and then cached by P4 switch
    client.read("test")

    # delete query should be forwarded to KV-Store
    client.delete("test")

    # read should be replied by the P4 switch (since cache invalidation is not implemented)
    client.read("test")


if __name__=="__main__":
    main()
