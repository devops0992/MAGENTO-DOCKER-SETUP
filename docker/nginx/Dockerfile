FROM nginx:1.25-alpine

ARG TEST_USER_ID=1000
ARG TEST_GROUP_ID=1001
ARG TEST_USER=test-ssh
ARG TEST_GROUP=clp

# Install OpenSSL for certificate generation
RUN apk add --no-cache openssl

# Create user and group
RUN addgroup -g ${TEST_GROUP_ID} ${TEST_GROUP} && \
    adduser -D -u ${TEST_USER_ID} -G ${TEST_GROUP} ${TEST_USER}

# Create certificate directory
RUN mkdir -p /etc/nginx/certs && \
    chown -R ${TEST_USER}:${TEST_GROUP} /etc/nginx/certs

# Generate self-signed certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/test.dyna.com.key \
    -out /etc/nginx/certs/test.dyna.com.crt \
    -subj "/CN=test.dyna.com/O=Test Organization/C=US" \
    -addext "subjectAltName=DNS:test.dyna.com,DNS:*.test.dyna.com"

# Set permissions
RUN chown -R ${TEST_USER}:${TEST_GROUP} /etc/nginx && \
    chown -R ${TEST_USER}:${TEST_GROUP} /var/log/nginx && \
    chown -R ${TEST_USER}:${TEST_GROUP} /var/cache/nginx && \
    chmod 750 /etc/nginx/certs

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
