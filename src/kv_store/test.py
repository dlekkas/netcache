from client_api import NetCacheClient


def main():
    client = NetCacheClient('10.0.0.2', 50000)

    # read should be returned from switch (cached statically)
    client.read("one")
    client.read("two")
    client.read("ten")

    # read should be forwared to KV-Store and return error (not inserted)
    # client.read("test")

    # put query should be forwarded to KV-Store
    client.put("test", "test_ok")

    # read should be forwared to KV-Store
    client.read("test")
    client.read("test")

    # delete query should be forwarded to KV-Store
    client.delete("test")

    # read should fail for hot key report threshold set to 3 (testing purposes)
    client.read("test")

    client.put("test_2", "test2_ok")
    client.read("test_2")
    client.read("test_2")

    # key should get cached after this one (threshold > 3)
    client.read("test_2")
    client.read("test_2")

    # delete query forwarded to KV-store
    client.delete("test_2")

    # key should be invalidated in the cache and hence it will be replied by the server
    client.read("test_2")




if __name__=="__main__":
    main()
