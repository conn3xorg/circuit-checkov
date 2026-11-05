# Local example

Applies circuit-checkov to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The apply builds a Python virtual environment and installs checkov into it from PyPI, which takes a minute or so. The second plan says `No changes.` Then check checkov is there:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 checkov --version
```

Want to watch it catch something? `check.sh` plants a Terraform file with a security group open to the world on port 22, and checks checkov fails it on `CKV_AWS_24`. Then it closes the group and checks the same check passes:

```sh
podman exec -i circuit-checkov sh < check.sh
```

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINER_NAME` to name the container something other than `circuit-checkov`, and use that name with `podman exec`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses. On a Mac, rootful Podman is simplest: `export CONTAINER_CONNECTION=podman-machine-default-root`.

`./down.sh` removes the container, its volumes, the key and the state.
