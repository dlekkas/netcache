from client_api import NetCacheClient
import numpy as np

def main():
    client = NetCacheClient()

    NO_QUERIES = 4000
    MAX_KEY_VAL = 2000

    ZIPF_PARAM = 2.0

    keys = np.random.zipf(ZIPF_PARAM, NO_QUERIES)

    for key in keys:
        if key <= MAX_KEY_VAL:
            client.read(str(key))

if __name__=="__main__":
    main()
