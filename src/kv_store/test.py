from client_api import NetCacheClient


def main():
    client = NetCacheClient()

    # read should be returned from switch (cached statically)
    client.read("one")
    client.read("two")
    client.read("ten")

    # read should be forwared to KV-Store and return error (not inserted)
    # client.read("test")

    # put query should be forwarded to KV-Store
    client.put("ctest", "test_okay")

    # read should be forwared to KV-Store
    client.read("ctest")
    client.read("ctest")

    # delete query should be forwarded to KV-Store
    client.delete("ctest")

    # read should fail for hot key report threshold set to 3 (testing purposes)
    client.read("ctest")

    client.put("ctest_2", "test2_ok")
    client.read("ctest_2")
    client.read("ctest_2")

    # key should get cached after this one (threshold > 3)
    client.read("ctest_2")
    client.read("ctest_2")
    client.read("ctest_2")
    client.put("ctest_2", "another")
    client.read("ctest_2")


    """
    # delete query forwarded to KV-store
    client.delete("ctest_2")

    # key should be invalidated in the cache and hence it will be replied by the server
    client.read("ctest_2")

    # test prepopulated value
    client.read("c_s4_key44")
    """


if __name__=="__main__":
    main()
