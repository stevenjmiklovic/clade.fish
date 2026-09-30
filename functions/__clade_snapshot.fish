function __clade_snapshot -a dir label --description 'Snapshot a profile and print the snapshot file'
    set -l data (__clade_data_dir)
    set -l store $data/snapshots/(__clade_key $dir)
    # Snapshots keep secrets, so the store is private to the user.
    mkdir -p $store; and chmod 700 $data $data/snapshots $store; or return

    set -l stamp (date -u +%Y%m%dT%H%M%SZ)
    set -l id $stamp
    set -l n 0
    while count $store/$id*.tar.gz* >/dev/null
        set n (math $n + 1)
        set id $stamp.$n
    end

    set -l slug (string lower -- "$label" | string replace -ra -- '[^a-z0-9]+' - | string trim -c - | string sub -l 40)
    set -l base $store/$id
    test -n "$slug"; and set base $store/$id-$slug

    if not set -q clade_gpg_recipients[1]
        __clade_pack --label="$label" $dir $base.tar.gz; or return
        echo $base.tar.gz
        return 0
    end

    # Encrypted: build it privately, prove it decrypts back to the same bytes, then move it into place.
    __clade_gpg_can_decrypt $clade_gpg_recipients; or return
    set -l tmp (__clade_mktemp); or return
    set -l recipients
    for fingerprint in $clade_gpg_recipients
        set -a recipients --recipient $fingerprint
    end
    if not begin
            __clade_pack --label="$label" $dir $tmp/snapshot.tar.gz
            and gpg --batch --quiet --yes --trust-model always $recipients --encrypt \
                --output $tmp/snapshot.tar.gz.gpg $tmp/snapshot.tar.gz
            and gpg --batch --quiet --yes --decrypt --output $tmp/check.tar.gz $tmp/snapshot.tar.gz.gpg
            and cmp -s $tmp/snapshot.tar.gz $tmp/check.tar.gz
        end
        rm -rf $tmp
        __clade_err "could not encrypt and verify the snapshot, so none was saved (see 'clade encryption status')"
        return 1
    end
    jq -n --arg label "$label" --arg created (date -u +%Y-%m-%dT%H:%M:%SZ) --arg profile (__clade_key $dir) \
        '{label: $label, created: $created, profile: $profile, recipients: $ARGS.positional}' \
        --args $clade_gpg_recipients >$tmp/meta.json
    chmod 600 $tmp/snapshot.tar.gz.gpg $tmp/meta.json
    mv -n $tmp/snapshot.tar.gz.gpg $base.tar.gz.gpg
    and mv -n $tmp/meta.json $base.tar.gz.gpg.json
    if test $status -ne 0; or test -e $tmp/snapshot.tar.gz.gpg
        rm -rf $tmp
        __clade_err "could not save the snapshot to $store"
        return 1
    end
    rm -rf $tmp
    echo $base.tar.gz.gpg
end
