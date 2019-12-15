from client_api import NetCacheClient


def main(n_servers, no_cache):
    client = NetCacheClient(n_servers=n_servers, no_cache=no_cache)

    # read should be forwared to KV-Store and return error (not inserted)
    client.read("test")

    # put query should be forwarded to KV-Store
    client.put("ctest", "test_okay")

    # read should be forwared to KV-Store
    client.read("ctest")
    client.read("ctest")

    # delete query should be forwarded to KV-Store
    client.delete("ctest")

    # read should fail for hot key report threshold set to 3 (testing purposes)
    client.read("ctest")

    client.put("ctest_2", "tOmZmAvVujaXBP8nFm2TX10w")
    client.put("ctest_2", "abcdeaaaujaXBP8nFm2TX10w")
    client.put("ctest_2", "abcdefghijklmnopkalutera")

    # those queries should be replied by the server
    client.read("ctest_2")
    client.read("ctest_2")
    client.read("ctest_2")
    client.read("ctest_2")

    # queries should be replied from the cache (threshold > 3)
    client.read("ctest_2")
    client.read("ctest_2")

    client.put("ctest_2", "another")
    client.read("ctest_2")
    client.read("ctest_2")
    client.read("ctest_2")

    client.put("ctest_2", "123456789alelajdsflkjads")

    client.read("ctest_2")
    client.read("ctest_2")

    #client.request_metrics_report()

    """
    # delete query forwarded to KV-store
    client.delete("ctest_2")

    # key should be invalidated in the cache and hence it will be replied by the server
    client.read("ctest_2")

    # test prepopulated value
    client.read("c_s4_key44")
    """


if __name__=="__main__":

    import argparse
    parser = argparse.ArgumentParser()

    parser.add_argument('--n-servers', help='number of servers', type=int, required=False, default=1)
    parser.add_argument('--disable-cache', help='do not use netcache', action='store_true')
    args = parser.parse_args()

    main(args.n_servers, args.disable_cache)
