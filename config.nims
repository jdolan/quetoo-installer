when defined(staticBuild):
  when defined(windows):
    # TODO: change once issue nim#15220 is resolved
    switch("passL", "-static")
    switch("define", "noOpenSSLHacks")
    switch("dynlibOverride", "ssl-")
    switch("dynlibOverride", "crypto-")
    switch("define", "sslVersion:(")
    switch("passL", "-lssl")
    switch("passL", "-lcrypto")
    switch("passL", "-lws2_32")
