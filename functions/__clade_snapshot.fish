function __clade_snapshot -a dir label --description 'Snapshot a profile and print the snapshot file'
    set -l data (__clade_data_dir)
    set -l store $data/snapshots/(__clade_key $dir)
    # Snapshots keep secrets, so the store is private to the user.
    mkdir -p $store; and chmod 700 $data $data/snapshots $store; or return

    set -l stamp (date -u +%Y%m%dT%H%M%SZ)
    set -l id $stamp
    set -l n 0
    while count $store/$id*.tar.gz >/dev/null
        set n (math $n + 1)
        set id $stamp.$n
    end

    set -l slug (string lower -- "$label" | string replace -ra -- '[^a-z0-9]+' - | string trim -c - | string sub -l 40)
    set -l file $store/$id.tar.gz
    test -n "$slug"; and set file $store/$id-$slug.tar.gz

    __clade_pack --label="$label" $dir $file; or return
    echo $file
end
