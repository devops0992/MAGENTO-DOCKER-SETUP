vcl 4.1;

import std;

backend default {
    .host = "php-fpm";
    .port = "9000";
    .first_byte_timeout = 300s;
    .connect_timeout = 5s;
    .between_bytes_timeout = 300s;
}

acl purge {
    "localhost";
    "127.0.0.1";
    "172.0.0.0/8";
}

sub vcl_recv {
    # Normalize host header
    if (req.http.host ~ "(?i)^(www\.)?test\.dyna\.com$") {
        set req.http.host = "test.dyna.com";
    }

    # Health check
    if (req.url == "/health.check") {
        return (synth(200, "OK"));
    }

    # PURGE method
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(403, "Purge not allowed"));
        }
        return (purge);
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Pass through if authorization header is present
    if (req.http.Authorization) {
        return (pass);
    }

    # Skip caching for admin URLs
    if (req.url ~ "^/(admin|api)" || req.http.Cookie ~ "adminhtml") {
        return (pass);
    }

    # Skip caching for certain URL patterns
    if (req.url ~ "^/checkout" || 
        req.url ~ "^/customer" ||
        req.url ~ "^/account" ||
        req.url ~ "^/sales" ||
        req.url ~ "\?") {
        return (pass);
    }

    # Remove cookies for static content
    if (req.url ~ "(?i)\.(jpg|jpeg|png|gif|css|js|woff|woff2|ttf|svg|eot|ico)$") {
        unset req.http.Cookie;
    }

    return (hash);
}

sub vcl_hash {
    hash_data(req.url);
    hash_data(req.http.host);
    
    # Hash based on cookie for user-specific content
    if (req.http.Cookie ~ "customer") {
        hash_data(req.http.Cookie);
    }
}

sub vcl_backend_response {
    # Set default cache time to 1 hour
    if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Pragma ~ "no-cache" ||
        beresp.http.Cache-Control ~ "no-cache|private") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    } else {
        set beresp.ttl = 1h;
    }

    # Cache 404 and 301 responses
    if (beresp.status == 404 || beresp.status == 301 || beresp.status == 302) {
        set beresp.ttl = 1h;
    }

    # Set cache time for static assets to 24 hours
    if (bereq.url ~ "(?i)\.(jpg|jpeg|png|gif|css|js|woff|woff2|ttf|svg|eot|ico)$") {
        set beresp.ttl = 24h;
    }

    # Add debug header
    set beresp.http.X-Magento-Cache-Debug = "HIT";

    return (deliver);
}

sub vcl_hit {
    set resp.http.X-Magento-Cache-Debug = "HIT";
}

sub vcl_miss {
    set resp.http.X-Magento-Cache-Debug = "MISS";
}

sub vcl_pass {
    set resp.http.X-Magento-Cache-Debug = "PASS";
}

sub vcl_deliver {
    # Ensure the cache debug header is present
    if (resp.http.X-Magento-Cache-Debug) {
        # Already set
    } else {
        set resp.http.X-Magento-Cache-Debug = "UNCACHEABLE";
    }

    # Remove server info for security
    unset resp.http.Server;
    unset resp.http.X-Powered-By;
}

sub vcl_synth {
    if (resp.status == 200) {
        set resp.http.Content-Type = "text/plain; charset=utf-8";
        set resp.body = "Varnish is running";
        return (deliver);
    }
}
