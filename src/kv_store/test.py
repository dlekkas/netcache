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
    client.put("test", "testvalue")

    # read should be forwared to KV-Store and return testvalue
    client.read("test")

    # delete query should be forwarded to KV-Store
    client.delete("test")

    # read should be forwared to KV-Store and return error (deleted)
    client.read("test")


if __name__=="__main__":
    main()
