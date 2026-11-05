#!/usr/bin/env sh
# Runs on the host: plants a Terraform file with a security group open to the
# world on port 22, and checks checkov fails it on CKV_AWS_24. Then fixes the
# group and checks the same check passes. CI pipes it in with podman exec.
set -eu
checkov --version

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/open" "$dir/closed"
cat > "$dir/open/main.tf" <<'TF'
resource "aws_security_group" "ssh" {
  name        = "ssh"
  description = "SSH from anywhere"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
TF
sed 's|0.0.0.0/0|192.0.2.0/24|; s|from anywhere|from the office|' "$dir/open/main.tf" > "$dir/closed/main.tf"

# checkov exits 1 when a check fails.
rc=0
checkov --skip-download --quiet --compact -o json -d "$dir/open" > "$dir/open.json" || rc=$?
if [ "$rc" != 1 ]; then
  echo "checkov exited $rc on the open security group, not 1 for a failed check." >&2
  exit 1
fi
grep -q '"check_id": "CKV_AWS_24"' "$dir/open.json"
grep -q '"resource": "aws_security_group.ssh"' "$dir/open.json"

checkov --skip-download --quiet --compact -o json -d "$dir/closed" --check CKV_AWS_24 > "$dir/closed.json"
grep -q '"failed": 0' "$dir/closed.json"
grep -q '"passed": 1' "$dir/closed.json"
echo "checkov failed CKV_AWS_24 on the open security group and passed it once closed."
