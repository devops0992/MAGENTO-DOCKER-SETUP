vcl 4.1;

# Varnish backend = internal NGINX (HTTP, port 8080)
backend default {
    .host = "nginx";
    .port = "8080";
    .connect_timeout = 60s;
    .first_byte_timeout = 300s;
    .between_bytes_timeout = 60s;
}

import std;

acl purge {
    "localhost";
    "127.0.0.1";
    "nginx";
    "php-fpm";
    "10.0.0.0/8";
    "172.16.0.0/12";
    "192.168.0.0/16";
}

sub vcl_recv {
    # Handle PURGE requests
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Method not allowed"));
        }
        return (purge);
    }

    # Ban
    if (req.method == "BAN") {
        if (!client.ip ~ purge) {
            return (synth(405, "Method not allowed"));
        }
        ban("obj.http.X-Tags ~ " + req.http.X-Ban-Tags);
        return (synth(200, "Banned"));
    }

    # Only cache GET and HEAD
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Don't cache admin
    if (req.url ~ "^/index.php/admin" || req.url ~ "^/admin") {
        return (pass);
    }

    # Don't cache checkout, customer account
    if (req.url ~ "^/(checkout|customer|account|wishlist|cart|compare|review)" ) {
        return (pass);
    }

    # Don't cache if cookie contains logged-in session
    if (req.http.cookie ~ "adminhtml=") {
        return (pass);
    }

    # Magento no-cache cookie
    if (req.http.cookie ~ "no_cache=1") {
        return (pass);
    }

    # Strip marketing/analytics query params to improve cache hit rate
    set req.url = regsuball(req.url, "(^|&)(utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|fbclid)=[^&]*", "");
    set req.url = regsub(req.url, "^([^?]*)\?$", "\1");

    return (hash);
}

sub vcl_hash {
    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    # Vary cache by currency/store cookie if present
    if (req.http.cookie ~ "currency=") {
        hash_data(regsub(req.http.cookie, ".*currency=([^;]+).*", "\1"));
    }
    if (req.http.cookie ~ "store=") {
        hash_data(regsub(req.http.cookie, ".*store=([^;]+).*", "\1"));
    }

    return (lookup);
}

sub vcl_backend_response {
    # Cache 404s briefly to reduce backend load
    if (beresp.status == 404) {
        set beresp.ttl = 30s;
        set beresp.grace = 10s;
        return (deliver);
    }

    # Don't cache 5xx errors
    if (beresp.status >= 500) {
        set beresp.ttl = 0s;
        return (deliver);
    }

    # Strip cookies from cacheable responses
    if (beresp.http.cache-control !~ "private" && beresp.http.cache-control !~ "no-cache") {
        unset beresp.http.set-cookie;
        set beresp.ttl = 1h;
        set beresp.grace = 30m;
    }

    return (deliver);
}

sub vcl_deliver {
    # Add HIT/MISS debug header
    if (obj.hits > 0) {
        set resp.http.X-Magento-Cache-Debug = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Magento-Cache-Debug = "MISS";
    }

    # Remove internal headers
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
    unset resp.http.X-Varnish;
    unset resp.http.Via;

    return (deliver);
}
