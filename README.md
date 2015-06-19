# hiera-consul
A Hiera backend to retrieve configuration from Hashicorp's Consul KV store

## Configuration

You should modify `hiera.yaml` as follows:

    :backends:
        - consul

    :consul:
        :addr: # parsed from CONSUL_HTTP_ADDR if not specified
        :port: # parsed from CONSUL_HTTP_ADDR if not specified
        :paths:
            - /v1/kv/hiera
            - /v1/kv/%{environment}

## Lookups

Only string and hash lookups are support, i.e. `hiera()` and `hiera_hash()`.

A string lookup will return the contents of the value at the specified key.

### Hash lookups

A hash lookup will use the `recurse` parameter of the
[KV HTTP API](https://www.consul.io/docs/agent/http/kv.html) and performs a
deep merge to produce an answer.

Example (values have been base64 decoded for clarity):

    > curl http://127.0.0.1:8500/v1/kv/hiera/foo?recurse
    [
        {
            "CreateIndex": 1,
            "Flags": 0,
            "Key": "foo/",
            "LockIndex": 0,
            "ModifyIndex": 305244,
            "Value": null
        },
        {
            "CreateIndex": 2,
            "Flags": 0,
            "Key": "foo/bar",
            "LockIndex": 0,
            "ModifyIndex": 305244,
            "Value": "42"
        },
        {
            "CreateIndex": 3,
            "Flags": 0,
            "Key": "foo/baz",
            "LockIndex": 0,
            "ModifyIndex": 305244,
            "Value": null
        },
        {
            "CreateIndex": 4,
            "Flags": 0,
            "Key": "foo/baz/qux",
            "LockIndex": 0,
            "ModifyIndex": 305244,
            "Value": "hello"
        }
    ]

Will return an answer:

    > hiera -h foo
    {
        "foo" => {
            "bar" => "42",
            "baz" => {
                "qux" => "hello"
            }
        }
    }

## TODO

This is very much alpha, some improvements:

 - [ ] Add configuration options for SSL/TLS
 - [ ] Setup CI
