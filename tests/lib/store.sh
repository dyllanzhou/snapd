#!/bin/bash

STORE_CONFIG=/etc/systemd/system/snapd.service.d/store.conf

# shellcheck source=tests/lib/systemd.sh
. "$TESTSLIB/systemd.sh"

_configure_store_backends(){
    systemctl stop snapd.service snapd.socket
    mkdir -p "$(dirname $STORE_CONFIG)"
    rm -f "$STORE_CONFIG"
    cat > "$STORE_CONFIG" <<EOF
[Service]
Environment=SNAPD_DEBUG=1 SNAPD_DEBUG_HTTP=7 SNAPPY_TESTING=1
Environment=$*
EOF
    systemctl daemon-reload
    systemctl start snapd.socket
}

setup_staging_store(){
    _configure_store_backends "SNAPPY_USE_STAGING_STORE=1"
}

teardown_staging_store(){
    systemctl stop snapd.socket
    rm -rf "$STORE_CONFIG"
    systemctl daemon-reload
    systemctl start snapd.socket
}

init_fake_refreshes(){
    local refreshable_snaps=$1
    local dir=$2

    fakestore -make-refreshable "$refreshable_snaps" -dir "$dir"
}

setup_fake_store(){
    local top_dir=$1

    mkdir -p "$top_dir/asserts"
    # debugging
    systemctl status fakestore || true
    echo "Given a controlled store service is up"

    https_proxy=${https_proxy:-}
    http_proxy=${http_proxy:-}

    systemd_create_and_start_unit fakestore "$(which fakestore) -start -dir $top_dir -addr localhost:11028 -https-proxy=${https_proxy} -http-proxy=${http_proxy} -assert-fallback" "SNAPD_DEBUG=1 SNAPD_DEBUG_HTTP=7 SNAPPY_TESTING=1 SNAPPY_USE_STAGING_STORE=$SNAPPY_USE_STAGING_STORE"

    echo "And snapd is configured to use the controlled store"
    _configure_store_backends "SNAPPY_FORCE_API_URL=http://localhost:11028" "SNAPPY_USE_STAGING_STORE=$SNAPPY_USE_STAGING_STORE"

    echo "Wait until fake store is ready"
    for i in $(seq 10); do
        if netstat -ntlp | MATCH "127.0.0.1:11028*.*LISTEN"; then
            return 0
        fi
        sleep 1
    done

    echo "fakestore service not started properly"
    exit 1
}

teardown_fake_store(){
    local top_dir=$1
    systemd_stop_and_destroy_unit fakestore

    if [ "$REMOTE_STORE" = "staging" ]; then
        setup_staging_store
    else
        systemctl stop snapd.socket
        rm -rf "$STORE_CONFIG" "$top_dir"
        systemctl daemon-reload
        systemctl start snapd.socket
    fi
}
